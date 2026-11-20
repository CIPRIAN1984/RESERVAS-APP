# Progreso

Última actualización: 15 de noviembre de 2026 (paso 4).

## Hecho

**Paso 0 (parcial) — cimientos del cliente**

- Proyecto Vite + React 19 + TypeScript + Tailwind 4, React Router 7.
- PWA instalable: manifiesto, iconos provisionales, service worker con caché de la app (vite-plugin-pwa) y pantalla de instalación guiada para iPhone y Android (`/instalar`).
- Tokens de diseño en `src/styles/tokens.css` (colores, fuentes locales, modo oscuro).
- Componentes base: botones, chips, tarjetas, barras de progreso, cinturón, hojas inferiores, avisos.

**Prototipo de las 11 pantallas del diseño, navegable y con datos de ejemplo**

- Alumno: Hoy, Horario (7 días, filtros, 3 semanas), Detalle de clase, Progreso, Tarifas, Perfil, ITACA+ (buscador, filtros, currículos) y Vídeo.
- Personal: Pasar lista (con cola sin conexión y "hoy toca"), Alumnos, Horario, Cobros, Monitores, Ficha de monitor (asignar currículo, sustituto, exportar horas en CSV).
- Reglas de negocio en `src/lib/logic.ts` con 13 pruebas: generar sesiones desde plantillas y saltar cierres, reservar con aforo y lista de espera, bloqueo por deuda o plan, cancelar con plazo y promoción del primero en espera, ventana de check-in, asistencia idempotente.
- Exportar mis datos (JSON) desde Perfil.

**Paso 1 — personas, roles e inicio de sesión** ✅

- Supabase local (Docker) con tres migraciones en `supabase/migrations/`:
  - `gyms`, `profiles`, `gym_members` (owner, admin, coach, front_desk, member), `guardianships` y `audit_log`.
  - Alta automática del perfil al registrarse.
  - RLS por rol: el alumno ve solo lo suyo y lo de sus menores; profesor y recepción ven a los alumnos de su sede; recepción y admin dan de alta alumnos; solo el propietario cambia roles y el cambio queda en auditoría.
  - `add_minor`: el tutor da de alta a un menor de 18 sin cuenta propia.
- 42 pruebas pgTAP en `supabase/tests/` (`npm run test:db`). Comprobado que fallan si se abre un permiso.
- `supabase/seed.sql`: sede ITACA y un usuario por rol (`propietario@`, `admin@`, `cipri@`, `boris@`, `marta@`, `recepcion@`, `elena@`, `carlos@itaca.test`).
- Cliente: pantalla Entrar con enlace mágico, rutas protegidas, la vista del personal solo con rol de personal, sesión y cierre en Perfil. Probado en el navegador con el profesor y con un alumno.
- Sin `.env.local`, la app sigue en modo demo.

**Paso 2 — horario** ✅

- Horario real de ITACA tomado de itacajiujitsu.com (17 clases semanales, de lunes a sábado) e instructores Cipri, Boris y Marta. La web no dice quién da cada clase ni el aforo: quedan "por asignar" y con aforo provisional.
- Migración `…_schedule.sql`: `disciplines`, `class_templates` (días, hora local, duración, aforo, profesor), `class_sessions` (UTC), `closures`.
- `generate_sessions(sede, semanas)`: crea las sesiones desde las plantillas en hora de Madrid, salta cierres y no duplica. Tarea nocturna con `pg_cron` que mantiene 4 semanas por delante.
- Un cierre cancela las clases de esos días y, si se quita, vuelven. Editar o desactivar una plantilla rehace sus sesiones futuras.
- Vista `staff_directory`: los alumnos ven el nombre del profesor, no sus datos personales.
- 27 pruebas pgTAP nuevas (69 en total): generación de 4 semanas, cambio de hora del 25/10, cierres, permisos. Comprobado que fallan si se rompe la zona horaria, los cierres o los permisos.
- Cliente: con sesión iniciada, Hoy, Horario, Detalle y Pasar lista leen las sesiones de la base; las clases canceladas se muestran como tales. Editor de horario y cierres para propietario y administración (`/staff/horario/editor`). Probado en el navegador: asignar profesor y añadir un cierre.

