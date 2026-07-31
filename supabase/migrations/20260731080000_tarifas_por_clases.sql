-- ============================================================
-- Tarifas con clases por ciclo
-- ============================================================
--
-- Una tarifa era cuota plana. El negocio de Cipri no funciona así: «2 días
-- por semana son 8 al mes, 3 por semana son 12; si empieza el 5 de mayo,
-- hasta el 5 de junio puede gastar las que tiene».
--
-- Ver DECISIONS.md, 31/07/2026, para el porqué de cada regla.

-- ------------------------------------------------------------
-- 1. La tarifa lleva cuántas clases da al mes
-- ------------------------------------------------------------

alter table public.tarifas
  add column if not exists clases_incluidas int;

comment on column public.tarifas.clases_incluidas is
  'Clases que da AL MES. NULL = ilimitada. Es por mes aunque la tarifa se '
  'cobre cada 3 o cada 12: la periodicidad es de facturación, las clases van '
  'por ciclo mensual.';

alter table public.tarifas
  drop constraint if exists tarifas_clases_incluidas_check;
alter table public.tarifas
  add constraint tarifas_clases_incluidas_check
  check (clases_incluidas is null or clases_incluidas > 0);

-- «suelta» es el drop-in: se paga una vez, no se renueva.
alter table public.tarifas
  drop constraint if exists tarifas_periodicidad_check;
alter table public.tarifas
  add constraint tarifas_periodicidad_check
  check (periodicidad in ('mensual', 'trimestral', 'anual', 'suelta'));

-- El Dueño ya podía crear tarifas; solo hay que dejarle tocar la columna
-- nueva. `tarifas` no tiene el update de tabla revocado, así que no hace
-- falta ningún grant extra: se hereda del de la tabla.

-- ------------------------------------------------------------
-- 2. El ciclo vigente de una suscripción
-- ------------------------------------------------------------
--
-- De fecha a fecha, no por mes natural: del 5 de mayo al 5 de junio.
-- `age()` hace bien el salto de mes (el 31 de enero + 1 mes es el 28 de
-- febrero, no el 3 de marzo).
--
-- Una tarifa «suelta» no tiene ciclo mensual: las clases duran hasta que se
-- acaba la suscripción, y ya.

create or replace function public.ciclo_vigente(
  p_fecha_inicio timestamptz,
  p_fecha_fin timestamptz,
  p_periodicidad text
)
returns table (inicio timestamptz, fin timestamptz)
language sql
-- STABLE y no IMMUTABLE: depende de `now()`. Marcarla inmutable dejaría que
-- el planificador la calculara una vez y la congelara.
stable
set search_path = public, pg_temp
as $function$
  select
    case when p_periodicidad = 'suelta' then p_fecha_inicio
         else p_fecha_inicio + (meses || ' months')::interval end,
    case when p_periodicidad = 'suelta'
         then coalesce(p_fecha_fin, 'infinity'::timestamptz)
         else p_fecha_inicio + ((meses + 1) || ' months')::interval end
  from (
    select greatest(
      0,
      extract(year from age(now(), p_fecha_inicio))::int * 12
        + extract(month from age(now(), p_fecha_inicio))::int
    ) as meses
  ) c;
$function$;

-- Toda función de `public` queda expuesta como endpoint por PostgREST. Esta
-- es una ayuda interna y no tiene por qué llamarla nadie desde fuera. Hay una
-- prueba (`function_permissions_test`) que falla si alguna se queda abierta a
-- `anon`, y es la que cazó este olvido.
revoke all on function
  public.ciclo_vigente(timestamptz, timestamptz, text) from public, anon;
grant execute on function
  public.ciclo_vigente(timestamptz, timestamptz, text) to authenticated;

-- ------------------------------------------------------------
-- 3. Cuántas clases le quedan a un alumno
-- ------------------------------------------------------------
--
-- Devuelve el saldo del ciclo vigente. Las condiciones de «cuota al día» son
-- LAS MISMAS que comprueba `reservar_clase`: si aquí se relajaran, la app
-- diría «al corriente» de alguien a quien el servidor considera moroso.
--
-- `disponibles` descuenta también lo ya RESERVADO, no solo lo confirmado.
-- Sin eso, alguien con una clase suelta podría reservar las ocho de la
-- semana: al reservar, el contador todavía no ha bajado.
--
-- Las clases se cuentan por la fecha de la CLASE, no por la de validación:
-- si el profesor pasa lista dos días tarde, la clase cuenta en el ciclo en
-- el que se dio.

