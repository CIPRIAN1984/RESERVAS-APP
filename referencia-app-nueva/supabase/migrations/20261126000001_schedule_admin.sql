-- Gestión del horario por propietario y administración:
-- eliminar una clase semanal, crear una clase puntual, y cancelar, recuperar
-- o cambiar la clase de un día concreto. Todo queda en auditoría.

create function public._require_schedule_admin(p_gym uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.has_role(p_gym, array['owner', 'admin']::public.gym_role[]) then
    raise exception 'Solo propietario y administración cambian el horario' using errcode = '42501';
  end if;
end $$;
revoke execute on function public._require_schedule_admin from public, anon, authenticated;

-- ---------- Eliminar una clase semanal ----------
-- Las sesiones futuras sin reservas se borran; las que tienen reservas se
-- cancelan (los alumnos las ven canceladas) y quedan como clases sueltas.
-- El historial pasado se conserva.
create function public.delete_class_template(p_template uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_t public.class_templates%rowtype;
  v_deleted int;
  v_cancelled int;
begin
  select * into v_t from public.class_templates where id = p_template;
  if not found then
    raise exception 'Clase no encontrada' using errcode = 'P0002';
  end if;
  perform public._require_schedule_admin(v_t.gym_id);

  delete from public.class_sessions s
  where s.template_id = p_template and s.starts_at > now() and s.booked_count = 0 and s.waitlist_count = 0;
  get diagnostics v_deleted = row_count;

  update public.class_sessions s
  set status = 'cancelled', cancel_reason = 'Clase eliminada del horario', template_id = null
  where s.template_id = p_template and s.starts_at > now();
  get diagnostics v_cancelled = row_count;

  delete from public.class_templates where id = p_template;  -- el pasado queda con template_id vacío

  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, old_data)
  values (v_t.gym_id, (select auth.uid()), 'class_templates', v_t.id, 'delete_class', to_jsonb(v_t));
  return jsonb_build_object('deleted_sessions', v_deleted, 'cancelled_sessions', v_cancelled);
end $$;

-- ---------- Clase puntual (un solo día) ----------
create function public.create_one_off_session(
  p_gym uuid, p_discipline uuid, p_name text, p_date date, p_start time, p_duration_min integer,
  p_capacity integer default 50, p_level text default '', p_coach uuid default null, p_place text default 'Tatami'
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_tz text;
  v_start timestamptz;
  v_id uuid;
begin
  perform public._require_schedule_admin(p_gym);
  if length(trim(coalesce(p_name, ''))) = 0 then
    raise exception 'Falta el nombre de la clase' using errcode = '22023';
  end if;
  if p_duration_min is null or p_duration_min < 15 or p_duration_min > 600 then
    raise exception 'Duración no válida' using errcode = '22023';
  end if;
  if not exists (select 1 from public.disciplines d where d.id = p_discipline and d.gym_id = p_gym) then
    raise exception 'Disciplina no válida' using errcode = '22023';
  end if;
  select g.time_zone into v_tz from public.gyms g where g.id = p_gym;
  v_start := (p_date + p_start) at time zone v_tz;
  if v_start < now() - interval '1 hour' then
    raise exception 'La clase sería en el pasado' using errcode = '22023';
  end if;

  insert into public.class_sessions (gym_id, template_id, discipline_id, name, level, starts_at, ends_at, capacity, coach_profile_id, place)
  values (p_gym, null, p_discipline, trim(p_name), coalesce(trim(p_level), ''), v_start, v_start + make_interval(mins => p_duration_min),
          coalesce(p_capacity, 50), p_coach, coalesce(nullif(trim(p_place), ''), 'Tatami'))
  returning id into v_id;

  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, new_data)
  values (p_gym, (select auth.uid()), 'class_sessions', v_id, 'create_one_off',
          jsonb_build_object('name', trim(p_name), 'starts_at', v_start, 'duration_min', p_duration_min));
  return v_id;
end $$;

-- ---------- Cancelar o recuperar la clase de un día ----------
create function public.cancel_session(p_session uuid, p_reason text default null) returns void
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
  update public.class_sessions
  set status = 'cancelled', cancel_reason = coalesce(nullif(trim(p_reason), ''), 'Clase cancelada'), cancelled_by_closure = null
  where id = p_session;
  -- PASO 7: avisar a los apuntados por push y email.
  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, new_data)
  values (v_s.gym_id, (select auth.uid()), 'class_sessions', v_s.id, 'cancel_session',
          jsonb_build_object('reason', p_reason, 'booked', v_s.booked_count));
end $$;

create function public.restore_session(p_session uuid) returns void
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
  if v_s.cancelled_by_closure is not null then
    raise exception 'Este día está cerrado: quita el cierre para recuperar sus clases' using errcode = 'P0001', hint = 'closure';
  end if;
  update public.class_sessions set status = 'scheduled', cancel_reason = null where id = p_session;
  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action)
  values (v_s.gym_id, (select auth.uid()), 'class_sessions', v_s.id, 'restore_session');
end $$;

-- ---------- Cambiar la clase de un día (aforo, sustituto, lugar) ----------
create function public.update_session(p_session uuid, p_capacity integer default null, p_substitute uuid default null,
                                      p_clear_substitute boolean default false, p_place text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_s public.class_sessions%rowtype;
  v_free int;
  v_w record;
begin
  select * into v_s from public.class_sessions where id = p_session for update;
  if not found then
    raise exception 'Clase no encontrada' using errcode = 'P0002';
  end if;
  perform public._require_schedule_admin(v_s.gym_id);
  if p_capacity is not null and p_capacity < v_s.booked_count then
    raise exception 'Ya hay % reservas: el aforo no puede ser menor', v_s.booked_count using errcode = '22023', hint = 'capacity';
  end if;
  if p_substitute is not null and not exists (
    select 1 from public.gym_members m where m.gym_id = v_s.gym_id and m.profile_id = p_substitute and m.status = 'active'
      and m.role in ('owner', 'admin', 'coach')
  ) then
    raise exception 'El sustituto debe ser del personal docente' using errcode = '22023';
  end if;
  update public.class_sessions set
    capacity = coalesce(p_capacity, capacity),
    substitute_coach_profile_id = case when p_clear_substitute then null else coalesce(p_substitute, substitute_coach_profile_id) end,
    place = coalesce(nullif(trim(p_place), ''), place)
  where id = p_session;
  -- Con más aforo, sube la lista de espera (solo quien aún tenga clases en su tarifa)
  if p_capacity is not null and p_capacity > v_s.capacity then
    v_free := p_capacity - v_s.booked_count;
    for v_w in
      select w.id, w.profile_id from public.bookings w
      where w.session_id = p_session and w.status = 'waitlist'
      order by w.created_at
    loop
      exit when v_free <= 0;
      if (public.plan_allowance(v_w.profile_id, p_session) ->> 'ok')::boolean then
        update public.bookings set status = 'booked' where id = v_w.id;
        v_free := v_free - 1;
      end if;
    end loop;
  end if;
  insert into public.audit_log (gym_id, actor_user_id, table_name, row_id, action, new_data)
  values (v_s.gym_id, (select auth.uid()), 'class_sessions', v_s.id, 'update_session',
          jsonb_build_object('capacity', p_capacity, 'substitute', p_substitute, 'clear_substitute', p_clear_substitute, 'place', p_place));
end $$;

revoke execute on function public.delete_class_template, public.create_one_off_session, public.cancel_session,
  public.restore_session, public.update_session from public, anon;
grant execute on function public.delete_class_template, public.create_one_off_session, public.cancel_session,
  public.restore_session, public.update_session to authenticated;