**Paso 3 — reservas** ✅

- Migración `…_bookings.sql`: tabla `bookings` (solo lectura para los usuarios: se escribe con funciones), contadores de ocupación en `class_sessions` mantenidos por trigger.
- `book_session`: bloquea la clase, valida miembro, estado, hora y edad (infantil según la edad de la plantilla; menores de 14 no van a adultos), da plaza o puesto en la lista de espera. Idempotente. Tutor y recepción pueden reservar por otro.
- `cancel_booking`: marca la cancelación tardía según el plazo de la sede y sube al primero de la lista de espera.
- `my_bookings`: mis reservas y las de mis menores con su puesto en la lista.
- Editar una plantilla ya no borra clases con reservas.
- Tiempo real (Supabase Realtime) de la ocupación y de mis reservas.
- 34 pruebas pgTAP nuevas (103 en total) y `npm run test:concurrency`: **dos reservas simultáneas a la última plaza dan una plaza y una espera**. Comprobado que, sin el bloqueo, la prueba falla con dos plazas.
- Seed con 27 alumnos de ejemplo y reservas en las clases futuras.
- Cliente: Hoy, Horario, Detalle de clase, nueva pantalla **Mis reservas** y Pasar lista usan las reservas reales. Probado en el navegador: lista de espera (puesto 3), subida automática a plaza en directo al cancelar otros, cancelar, lista del profesor.

**Quién va y fotos de perfil** ✅

- `session_attendees`: cualquier miembro de la sede ve quién va a una clase (nombre y foto; de los menores, solo el nombre de pila). No se abre el resto del perfil.
- Fotos en un cubo privado `avatars`: cada usuario sube y borra solo en su carpeta; las ven él y los miembros de sus sedes. La app recorta y reduce a 512 px (JPEG) antes de subir. Un perfil solo puede apuntar a una foto de su propia carpeta.
- 14 pruebas pgTAP nuevas (117 en total). Comprobado que fallan si se abren las fotos o la lista a otra sede.
- Cliente: foto en Perfil (añadir, cambiar, quitar), en la cabecera de Hoy, en "Quién va" del detalle de clase y en Pasar lista. Probado en el navegador.

**Tarifas reales (adelanto del paso 6)** ✅

- Tabla `plans` con las 10 tarifas vigentes: 1 Día por Semana (30 €/mes, 4 sesiones), Bjj White (50 €, 8), Blue (60 €, 12), Black (70 €, 16), Corral (80 €, 32), Fundador (50 €, ilimitado), Bono 10 Clases (70 €, 3 meses), Bjj Kids (40 €/mes, 8), Anual BJJ Kids (300 €/año) y Pase por un Día (10 €).
- La ven los miembros; la editan propietario y administración. 6 pruebas pgTAP nuevas (123 en total).
- Pantalla Tarifas con pestañas Membresías y Clases sueltas. Elegir una tarifa avisa a recepción; suscripciones y cobros siguen en el paso 6.
- Dudas abiertas: el Bono 10 figura en la app actual como "10 sesiones/mes, renovable" pero su descripción dice "máximo 3 meses" (se ha registrado como bono de 3 meses sin renovación); Fundador cuesta lo mismo que Bjj White con sesiones ilimitadas (¿solo para socios fundadores?).

**Paso 4 — asistencia** ✅

