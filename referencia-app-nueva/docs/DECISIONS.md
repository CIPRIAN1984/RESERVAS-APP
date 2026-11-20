# Decisiones

| Fecha | Decisión | Motivo |
| --- | --- | --- |
| 2026-11-13 | PWA con React + Supabase + Cloudflare Pages | Ver `SPEC.md`: única vía para Android e iOS sin cuenta de desarrollador, coste 0 € al arrancar |
| 2026-11-15 | Construir primero el cliente completo con datos de ejemplo | Permite enseñar y validar las 11 pantallas en el gimnasio antes de montar el servidor |
| 2026-11-15 | Reglas de negocio como funciones puras en `src/lib/logic.ts` con pruebas | Son la especificación ejecutable de `book_session`, `cancel_booking`, `check_in` y `generate_sessions` cuando pasen a SQL |
| 2026-11-15 | Vite 6 en lugar de 7 | El equipo de desarrollo usa Node 20.10; Vite 7 pide Node 20.19 o superior |
| 2026-11-15 | El horario muestra 7 días a partir de hoy, no de lunes a domingo | Un domingo, la semana natural ya ha pasado entera |
| 2026-11-15 | Alumno de ejemplo: Elena Díaz, cinturón azul con 2 grados | Coincide con las iniciales "ED" y los datos de las maquetas |
| 2026-11-15 | Docker Desktop + Supabase local para desarrollar; proyecto en la nube solo para producción | Las pruebas de permisos crean y borran datos; nunca contra datos reales |
| 2026-11-15 | Solo el propietario cambia roles (trigger), con registro en `audit_log` | SPEC: "solo el propietario gestiona roles"; auditoría de datos sensibles |
| 2026-11-15 | Menores sin cuenta se crean con `add_minor` (SECURITY DEFINER) en lugar de permitir insertar perfiles desde el cliente | Un cliente no puede crear perfiles sueltos; el tutor queda ligado en la misma transacción |
| 2026-11-15 | Sin variables de Supabase, la app funciona en modo demo | Se puede enseñar sin servidor |
| 2026-11-15 | Horario e instructores tomados de itacajiujitsu.com | Petición del propietario; profesor por clase y aforo no publicados, quedan editables |
| 2026-11-15 | Plantillas con varios días (`weekdays[]`) y hora local; sesiones en UTC | Una clase L·X·V se edita una vez; el cambio de hora no mueve las clases |
| 2026-11-15 | Editar una plantilla borra y regenera sus sesiones futuras | Sencillo mientras no hay reservas en la base; se revisa en el paso 3 |
| 2026-11-15 | `staff_directory` como vista en lugar de abrir `profiles` a los alumnos | El alumno necesita el nombre del profesor, no su fecha de nacimiento ni su contacto |
| 2026-11-15 | Reservas solo mediante `book_session` / `cancel_booking` (sin permiso de escritura directa) | Las reglas (aforo, plazo, edad) no se pueden saltar desde el cliente |
| 2026-11-15 | Contadores de ocupación en `class_sessions` mantenidos por trigger | Los alumnos ven cuántos van sin ver quiénes; además permite el tiempo real con RLS |
| 2026-11-15 | Bloqueo de la fila de la sesión (`for update`) al reservar | Garantiza una plaza y una espera con peticiones simultáneas; probado con dos conexiones |
| 2026-11-15 | Regla de edad provisional: infantil según la plantilla; menores de 14 no reservan adultos | El plan de tarifas (paso 6) afinará qué puede reservar cada uno |
| 2026-11-15 | Los alumnos ven quién va a cada clase (petición del propietario) mediante `session_attendees` | Muestra nombre y foto sin abrir fecha de nacimiento ni contactos; de menores solo el nombre de pila |
| 2026-11-15 | Fotos de perfil en cubo privado con URLs firmadas | Son datos personales de imagen: solo los ven miembros del mismo gimnasio |
| 2026-11-15 | Asistencia solo por funciones con `client_id` del móvil; se anula en lugar de borrar | Reenvíos sin duplicados (modo avión) y registro completo |
| 2026-11-15 | Cartel QR fijo con el código de la sede; el servidor elige la clase | Coste cero (plan); la ventana de horario y la sesión iniciada frenan el abuso |
| 2026-11-15 | Dependencias `jsqr` (leer QR) y `qrcode-generator` (dibujar QR) | El plan prevé una librería de QR; ambas sin dependencias y generan/leen en el propio móvil |
| 2026-11-15 | El código de check-in de la sede no es legible por los alumnos (permisos por columna) | Que no se pueda fichar sin estar delante del cartel |
