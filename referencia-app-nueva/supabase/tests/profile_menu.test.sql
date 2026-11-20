-- Perfil completo: facturación, contacto de la sede y perfiles de la familia.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

create function pg_temp.login(p_email text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

-- ================= Contacto de la sede =================
select pg_temp.login('elena@itaca.test');
select is(public.gym_contact('00000000-0000-4000-a000-000000000001') ->> 'email', 'contacto@tu-gimnasio.com', 'un miembro ve el contacto de su sede');
select ok(public.gym_contact('00000000-0000-4000-a000-000000000001') ->> 'whatsapp' is not null, 'incluye el WhatsApp');

-- ================= Facturación =================
select lives_ok($$
  update public.profiles set billing_name = 'Elena Ruiz', billing_tax_id = '12345678Z', billing_city = 'Logroño'
  where user_id = (select auth.uid())
$$, 'el alumno guarda sus datos de facturación');
select is((select billing_city from public.profiles where user_id = (select auth.uid())), 'Logroño', 'se guardan');
select throws_ok($$
  update public.profiles set billing_tax_id = repeat('9', 21) where user_id = (select auth.uid())
$$, '23514', null, 'el NIF tiene longitud máxima');

-- ================= Familia =================
select is((select count(*)::int from public.guardianships g join public.profiles p on p.id = g.minor_profile_id
           where g.guardian_profile_id = public.current_profile_id()), 1, 'la tutora ve a su hija');
select lives_ok($$
  update public.profiles set full_name = 'Noa Díaz Ruiz'
  where id = (select minor_profile_id from public.guardianships where guardian_profile_id = public.current_profile_id())
$$, 'la tutora edita los datos de su hija');
select is((select full_name from public.profiles p join public.guardianships g on g.minor_profile_id = p.id
           where g.guardian_profile_id = public.current_profile_id()), 'Noa Díaz Ruiz', 'el cambio se guarda');

-- Otro alumno no ve a la menor ni su contacto de sede ajena
select pg_temp.login('carlos@itaca.test');
select is((select count(*)::int from public.profiles where full_name like 'Noa%'), 0, 'otro alumno no ve a la menor');
select pg_temp.login('elena@itaca.test');
select is(public.gym_contact(gen_random_uuid()), null, 'no ve el contacto de una sede a la que no pertenece');

select * from finish();
rollback;