- Migración `…_attendance.sql`: tabla `attendances` (no se borra: se anula), con `client_id` generado en el móvil y único.
- `check_in`: el personal marca a cualquier miembro (hasta un día después, para listas hechas sin red); el alumno o su tutor solo dentro de la ventana (30 min antes, 15 después). Sin reserva, ficha si queda plaza y se le crea la reserva. `uncheck` anula. Reenviar la misma marca o anulación no duplica nada.
- `check_in_by_code`: el QR de la entrada (`itaca:checkin:<código>`) elige la clase con reserva o la abierta con plaza. El código solo lo ve el personal (`gym_checkin_code`).
- 30 pruebas pgTAP nuevas (153 en total). Comprobado que, sin la protección contra duplicados, fallan 7.
- Cola sin conexión (`src/lib/offlineQueue.ts`, 10 pruebas): se guarda en el móvil, envía en orden al volver la red, descarta lo que el servidor rechaza.
- Pasar lista con asistencia real y aviso de cambios pendientes; lector de QR con la cámara (con código escrito como alternativa); modo kiosco (`/staff/kiosco`) con el QR de la sede y quién va fichando.
- **Hecho cuando: "se pasa lista en modo avión y sincroniza sin duplicados"** — probado en el navegador cortando el servidor: 3 marcas y una corrección en cola, al volver la red 3 filas para 3 personas. En las pruebas aparecieron dos fallos (la lista no reflejaba la cola y no se refrescaba tras sincronizar); corregidos y repetida la prueba.

**Perfil, cinturones, estadísticas y pantallas grandes** ✅ (16/11/2026)

- Migración `…_profile_ranks.sql`: teléfono en el perfil, tabla `promotions` (historial de cinturones, incluidos los infantiles), `set_my_rank` (el alumno indica su cinturón solo mientras el personal no haya registrado uno), `promote` (personal docente, queda en auditoría), `gym_roster` (lista de miembros con cinturón para el personal) y `my_attendance_days` (asistencia por día).
- 20 pruebas pgTAP nuevas (173 en total). Encontrado y corregido un empate al registrar dos cambios de cinturón el mismo día.
- Editar perfil: nombre, fecha de nacimiento, teléfono, contacto de emergencia, foto y cinturón.
- Alumnos (personal): lista real con cinturón y clases de los últimos 30 días; registrar graduación o corregir el cinturón. Pasar lista muestra el cinturón real.
- Progreso y Hoy con estadísticas reales; las barras de "Clases por mes" se pueden pulsar y muestran el calendario de ese mes con los días entrenados (7 pruebas nuevas de cálculo).
- Tablet y portátil: menú lateral, contenido centrado más ancho, dos columnas en Progreso y Alumnos, ventanas centradas en lugar de hojas inferiores.
- Publicado en producción.

**Plan de mejora, fases 1 y 2: estilo y navegación** ✅ (18/11/2026)

- Tema oscuro por defecto, con claro o "como el sistema" en Perfil → Ajustes de la app (se aplica antes de pintar la página).
- Cuatro pestañas de iconos (Inicio, Estadísticas, Novedades, Perfil); Inicio con mes, semana desplegable a mes completo y las clases del día; tarjeta de clase con profesor y compartir.

**Plan de mejora, fase 3: cuenta** ✅ (18/11/2026)

- Entrar con correo y contraseña (o con enlace), crear cuenta, olvidé mi contraseña, poner o cambiar la contraseña y eliminar la cuenta (Perfil → Configuración de la cuenta).
- Migración `…_accounts.sql`: quien se registra queda **pendiente** hasta que recepción o administración lo activen en Alumnos (filtro "Pendientes"); con `gyms.settings.auto_approve_members = true` entra activo. `delete_my_account` cancela las reservas futuras, anonimiza el perfil (la asistencia queda sin nombre) y borra el acceso; el último propietario no puede borrarse.
- 14 pruebas pgTAP nuevas (187 en total). Probado de principio a fin en local: registro, activación, entrar, contraseña errónea, recuperar contraseña con el correo, cambiarla y eliminar la cuenta.
- Contraseña mínima de 8 caracteres; en producción se confirma el correo al registrarse.
- Corregido en producción: el service worker podía guardar `index.html` en lugar de un `.css` si se instalaba mientras se publicaba (Cloudflare responde con la página a cualquier ruta que no existe) y la app se quedaba sin estilos. Ahora la página siempre se pide a la red y `public/sw-guard.js` rechaza y limpia esas copias erróneas.

