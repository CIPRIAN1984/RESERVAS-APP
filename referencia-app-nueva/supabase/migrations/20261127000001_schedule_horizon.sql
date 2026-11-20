-- Horario sin "generar semanas": las clases semanales se crean solas con
-- 12 semanas (tres meses) de antelación, al guardarlas y cada noche.
-- Cada clase semanal tiene fecha de inicio y, opcionalmente, de fin
-- (valid_from / valid_until): "todos los meses" = sin fecha de fin.

create or replace function public.sync_template_sessions() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_tz text;
begin
  if tg_op = 'UPDATE' then
    select g.time_zone into v_tz from public.gyms g where g.id = new.gym_id;

    -- Datos que no cambian la hora: se aplican a todas las sesiones futuras
    update public.class_sessions s set
      name = new.name, level = new.level, discipline_id = new.discipline_id,
      capacity = greatest(new.capacity, s.booked_count), coach_profile_id = new.coach_profile_id, place = new.place
    where s.template_id = new.id and s.starts_at > now() and s.status = 'scheduled';

    -- Sesiones que ya no encajan (día, hora, duración, fechas o clase desactivada):
    -- se borran solo si nadie las ha reservado
    delete from public.class_sessions s
    where s.template_id = new.id and s.starts_at > now() and s.status = 'scheduled'
      and s.booked_count = 0 and s.waitlist_count = 0
      and (
        not new.active
        or extract(isodow from s.starts_at at time zone v_tz)::smallint <> all (new.weekdays)
        or (s.starts_at at time zone v_tz)::time <> new.start_time
        or s.ends_at - s.starts_at <> make_interval(mins => new.duration_min)
        or (s.starts_at at time zone v_tz)::date < new.valid_from
        or (new.valid_until is not null and (s.starts_at at time zone v_tz)::date > new.valid_until)
      );
  end if;
  perform public.generate_sessions(new.gym_id, 12);
  return new;
end $$;

-- Tarea nocturna con el nuevo horizonte
select cron.unschedule('generate-sessions-nightly');
select cron.schedule('generate-sessions-nightly', '15 3 * * *', $$ select public.generate_sessions_all(12) $$);

-- Al quitar un cierre, las clases de esos días vuelven (las que nunca se crearon, también)
create or replace function public.regenerate_after_closure() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.generate_sessions(coalesce(old.gym_id, new.gym_id), 12);
  return null;
end $$;
create trigger closures_regenerate after delete on public.closures
  for each row execute function public.regenerate_after_closure();

-- ---------- Borrar la clase de un solo día ----------
-- Sin reservas se borra; con reservas se cancela para que los alumnos lo vean.
-- Si es de una clase semanal, ese día no se vuelve a crear (queda cancelada).
create function public.delete_session(p_session uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_s public.class_sessions%rowtype;
begin
  select * into v_s from public.class_sessions where id = p_session for update;
  if not found then
    raise exception 'Clase no encontrada' using errcode = 'P0002';
  end if;
  perform public._require_schedule_admin(v_s.gym_id);
  if v_s.ends_at <= now() then
    raise exception 'La clase ya ha terminado' using errcode = 'P0001', hint = 'ended';
  end if;

  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, old_data)
  values (v_s.gym_id, (select auth.uid()), 'class_sessions', v_s.id, 'delete_session', to_jsonb(v_s));

  if v_s.template_id is null and v_s.booked_count = 0 and v_s.waitlist_count = 0 then
    delete from public.class_sessions where id = p_session;
    return 'deleted';
  end if;
  -- Clase semanal (o con reservas): se cancela y así no se vuelve a generar ese día
  update public.class_sessions
  set status = 'cancelled', cancel_reason = coalesce(cancel_reason, 'Clase anulada'), cancelled_by_closure = null
  where id = p_session;
  return 'cancelled';
end $$;
revoke execute on function public.delete_session from public, anon;
grant execute on function public.delete_session to authenticated;

-- Rellenar ya los tres meses en todas las sedes
select public.generate_sessions_all(12);
