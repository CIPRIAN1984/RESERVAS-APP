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

## Observabilidad de producción

Fuentes autorizadas para `RESERVAS-APP`:

| Señal | Destino exacto | Uso |
| --- | --- | --- |
| CI | `CIPRIAN1984/RESERVAS-APP` | formato, análisis, pruebas, pgTAP, secretos y build |
| Despliegue | Vercel `itc2-reservas` | estado y logs de compilación |
| Disponibilidad | `https://itc2-reservas.vercel.app` | smoke diario de rutas públicas |
| Backend | Supabase `dpcdpcvjcutcqyqcacti` | Advisors, Auth, Postgres y Edge Functions |
| Errores cliente | Sentry, si hay DSN de este proyecto | errores y trazas sin PII predeterminada |

`Production smoke` se ejecuta diariamente y también admite ejecución manual.
Solo realiza peticiones GET al dominio canónico y comprueba `/`,
`/olvide-contrasena` y `/privacidad`.

Tras cada despliegue de producción:

1. Confirmar que Vercel muestra estado `READY` para `itc2-reservas`.
2. Ejecutar manualmente `Production smoke`.
3. Revisar errores de la última hora en Vercel y Supabase.
4. Si Sentry está activo, comprobar que la release coincide con el commit.
5. No copiar payloads, tokens, correos ni datos personales a incidencias.

No activar Web Analytics, Speed Insights, drains ni integraciones de pago sin
revisar primero el plan, el coste y el impacto de privacidad.

## Respuesta a incidentes

Clasificación:

- **P0:** fuga de datos, acceso cruzado entre academias o cobros incorrectos.
- **P1:** autenticación, reservas o pagos no disponibles para todos.
- **P2:** función degradada con alternativa operativa.
- **P3:** defecto menor sin pérdida de datos.

Procedimiento:

1. Registrar hora, entorno, commit y señal de detección sin incluir PII.
2. Contener: desactivar solo la función afectada o volver al despliegue Vercel
   anterior. No revertir una migración destructivamente.
3. Preservar logs y referencias de Stripe/Supabase con acceso restringido.
4. Corregir en una rama y PR independientes con prueba de regresión.
5. Restaurar servicio, ejecutar el smoke y revisar errores durante una hora.
6. Documentar causa, alcance, línea temporal y acciones preventivas.
7. Si afecta a datos personales, escalar inmediatamente al responsable de la
   academia para evaluar comunicaciones y plazos legales.

## Solicitudes de privacidad

1. La academia recibe la solicitud por un canal previamente verificado.
2. Verifica la identidad sin pedir contraseñas ni códigos de un solo uso.
3. Localiza el perfil por UUID dentro de su academia; nunca consulta otras.
4. Para acceso o portabilidad, exporta solo los datos del solicitante y sus
   relaciones autorizadas.
5. Para rectificación, usa los flujos normales y deja trazabilidad mínima.
6. Para supresión, identifica antes obligaciones de facturación, pagos,
   antifraude o reclamaciones. Elimina o anonimiza el resto y revoca sesiones,
   tokens push y archivos.
7. Registra fecha, responsable, decisión y finalización sin adjuntar el
   contenido exportado al ticket.

Las operaciones masivas, la eliminación de Auth y cualquier cambio en datos
reales requieren autorización expresa y una copia de seguridad verificada.

## Recuperación y continuidad

1. Comprobar diariamente el estado de copias de Supabase en el proyecto exacto.
2. Probar trimestralmente la restauración en un entorno no productivo aislado.
3. Antes de una migración de riesgo, documentar copia, compatibilidad hacia
   atrás y procedimiento de avance; las migraciones son forward-only.
4. Para una regresión de frontend, promover un despliegue Vercel anterior y
   confirmar el dominio canónico con el smoke.
5. Para una caída de Supabase, no crear una base alternativa ni cambiar IDs.
   Esperar recuperación o restaurar únicamente dentro de
   `dpcdpcvjcutcqyqcacti` con autorización expresa.

## Activación de notificaciones push

Requisitos externos:

1. Crear un único proyecto Firebase exclusivo de `RESERVAS-APP`.
2. Registrar Android `com.itaca.itaca` e iOS `com.itaca.itaca`.
3. En Apple Developer, habilitar Push Notifications para el App ID y cargar la
   clave APNs en Firebase.
4. Crear una service account con el acceso mínimo necesario para FCM v1.
5. Generar un `CRON_SECRET` aleatorio e independiente.

Configurar en Supabase `dpcdpcvjcutcqyqcacti` los secretos
`FCM_SERVICE_ACCOUNT` y `CRON_SECRET`. Después:

1. Desplegar únicamente `send-push`; `supabase/config.toml` fija
   `verify_jwt=false`.
2. Programar una llamada HTTPS periódica con
   `X-Cron-Secret: <CRON_SECRET>`.
3. Probar con un usuario ficticio y un dispositivo físico de cada plataforma.
4. Confirmar registro del token, recepción en primer y segundo plano y borrado
   de un token inválido.
5. Confirmar que una indisponibilidad temporal de FCM deja la fila pendiente
   para el siguiente intento.

Nunca registrar el JSON de la service account, el secreto del cron ni tokens de
dispositivos en commits, incidencias o logs.

## Generación de artefactos móviles

El workflow manual `Mobile release artifacts` necesita estos secretos:

- `MOBILE_DART_DEFINE_JSON_BASE64`
- `FIREBASE_ANDROID_CONFIG_BASE64`
- `FIREBASE_IOS_CONFIG_BASE64`
- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

El JSON de Dart debe apuntar exactamente a
`https://dpcdpcvjcutcqyqcacti.supabase.co` y contener
`"PUSH_ENABLED": true`. Los tres archivos binarios/configuración se guardan
codificados en Base64; el workflow los materializa solo durante la ejecución y
los elimina al finalizar.

Para cada versión:

1. Aumentar el número de build; nunca reutilizar uno aceptado por una tienda.
2. Ejecutar CI y `Mobile release artifacts`.
3. Descargar el AAB firmado, comprobar su firma y subirlo primero a una pista
   interna de Google Play con Play App Signing.
4. El job iOS verifica una compilación release sin firma. Abrir el mismo commit
   en un Mac autorizado, seleccionar el equipo Apple, comprobar Push
   Notifications y archivar/distribuir desde Xcode o App Store Connect.
5. Probar instalación, inicio de sesión, recuperación de contraseña, reservas,
   pagos de prueba y push en dispositivos físicos.
6. Completar las fichas de privacidad, clasificación por edades, capturas,
   países y contacto de soporte antes de solicitar revisión.

La URL de privacidad para ambas tiendas es
`https://itc2-reservas.vercel.app/privacidad`. La publicación no se considera
terminada hasta que cada consola confirme la aprobación y la versión esté
disponible en la pista o países elegidos.
