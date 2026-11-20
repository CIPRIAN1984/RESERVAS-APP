-- Fase 4 del plan de mejora · Perfil completo.
-- Datos de facturación en el perfil y contacto público de la sede (soporte).

alter table public.profiles
  add column billing_name text check (billing_name is null or length(billing_name) <= 120),
  add column billing_tax_id text check (billing_tax_id is null or length(billing_tax_id) <= 20),
  add column billing_address text check (billing_address is null or length(billing_address) <= 200),
  add column billing_postal_code text check (billing_postal_code is null or length(billing_postal_code) <= 10),
  add column billing_city text check (billing_city is null or length(billing_city) <= 80);

comment on column public.profiles.billing_tax_id is 'NIF/DNI solo para emitir facturas; opcional';

-- Contacto de la sede (lo ven sus miembros en "Contactar con soporte").
-- Datos públicos de https://www.tu-gimnasio.com (18/11/2026).
update public.gyms
set settings = settings || jsonb_build_object('contact', jsonb_build_object(
  'email', 'contacto@tu-gimnasio.com',
  'phone', '+34600000000',
  'whatsapp', '34600000000',
  'address', 'Calle Ejemplo, 1 · 00000 Tu ciudad',
  'instagram', 'tu_gimnasio',
  'web', 'https://www.tu-gimnasio.com'
))
where id = '00000000-0000-4000-a000-000000000001';

-- Contacto de mi sede (sin exponer el resto de ajustes)
create function public.gym_contact(p_gym uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select g.settings -> 'contact' from public.gyms g
  where g.id = p_gym and public.has_role(g.id, enum_range(null::public.gym_role))
$$;
revoke execute on function public.gym_contact from public, anon;
grant execute on function public.gym_contact to authenticated;