**Plan de mejora, fase 4: perfil completo** ✅ (18/11/2026)

- Perfil nuevo: tarjeta con foto, nombre, cinturón y roles; selector "Tú / hijos" cuando hay menores a cargo; accesos Membresías y Documentos; aviso "Conecta tu móvil" (se puede ocultar) y el menú de la referencia.
- Pantallas nuevas: Perfiles (añadir menor y editar sus datos, contacto de emergencia y cinturón), Promociones (cinturón actual e historial en línea de tiempo, también de cada hijo), Contacto de emergencia (sale de Editar perfil), Facturación y pago (datos opcionales para la factura; pago en recepción), Contactar con soporte (WhatsApp, correo, teléfono, dirección, Instagram y web de la sede) y Documentos (vacía por ahora).
- Exportar mis datos pasa a Ajustes de la app → Privacidad.
- Migración `…_profile_menu.sql`: datos de facturación en el perfil y `gym_contact` (contacto público de la sede, tomado de la web). 10 pruebas pgTAP nuevas (197 en total) y 3 de Vitest (33).
- Probado en el navegador en móvil y portátil, tema oscuro y claro: cinturón de un hijo guardado y visible en su historial; facturación y contacto de emergencia guardados y recuperados al recargar.

**Límite de clases por tarifa y aforo 50** ✅ (18/11/2026, adelanto de la fase 7)

- Reglas acordadas con ITACA: mes natural; "1 Día por Semana" es una clase por semana (lunes a domingo, 5 en un mes de 5 semanas); bonos y pases, clases en total mientras dure la tarifa.
- Cuenta como clase usada: una reserva de una clase que aún no ha terminado, una asistencia, o un no presentado en una clase en la que alguien se quedó fuera (llena o con lista de espera). Las canceladas no cuentan y la lista de espera no gasta clase.
- Al liberarse una plaza sube el primero de la espera que aún tenga clases. El check-in sin reserva también respeta el límite.
- Recepción y administración pueden apuntar a alguien por encima del límite; queda en auditoría.
- Migración `…_plan_limits.sql`: tabla `member_plans` (tarifa asignada, con fechas), `assign_plan`, `end_plan`, `my_plan_status`, `book_session` y `cancel_booking` con la comprobación; columna `plans.weekly_sessions`. Aforo de todas las clases: 50 (también por defecto en el editor).
- Sin tarifa asignada se puede reservar sin límite mientras la sede no active `settings.require_plan_to_book`, para que nadie se quede sin reservar mientras recepción asigna las tarifas.
- Pantallas: Alumnos → ficha → Tarifa (asignar, cambiar o dar de baja, y lo que le queda); Inicio y Tarifas muestran "Te quedan 3 de 4 clases este mes"; al pasarse del límite, el mensaje explica por qué.
- 24 pruebas pgTAP nuevas (221 en total) y 6 de Vitest (38). Probado en el navegador: Carlos (1 por semana) reserva una clase y la segunda de la misma semana se rechaza; recepción le cambia la tarifa y el contador se actualiza.
- En el modo demo (sin servidor) no se aplica el límite.

**Plan de mejora, fase 5: estadísticas con ranking** ✅ (18/11/2026)

- Estadísticas con dos pestañas y selector de periodo (semana, mes natural, año):
  - **Ranking:** podio de los tres primeros con corona, lista con foto, nombre, cinturón y clases, empates en el mismo puesto y mi fila fija abajo en amarillo.
  - **Actividad:** resumen (clases, días entrenados, racha), rendimiento frente al periodo anterior hasta el mismo día, tendencia de las últimas 8 semanas, cinturón y progreso, clases por mes con detalle por días y actividad reciente.
