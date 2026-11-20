-- Al cambiar el día, la hora, la duración o las fechas de una clase semanal,
-- las sesiones que ya no encajan desaparecen siempre:
--  · sin reservas, se borran;
--  · con reservas, las reservas pasan a la sesión nueva de ese mismo día
--    (si el alumno ya tenía la nueva, la antigua se cancela) y la antigua se borra;
--  · si ese día ya no hay clase, la sesión se cancela para que los alumnos lo vean.
-- Antes, una sesión con reservas se quedaba con la hora antigua y, al cancelar
-- la reserva, quedaba suelta en el horario junto a la nueva.

create or replace function public.sync_template_sessions() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_tz text;
  v_old record;
  v_new uuid;
begin
  if tg_op = 'UPDATE' then
    select g.time_zone into v_tz from public.gyms g where g.id = new.gym_id;

    -- Datos que no cambian la hora: se aplican a todas las sesiones futuras
    update public.class_sessions s set
      name = new.name, level = new.level, discipline_id = new.discipline_id,
      capacity = greatest(new.capacity, s.booked_count), coach_profile_id = new.coach_profile_id, place = new.place
    where s.template_id = new.id and s.starts_at > now() and s.status = 'scheduled';

    -- Sesiones que ya no encajan y nadie ha reservado: se borran
    delete from public.class_sessions s
    where s.template_id = new.id and s.starts_at > now() and s.status = 'scheduled'
      and s.booked_count = 0 and s.waitlist_count = 0
      and public._session_misfits(s.starts_at, s.ends_at, new.active, new.weekdays, new.start_time, new.duration_min, new.valid_from, new.valid_until, v_tz);
  end if;

  perform public.generate_sessions(new.gym_id, 12);

  if tg_op = 'UPDATE' then
    -- Las que no encajan pero tienen reservas: se mueven a la nueva del mismo día
    for v_old in
      select s.id, (s.starts_at at time zone v_tz)::date as day
      from public.class_sessions s
      where s.template_id = new.id and s.starts_at > now() and s.status = 'scheduled'
        and public._session_misfits(s.starts_at, s.ends_at, new.active, new.weekdays, new.start_time, new.duration_min, new.valid_from, new.valid_until, v_tz)
    loop
      select n.id into v_new from public.class_sessions n
      where n.template_id = new.id and n.id <> v_old.id and n.status = 'scheduled'
        and (n.starts_at at time zone v_tz)::date = v_old.day
        and not public._session_misfits(n.starts_at, n.ends_at, new.active, new.weekdays, new.start_time, new.duration_min, new.valid_from, new.valid_until, v_tz)
      limit 1;

      if v_new is null then
        update public.class_sessions
        set status = 'cancelled', cancel_reason = 'Clase quitada del horario'
        where id = v_old.id;
        continue;
      end if;

      -- Si ya tenía reserva en la nueva, la antigua se cancela
      update public.bookings b set status = 'cancelled', cancelled_at = now()
      where b.session_id = v_old.id and b.status in ('booked', 'waitlist')
        and exists (select 1 from public.bookings x where x.session_id = v_new and x.profile_id = b.profile_id and x.status in ('booked', 'waitlist'));
      update public.bookings set session_id = v_new where session_id = v_old.id;
      update public.attendances set session_id = v_new where session_id = v_old.id;
      delete from public.class_sessions where id = v_old.id;
    end loop;
  end if;
  return new;
end $$;

-- ¿Ha dejado esta sesión de encajar en su clase semanal?
create or replace function public._session_misfits(
  p_starts timestamptz, p_ends timestamptz, p_active boolean, p_weekdays smallint[], p_start time,
  p_duration integer, p_from date, p_until date, p_tz text
) returns boolean
language sql immutable set search_path = '' as $$
  select not p_active
    or extract(isodow from p_starts at time zone p_tz)::smallint <> all (p_weekdays)
    or (p_starts at time zone p_tz)::time <> p_start
    or p_ends - p_starts <> make_interval(mins => p_duration)
    or (p_starts at time zone p_tz)::date < p_from
    or (p_until is not null and (p_starts at time zone p_tz)::date > p_until)
$$;
revoke execute on function public._session_misfits from public, anon, authenticated;

-- Limpieza: sesiones futuras que se quedaron con la hora antigua y ya no tienen reservas
delete from public.class_sessions s
using public.class_templates t, public.gyms g
where s.template_id = t.id and g.id = t.gym_id
  and s.starts_at > now() and s.status = 'scheduled' and s.booked_count = 0 and s.waitlist_count = 0
  and public._session_misfits(s.starts_at, s.ends_at, t.active, t.weekdays, t.start_time, t.duration_min, t.valid_from, t.valid_until, g.time_zone);
