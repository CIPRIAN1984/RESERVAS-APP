#!/usr/bin/env bash
# Prueba de concurrencia del paso 3: dos alumnos reservan A LA VEZ la última
# plaza de una clase, desde dos conexiones distintas. Debe salir una plaza y
# una lista de espera (nunca dos plazas).
#
# Uso: npm run test:concurrency   (con Supabase local arrancado)
set -euo pipefail

C=$(docker ps --format '{{.Names}}' | grep '^supabase_db_' | head -1)
if [ -z "$C" ]; then echo "Supabase local no está arrancado (npm run db:start)"; exit 1; fi
sql() { docker exec -i "$C" psql -U postgres -v ON_ERROR_STOP=1 -qtA; }

GYM=c0c00000-0000-4000-c000-000000000001
DISC=c0c00000-0000-4000-c000-000000000002
SES=c0c00000-0000-4000-c000-000000000003
U1=c0c00000-0000-4000-c000-0000000000a1
U2=c0c00000-0000-4000-c000-0000000000a2

cleanup() {
  sql >/dev/null <<SQL
delete from public.gyms where id = '$GYM';
delete from public.profiles where user_id in ('$U1', '$U2');
delete from auth.users where id in ('$U1', '$U2');
SQL
}
trap cleanup EXIT
cleanup

sql >/dev/null <<SQL
insert into public.gyms (id, name) values ('$GYM', 'Concurrencia');
insert into public.disciplines (id, gym_id, slug, name, kind) values ('$DISC', '$GYM', 'gi', 'Gi', 'gi');
insert into auth.users (instance_id, id, aud, role, email, raw_user_meta_data, created_at, updated_at) values
  ('00000000-0000-0000-0000-000000000000', '$U1', 'authenticated', 'authenticated', 'conc-1@test.test', '{"full_name":"Primero"}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '$U2', 'authenticated', 'authenticated', 'conc-2@test.test', '{"full_name":"Segundo"}', now(), now());
insert into public.gym_members (gym_id, profile_id) select '$GYM', id from public.profiles where user_id in ('$U1', '$U2');
-- Una sola plaza
insert into public.class_sessions (id, gym_id, discipline_id, name, starts_at, ends_at, capacity)
values ('$SES', '$GYM', '$DISC', 'Última plaza', now() + interval '1 day', now() + interval '1 day 1 hour', 1);
SQL

# Reserva como el usuario \$1 y mantiene la transacción abierta \$2 segundos
book() {
  sql <<SQL | grep -E '^(booked|waitlist)$'
begin;
select set_config('request.jwt.claims', '{"sub":"$1","role":"authenticated"}', true);
set local role authenticated;
select public.book_session('$SES') ->> 'status';
select pg_sleep($2);
commit;
SQL
}

TMP=$(mktemp -d)
book "$U1" 2 > "$TMP/a" &
sleep 0.5
START=$(date +%s)
book "$U2" 0 > "$TMP/b" &
wait
WAITED=$(( $(date +%s) - START ))

A=$(cat "$TMP/a"); B=$(cat "$TMP/b"); rm -rf "$TMP"
COUNTS=$(echo "select booked_count || '/' || waitlist_count from public.class_sessions where id = '$SES';" | sql)

echo "Primera conexión: $A"
echo "Segunda conexión: $B (esperó ~${WAITED}s a que la primera terminara)"
echo "Ocupación final (plazas/espera): $COUNTS"

if [ "$A" = "booked" ] && [ "$B" = "waitlist" ] && [ "$COUNTS" = "1/1" ]; then
  echo "OK: una plaza y una espera"
else
  echo "FALLO: se esperaba una plaza y una espera"
  exit 1
fi