- Migración `…_ranking.sql`: `gym_ranking` (solo miembros activos de la sede; cuentan las asistencias no anuladas; los menores nunca aparecen) y `profiles.hide_from_ranking`.
- Ajustes de la app → Privacidad: "Aparecer en el ranking" (activado por defecto).
- 12 pruebas pgTAP nuevas (233 en total) y 7 de Vitest (45). Corregido en las pruebas del navegador: el ranking no mostraba el cinturón de los demás.

**Portada con transición "agujero negro"** ✅ (18/11/2026)

- Antes de entrar: fondo negro satinado, logotipo nuevo de ITACA (redibujado en vector a partir de "Logro Rebrand itaca.png") y el nombre con letras espaciadas; botón "Entrar".
- Al pulsarlo, el logotipo y las letras se deshacen en partículas que caen en espiral hacia un agujero negro que crece con un halo, la cámara se acerca y todo queda negro; después aparece la pantalla de acceso. Dura unos 2,6 s. Se ve una vez por sesión del navegador. Con "reducir movimiento" en el sistema solo funde a negro.
- `src/components/BrandMark.tsx` (logotipo en SVG y en lienzo) y `src/features/auth/Cover.tsx`. Colores de marca en `tokens.css` (`--brand-cream`, `--brand-black`). La pantalla de acceso usa ya el logotipo nuevo.
- Logotipo nuevo en toda la app: icono de la app instalada y de la pestaña (fondo negro, logotipo crema), menú lateral y tarjetas de clase. Los PNG se generan con `python3 scripts/icons.py public` (sin dependencias).

**Gestión del horario por administración** ✅ (18/11/2026)

- Personal → Horario (propietario y administración): botón "Añadir clase este día" (clase puntual) y, en cada clase, el engranaje para cambiar solo ese día (aforo, profesor sustituto, lugar), cancelarla con un motivo que ven los alumnos, recuperarla, pasar lista o editar la clase semanal.
- Editar horario: "Nueva clase semanal", "Clase puntual" y "Eliminar esta clase del horario" (las próximas sin reservas se borran; las que tienen reservas quedan canceladas; el historial se conserva).
- Migración `…_schedule_admin.sql`: `delete_class_template`, `create_one_off_session`, `cancel_session`, `restore_session` y `update_session` (al subir el aforo sube la lista de espera, respetando la tarifa). Todo queda en auditoría. 18 pruebas pgTAP nuevas (251 en total).
- Pendiente: mover la hora de un solo día (hoy: cancelar ese día y crear una clase puntual) y avisar a los apuntados cuando se cancela (paso 7).

**Clases: una sola lista, papelera y "cada semana / solo un día"** ✅ (18/11/2026)

- Sin "Generar 4 semanas": las clases semanales se crean solas con tres meses (12 semanas) de antelación al guardarlas, cada noche y al quitar un cierre.
- Personal → Horario → "Clases y cierres": lista "Cada semana" (con "todos los meses" o "hasta el …") y "Solo un día", con papelera a la derecha de cada clase y confirmación.
- Nueva clase: "Cada semana" (días, empieza el, todos los meses o hasta una fecha) o "Solo un día". Editar permite pausar la clase.
- En el horario del personal, papelera junto al engranaje para quitar la clase de ese día (si es semanal, solo ese día).
- Migración `…_schedule_horizon.sql`: horizonte de 12 semanas, fechas de inicio y fin respetadas al editar, `delete_session` y regenerar al quitar un cierre. 9 pruebas pgTAP nuevas (260 en total).
- Encontrado en producción: "Avanzados No Gi" (lunes y viernes, 19:00) creada dos veces el 18/11; hay que borrar una con la papelera.

**Cambios de hora sin clases sueltas, aviso de duplicadas y mes completo** ✅ (18/11/2026)