create or replace function public.clases_restantes(p_alumno_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_actor_rol text;
  v_actor_academia uuid;
  v_suscripcion record;
  v_ciclo record;
  v_gastadas int;
  v_reservadas int;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  select rol, academia_id into v_actor_rol, v_actor_academia
    from public.profiles where id = v_actor_id;

  -- Su propio saldo lo ve cualquiera; el de otro, solo quien lleva la
  -- academia, y solo si es de LA SUYA. Se comprueba aquí arriba y no después
  -- de buscar la suscripción: si se hiciera después, el caso «no tiene
  -- cuota» respondería igual para un alumno de otra academia y ya estaría
  -- contando algo que no le incumbe.
  if p_alumno_id <> v_actor_id then
    if v_actor_rol not in ('dueño', 'profesor') then
      raise exception 'No autorizado.';
    end if;
    if not exists (
      select 1 from public.profiles
       where id = p_alumno_id and academia_id = v_actor_academia
    ) then
      raise exception 'No autorizado.';
    end if;
  end if;

  select s.*, t.clases_incluidas, t.periodicidad, t.nombre as tarifa_nombre
    into v_suscripcion
    from public.suscripciones s
    join public.tarifas t on t.id = s.tarifa_id
   where s.alumno_id = p_alumno_id
     and s.estado = 'activa'
     and s.payment_status = 'active'
     and s.fecha_inicio <= now()
     and (s.fecha_fin is null or s.fecha_fin > now())
   order by s.fecha_inicio desc
   limit 1;

  if not found then
    return jsonb_build_object(
      'tiene_cuota', false,
      'ilimitada', false,
      'incluidas', 0,
      'gastadas', 0,
      'reservadas', 0,
      'disponibles', 0
    );
  end if;

  select * into v_ciclo
    from public.ciclo_vigente(
      v_suscripcion.fecha_inicio,
      v_suscripcion.fecha_fin,
      v_suscripcion.periodicidad
    );

  if v_suscripcion.clases_incluidas is null then
    return jsonb_build_object(
      'tiene_cuota', true,
      'ilimitada', true,
      'tarifa', v_suscripcion.tarifa_nombre,
      'ciclo_inicio', v_ciclo.inicio,
      'ciclo_fin', v_ciclo.fin
    );
  end if;

  select count(*)::int into v_gastadas
    from public.asistencias a
    join public.clases c on c.id = a.clase_id
   where a.alumno_id = p_alumno_id
     and c.fecha_hora_inicio >= v_ciclo.inicio
     and c.fecha_hora_inicio < v_ciclo.fin;

  select count(*)::int into v_reservadas
    from public.inscripciones i
    join public.clases c on c.id = i.clase_id
   where i.alumno_id = p_alumno_id
     and i.estado = 'inscrito'
     and c.fecha_hora_inicio > now()
     and c.fecha_hora_inicio >= v_ciclo.inicio
     and c.fecha_hora_inicio < v_ciclo.fin
     and not exists (
       select 1 from public.asistencias a
        where a.clase_id = i.clase_id and a.alumno_id = i.alumno_id
     );

  return jsonb_build_object(
    'tiene_cuota', true,
    'ilimitada', false,
    'tarifa', v_suscripcion.tarifa_nombre,
    'incluidas', v_suscripcion.clases_incluidas,
    'gastadas', v_gastadas,
    'reservadas', v_reservadas,
    'disponibles', greatest(
      0, v_suscripcion.clases_incluidas - v_gastadas - v_reservadas
    ),
    'ciclo_inicio', v_ciclo.inicio,
    'ciclo_fin', v_ciclo.fin
  );
end;
$function$;

revoke all on function public.clases_restantes(uuid) from public, anon;
grant execute on function public.clases_restantes(uuid) to authenticated;
