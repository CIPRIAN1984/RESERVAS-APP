# Producción

| Pieza | Dónde |
| --- | --- |
| Web | https://itaca-jiu-jitsu.pages.dev (Cloudflare Pages, proyecto `itaca-jiu-jitsu`) |
| Base de datos | Supabase, proyecto `itaca-jiu-jitsu` (`TU_PROJECT_REF`), región París (eu-west-3), plan gratuito |
| Contraseña de la base | Llavero de macOS, elemento "Supabase ITACA base de datos" (nunca en el repositorio) |
| Configuración de la web | `.env.production` (URL y clave **pública**; no se sube al repositorio) |

## Publicar una versión nueva de la web

```bash
npm run deploy
```

Compila con `.env.production` y sube `dist/` a Cloudflare Pages. Necesita la sesión de Wrangler (`npx wrangler@3 login`). Se usa Wrangler 3 porque Wrangler 4 pide Node 22.

## Aplicar migraciones nuevas a la base de la nube

Siempre después de que pasen las pruebas en local (`npm run test:db`):

```bash
export SUPABASE_DB_PASSWORD="$(security find-generic-password -a itaca-jiu-jitsu -s 'Supabase ITACA base de datos' -w)"
supabase db push --remote --dry-run   # revisar qué se aplicaría
supabase db push --remote
```

## Datos iniciales

`supabase/production/setup.sql` crea la sede, el horario y las tarifas (sin usuarios ni alumnos de prueba). Ya aplicado el 16/11/2026; es idempotente.

## Inicio de sesión

`supabase/config.toml` → `[remotes.production]`: dirección de la web y redirecciones. Se aplica con `supabase config push`. En producción se mantienen los valores de Supabase: confirmación de email, un envío por minuto, código de 8 dígitos y doble factor disponible.

Pendiente: el correo de Supabase gratuito envía muy pocos emails por hora. Antes de abrir la app a todos los alumnos hay que configurar un proveedor (Resend o similar) en Authentication → SMTP.

## Dar el rol de propietario

Tras el primer inicio de sesión de la persona (que crea su perfil), en el SQL Editor de Supabase:

```sql
insert into public.gym_members (gym_id, profile_id, role)
select '00000000-0000-4000-a000-000000000001', p.id, 'owner'
from public.profiles p join auth.users u on u.id = p.user_id
where u.email = 'CORREO'
on conflict (gym_id, profile_id) do update set role = 'owner';
```

## Subir migraciones a la nube

El llavero de macOS de este equipo no deja a la CLI de Supabase guardar la sesión. El token de acceso se guarda una vez en `~/.config/supabase-itaca-token` (fuera del repositorio, permisos 600) y `npm run db:push:production` lo lee de ahí. Crearlo en https://supabase.com/dashboard/account/tokens con caducidad de 90 días; cuando caduque, se sustituye el archivo.