- Fallo corregido: al cambiar la hora de una clase semanal, la sesión de un día con reservas se quedaba con la hora antigua y, al cancelar la reserva, quedaba suelta junto a la nueva. Ahora las reservas pasan a la sesión nueva de ese día y la antigua desaparece; si ese día ya no hay clase, se cancela. La migración `…_move_bookings_on_edit.sql` limpió la sesión suelta de producción (Avanzado Gi del 20/11 a las 18:30). 7 pruebas pgTAP nuevas (267 en total).
- Al crear una clase semanal el mismo día y a la misma hora que otra, avisa y pide confirmación.
- Horario del personal: icono de calendario para ver el mes completo (hasta tres meses vista) y saltar a cualquier día.

**Botones de reserva** ✅ (19/11/2026)

- "Reservar clase" pasa a amarillo al pasar el ratón y, al conseguir plaza, se convierte durante 1,6 s en "¡A entrenar!" amarillo con un pequeño rebote; después aparecen Check-in y Cancelar.
- Cancelar una reserva: botón coral con texto blanco (`--coral`, `--on-coral` en `tokens.css`), en Inicio, el detalle de la clase y Mis reservas. Salir de la lista de espera sigue con borde.

**Plan de mejora, fase 6: novedades** ✅ (19/11/2026)

- Pestaña Novedades: avisos del gimnasio con los fijados arriba, autor y fecha ("hace 3 h"), "Mostrar más" en los largos y "Ver avisos anteriores". Se actualiza sola cuando alguien publica (tiempo real) y el icono de la pestaña lleva un punto amarillo si hay avisos sin ver.
- Personal (propietario, administración, recepción y profesores): "Nuevo aviso", editar, fijar arriba y borrar desde la misma pestaña; también desde Personal → Más → Novedades. Cada uno edita los suyos; propietario y administración, todos.
- Migración `…_announcements.sql`: tabla `announcements` con permisos, `gym_announcements` (con nombre del autor y si se puede editar) y tiempo real. 12 pruebas pgTAP nuevas (279 en total).
- Check-in también se pone amarillo al pasar el ratón.

**Hover amarillo en todos los botones** ✅ (19/11/2026)

- `<Btn>` (todas sus variantes salvo cancelar, que se oscurece) y los filtros se ponen amarillos al pasar el ratón. Para los controles hechos a mano, utilidades `.hy` (fondo amarillo) y `.hy-text` (texto amarillo, filas de menú) en `tokens.css`; lo seleccionado conserva su aspecto. Solo en dispositivos con ratón.

**Plan de mejora, fase 7: membresías** ✅ (19/11/2026)

- Perfil → Membresías: "Mis membresías" con la tarifa vigente del alumno y de cada hijo (válida hasta, o se renueva cada mes, y clases que le quedan), solicitud pendiente con "Retirar" y tarifas anteriores.
- "Productos disponibles" (Membresías / Clases sueltas): "Solicitar" envía la petición a recepción; con hijos, pregunta para quién. Se paga en recepción.
- Recepción: aviso en Alumnos ("Noa ha pedido Bjj Kids"), filtro "Solicitudes", etiqueta en la lista y, en la ficha, "Asignar Bjj Kids" con la tarifa ya elegida. Al asignarla, la solicitud queda atendida sola.
- Migración `…_plan_requests.sql`: tabla `plan_requests` (una pendiente por persona), `request_plan`, `cancel_plan_request`, `pending_plan_requests` y cierre automático al asignar. 10 pruebas pgTAP nuevas (289 en total).

**ITACA+ a 5 €/mes, como complemento** ✅ (19/11/2026)

- ITACA+ es una tarifa complemento (`plans.is_addon`) de 5 €/mes: se suma a la tarifa principal, no la sustituye, y no cuenta para el límite de clases.
- Solo se puede pedir y asignar con una tarifa de pago recurrente activa (membresía que se renueva y cuesta dinero); si esa tarifa termina, ITACA+ deja de funcionar (`has_itaca_plus`). Un bono o un pase no valen.
- Membresías: tarjeta ITACA+ con el precio, "Solicitar ITACA+", "Has pedido ITACA+" con Retirar, "Activo · Ir a ITACA+", o desactivado explicando que hace falta una tarifa mensual. Recepción lo asigna desde la ficha (aparece como complemento) y ve si está activo.
- Antes, con servidor, ITACA+ salía como suscrito para todos (era un dato de prueba del navegador); ahora lo decide el servidor.
- Migración `…_itaca_plus.sql` (también: una solicitud pendiente por tarifa y tipo). 10 pruebas pgTAP nuevas (299 en total).

