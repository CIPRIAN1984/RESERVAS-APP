# Operaciones

## Validación de permisos Supabase

Antes de aplicar una migración de permisos:

1. Ejecutar `supabase start`.
2. Ejecutar `supabase test db`.
3. Ejecutar los Security y Performance Advisors.
4. Confirmar que cada aviso restante de funciones `SECURITY DEFINER`
   corresponde a una RPC pública intencionada con validación interna.
5. Verificar en un entorno no productivo los roles `anon`, `authenticated` y
   `service_role`.

## Estado del historial remoto

El 27 de julio de 2026 se compararon las 22 migraciones remotas del proyecto
`dpcdpcvjcutcqyqcacti` con los archivos locales. El nombre lógico, el tamaño en
bytes y la huella MD5 del SQL normalizado coinciden exactamente en los 22 casos.

Los archivos locales usan desde entonces las mismas versiones temporales
registradas en producción (`20260712124546…20260712124745`). Este cambio solo
reconcilia el historial: no modifica el SQL, el esquema ni los datos.

Antes de ejecutar `supabase db push`:

1. Confirmar con `supabase migration list` que las 22 versiones coinciden en
   local y remoto.
2. Comprobar que solo aparecen como pendientes las migraciones nuevas.
3. Ejecutar primero `supabase db push --dry-run`.
4. Detener la operación si una migración histórica aparece como pendiente.

## Bootstrap del Administrador inicial

Este procedimiento se ejecuta una sola vez y únicamente si no existe ningún
perfil con `rol = 'administrador'`.

1. En Supabase Auth, crear el usuario definitivo del Administrador sin metadata
   de registro y confirmar su correo. No reutilizar una cuenta de Alumno o
   Dueño.
2. Copiar el UUID del usuario y, desde SQL Editor del proyecto exacto
   `dpcdpcvjcutcqyqcacti`, ejecutar:

   ```sql
   select public.bootstrap_initial_admin(
     '<uuid-del-usuario>'::uuid,
     '<nombre>',
     null
   );
   ```

3. Confirmar que existe exactamente un perfil Administrador activo y sin
   academia:

   ```sql
   select id, rol, estado, academia_id
   from public.profiles
   where rol = 'administrador';
   ```

4. Iniciar sesión en la aplicación y comprobar el acceso al panel de academias.

La función rechaza usuarios sin correo confirmado, perfiles existentes y
cualquier intento posterior. Nunca usar la clave `service_role` en Flutter,
Vercel público, una captura, un ticket o documentación versionada.

## Correo y recuperación de contraseña

Configuración requerida en Supabase Auth para el proyecto
`dpcdpcvjcutcqyqcacti`:

1. Definir **Site URL** como `https://itc2-reservas.vercel.app`.
2. Añadir exactamente estas Redirect URLs:
   - `https://itc2-reservas.vercel.app/restablecer-contrasena`
   - `itaca://restablecer-contrasena`
3. Copiar el asunto y HTML de `supabase/templates/recovery.html` a la plantilla
   **Reset password** del Dashboard.
4. Activar la notificación de cambio de contraseña usando
   `supabase/templates/password_changed_notification.html`.
5. Configurar un SMTP transaccional propio con dominio verificado antes de
   incorporar usuarios reales. Las credenciales SMTP se guardan solo en
   Supabase, nunca en Git, Flutter ni Vercel.
6. Probar en web, Android e iOS que el enlace abre la pantalla de nueva
   contraseña y que un enlace usado o caducado no permite cambiarla.

Los archivos de `config.toml` y `supabase/templates` reproducen el
comportamiento local. En proyectos Supabase alojados, las plantillas y el SMTP
se configuran en Dashboard; no se despliegan mediante migraciones SQL.

## Prueba integral con datos ficticios

`supabase/tests/e2e_fake_user_journey_test.sql` reproduce el recorrido crítico
sin tocar datos alojados: bootstrap del Administrador, registro y aprobación de
una academia, altas de Alumnos, promoción a Profesor, creación de tarifa y
clase, cuota cobrada simulada, reserva, lista de espera, cancelación, promoción,
notificación y asistencia.

La prueba se ejecuta dentro de una transacción con `rollback`. Las direcciones
terminadas en `@test.dev`, los UUID fijos y las referencias `sub_fake_e2e_*`
son exclusivamente datos de prueba.

Para ejecutarla:

1. Confirmar que Docker está operativo.
2. Ejecutar `supabase start`.
3. Ejecutar `supabase test db`.
4. Exigir que el plan integral complete sus 24 aserciones y que el resto de
   pruebas pgTAP siga en verde.

La activación de las dos cuotas simula únicamente el estado final escrito por
un webhook Stripe autenticado. No llama a Stripe, no usa secretos y no debe
ejecutarse contra el proyecto alojado.
