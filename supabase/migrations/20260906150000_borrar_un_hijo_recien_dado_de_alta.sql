-- Dar de baja a un hijo — pero solo mientras no haya empezado.
--
-- El 03/09 se decidió que el padre borraba a su hijo y se borraba todo. El
-- 06/09 Cipri dijo lo contrario hablando de la gestión de alumnos: «solo yo
-- les puedo dar de baja; en MAAT nadie se da de baja, yo debo darles
-- manualmente, si no es un cristo». Un hijo es un alumno que paga cuota, así
-- que las dos cosas no encajaban. Manda la segunda (ver DECISIONS.md).
--
-- Resultado: esto sirve para **corregir un alta recién hecha** (un nombre
-- mal escrito, un duplicado), no para dar de baja a nadie. En cuanto el niño
-- tiene una clase, una asistencia, una cuota, un pedido, un préstamo o una
-- solicitud de cambio de escuela, el padre ya no puede tocarlo: la baja pasa
-- a ser cosa del Dueño.

-- ============================================================
-- Qué hijos míos se pueden borrar todavía
-- ============================================================
-- La app necesita saberlo para no enseñar un botón que va a fallar. Va en
-- una función y no en una consulta del cliente porque mirar las cuotas de
-- otra persona no es algo que la RLS de `suscripciones` le deje hacer a un
-- padre, y con razón: ahí vive el dinero.
create or replace function public.hijos_borrables()
returns setof uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select rf.child_id
    from public.relaciones_familia rf
    join public.profiles p on p.id = rf.child_id
   where rf.parent_id = auth.uid()
     -- Nunca un perfil con cuenta propia: eso ya no es «un hijo dado de
     -- alta por su padre», es una persona que entra sola en la app.
     and not p.tiene_cuenta
     and not exists (select 1 from public.inscripciones i where i.alumno_id = p.id)
     and not exists (select 1 from public.asistencias a where a.alumno_id = p.id)
     and not exists (select 1 from public.suscripciones s where s.alumno_id = p.id)
     and not exists (select 1 from public.pedidos pe where pe.alumno_id = p.id)
     and not exists (select 1 from public.prestamos pr where pr.alumno_id = p.id)
     and not exists (
       select 1 from public.solicitudes_cambio_escuela sc where sc.alumno_id = p.id
     );
$$;

revoke all on function public.hijos_borrables() from public, anon;
grant execute on function public.hijos_borrables() to authenticated;

-- ============================================================
-- Borrar a un hijo
-- ============================================================
create or replace function public.borrar_hijo(p_hijo_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor_id uuid := auth.uid();
  v_nombre text;
  v_tiene_cuenta boolean;
begin
  if v_actor_id is null then
    raise exception 'No autorizado.';
  end if;

  -- La comprobación de parentesco va antes que ninguna otra: si no es hijo
  -- mío, ni siquiera debo enterarme de si existe.
  if not public.es_padre_de(p_hijo_id) then
    raise exception 'Solo puedes dar de baja a tus propios hijos.';
  end if;

  select nombre, tiene_cuenta into v_nombre, v_tiene_cuenta
    from public.profiles where id = p_hijo_id
    for update;

  if not found then
    raise exception 'Ese alumno ya no existe.';
  end if;

  if v_tiene_cuenta then
    raise exception 'Esta persona entra en la app con su propia cuenta. Habla con tu academia.';
  end if;

  -- Se vuelve a comprobar aquí, y no solo en `hijos_borrables`, porque entre
  -- que la pantalla pintó el botón y el padre lo pulsó pueden haber pasado
  -- cosas: el profesor le ha pasado lista, o el dueño le ha cobrado la
  -- cuota. La pantalla decide qué enseñar; quien decide qué se permite es
  -- esto.
  if exists (select 1 from public.inscripciones i where i.alumno_id = p_hijo_id)
     or exists (select 1 from public.asistencias a where a.alumno_id = p_hijo_id)
     or exists (select 1 from public.pedidos pe where pe.alumno_id = p_hijo_id)
     or exists (select 1 from public.prestamos pr where pr.alumno_id = p_hijo_id)
     or exists (
       select 1 from public.solicitudes_cambio_escuela sc where sc.alumno_id = p_hijo_id
     )
  then
    raise exception
      '% ya ha empezado en la academia. Habla con tu profesor para darle de baja.',
      v_nombre;
  end if;

  -- La cuota va aparte y con su propio mensaje: es el caso que más va a
  -- pasar y el que peor se entiende si se mezcla con «ya ha empezado».
  if exists (select 1 from public.suscripciones s where s.alumno_id = p_hijo_id) then
    raise exception
      '% tiene una cuota registrada. Solo tu academia puede darlo de baja.',
      v_nombre;
  end if;

  -- Estas dos guardan el id sin clave foránea, así que no bloquean el
  -- borrado: se quedarían huérfanas. Un menor sin cuenta no debería tener
  -- ninguna, pero asegurarlo cuesta dos líneas.
  delete from public.notificaciones_outbox where user_id = p_hijo_id;
  delete from public.device_tokens where user_id = p_hijo_id;

  -- `relaciones_familia` es la única clave foránea en cascada de todas las
  -- que apuntan a `profiles`, así que se va sola con el perfil.
  delete from public.profiles where id = p_hijo_id;
end;
$function$;

revoke all on function public.borrar_hijo(uuid) from public, anon;
grant execute on function public.borrar_hijo(uuid) to authenticated;