**Plan de mejora, fase 8: vista del personal** ✅ (19/11/2026)

- Cobros con datos reales (con servidor): previsto del mes según las tarifas que asigna recepción (mensuales completas, trimestrales y anuales prorrateadas, bonos el mes en que empiezan), alumnos con y sin tarifa, altas y bajas, media por alumno, desglose por tarifa (ITACA+ como complemento) y avisos de alumnos sin tarifa y solicitudes pendientes. Navegación por meses. Antes mostraba cifras de ejemplo también con servidor. Aún no hay "cobrado": llegará con el registro de pagos.
- Más: mismo estilo que el menú del perfil, con iconos, grupos "Gimnasio" y "Próximamente" (sin las etiquetas "Paso 5/8").
- Migración `…_billing_summary.sql`: `gym_billing_summary`. 8 pruebas pgTAP nuevas (307 en total).
- Con esto queda completo el plan de mejora salvo el inicio de sesión con Google.

**Tarifas para el personal, avisos de solicitudes y "Mejorar plan"** ✅ (19/11/2026)

- Personal → Tarifas (sustituye a Cobros en la barra): "Por aprobar" (solicitudes con la tarifa actual, Cambio/Nueva, Aprobar y Rechazar con motivo), "Alumnos" (tarifa actual de cada alumno, filtros sin tarifa, caducan en 14 días y con ITACA+; abre su ficha) y "Previsto" (lo que era Cobros). `/staff/cobros` redirige a Tarifas → Previsto.
- Aviso al personal (recepción y administración) en tiempo real: mensaje emergente "Nueva solicitud: Noa pide Bjj Kids" en cualquier pantalla y número de solicitudes por aprobar en la pestaña Tarifas.
- Alumno: con su tarifa activa solo ve su membresía y "Mejorar plan", que abre las demás para cambiar; si recepción rechaza una solicitud, la ve con el motivo.
- Migración `…_plans_admin.sql`: `staff_plan_overview`, `reject_plan_request` (con `reject_reason`), `pending_plan_requests` con tarifa actual y tiempo real de `plan_requests`. 8 pruebas pgTAP nuevas (315 en total).

**Tarifas: ajustes y filtros** ✅ (19/11/2026)

- Corregido "Tarifas0" en el menú lateral (el contador a cero se pintaba como texto).
- Tarifas → "Previsto" pasa a "Ingresos"; cada tarifa se puede tocar para ver quién la tiene y cuántos son.
- Tarifas → Alumnos y Alumnos incluyen a todos los miembros activos, también al personal que entrena (propietario, profesores), con su rol. Antes solo salían los de rol alumno.
- Alumnos (menú lateral): tarifa de cada persona en la lista, filtro por tarifa (también "Sin tarifa" y "Con ITACA+") y la sección Tarifa en la ficha de cualquier persona (solo para recepción y administración).
- Clases: buscador por nombre o profesor y filtros por disciplina (BJJ Gi, No Gi, Infantil, Open Mat) y día de la semana.
- Migración `…_plans_overview_all.sql`. 2 pruebas pgTAP nuevas (317 en total).

**Roles y monitores desde la app** ✅ (19/11/2026)

- Alumnos → ficha → "Rol en el gimnasio": el propietario elige Alumno, Profesor, Recepción, Administración o Propietario. No se puede dejar la sede sin propietario; los menores y quien no tiene cuenta solo pueden ser alumnos. Queda en auditoría.
- "También da clases" para propietario y administración: aparecen en Monitores y se les pueden asignar clases sin perder su rol. Los profesores, siempre.
- Monitores → "Añadir": eliges a una persona del gimnasio; si es alumno pasa a profesor (solo el propietario), si es propietario o administración se marca que da clases. Quitado el mensaje antiguo "El alta de monitores llega con el inicio de sesión (paso 1)".
- Migración `…_roles_teaching.sql`: `gym_members.teaches`, `staff_directory.teaches` y `set_member_role`. 10 pruebas pgTAP nuevas (327 en total).

## Simulado (sin servidor todavía)

| Qué | Cómo está ahora | Paso del plan que lo hace real |
| --- | --- | --- |
| Cinturones, suscripciones y cobros | `localStorage` del dispositivo, datos de ejemplo en `src/lib/data.ts` | 5–6 |
| Pagos e ITACA+ | "Suscribirme" activa el acceso sin cobrar | 9 (Stripe) |
| Reproductor | Simula el avance; el vídeo real vendrá de Bunny Stream con URL firmada | 10 |
| Métricas de cobros | Cifras fijas de ejemplo | 6 y 8 |

## Pendiente del paso 0

- [x] Supabase local con Docker.
- [x] Proyecto de Supabase en la nube (París) con las migraciones, el horario y las tarifas (16/11/2026).
- [x] Publicada en Cloudflare Pages: https://itaca-jiu-jitsu.pages.dev (ver `docs/PRODUCCION.md`).
- [ ] Correo propio (SMTP) para los enlaces de acceso: el de Supabase gratuito envía muy pocos por hora.
- [ ] Probar la instalación en un Android y un iPhone reales.
- [ ] Nombre, icono y color definitivos (el icono actual es provisional).

## Pendiente del paso 1

- [ ] Inicio de sesión con Google (necesita credenciales en Google Cloud; se deja para el final del plan de mejora).
- [ ] Correo propio (Resend) antes de abrir la app: el de Supabase solo manda unos pocos por hora.
- [x] Gestión de roles: Alumnos → ficha → Rol en el gimnasio (propietario).
- [ ] Al eliminar la cuenta de un tutor, sus menores quedan sin tutor: decidir si se borran o pasan a recepción.
- [ ] Doble factor para administradores (SPEC, Seguridad y RGPD).

## Pendiente del paso 2

- [ ] Asignar profesor y confirmar aforo de cada clase (datos que no están en la web).
- [ ] Confirmar si lunes y miércoles tienen solo dos clases, como dice la web.
- [ ] Clases puntuales y sustituciones desde el editor (la base ya las admite).

## Pendiente del paso 3

- [ ] Avisar al alumno que sube de la lista de espera (push y email, paso 7).
- [ ] Si se cambia la hora de una clase con reservas, la sesión antigua se mantiene y aparece la nueva: hace falta avisar y mover las reservas a mano.
- [ ] Deuda al reservar (paso 6). El límite de clases por tarifa ya está.
- [ ] Activar `require_plan_to_book` cuando recepción haya asignado la tarifa a todos.
- [ ] Pantalla para que el tutor reserve por sus hijos (la función ya lo permite).

## Pendiente del paso 4

- [ ] Abrir la app **sin** cobertura: hoy la lista debe haberse cargado antes de perder la red (el horario aún no se guarda en el móvil; TanStack Query con caché persistida, previsto en el plan).
- [ ] Probar la cámara en un iPhone y un Android reales (en el navegador de pruebas no hay cámara; se probó con el código escrito y leyendo el QR generado).
- [ ] Añadir a la lista a un alumno sin reserva desde la búsqueda (hoy se hace con su check-in por QR).
- [ ] QR que cambia cada 30 s, solo si aparece picaresca con el cartel fijo.

## Siguiente paso

Paso 5 (lo que queda): reglas de graduación configurables por cinturón (hoy el objetivo es provisional: 60 clases y 6 meses), filtro "listo para graduar", importación y exportación CSV.
