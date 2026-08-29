# Decisiones técnicas

## 2026-07-23 — Permisos explícitos para funciones Supabase

Las funciones del esquema `public` se consideran API remota porque PostgREST
puede exponerlas como RPC. Por tanto:

- `PUBLIC`, `anon` y `authenticated` no reciben `EXECUTE` por defecto.
- Cada migración debe conceder explícitamente las RPC que necesite Flutter.
- Las funciones internas, de trigger, cron o mantenimiento quedan accesibles
  solo para su propietario y `service_role`.
- Las funciones fijan `search_path`; no dependen del valor de la sesión.
- Las funciones `SECURITY DEFINER` deben validar identidad y rol cuando sean
  RPC públicas. Los avisos restantes del Security Advisor se revisan como
  excepciones explícitas, no se ignoran globalmente.

Motivo: reducir la superficie RPC, evitar que helpers internos se conviertan
en endpoints y mantener los permisos reproducibles entre entornos Supabase.

## 2026-07-27 — Bootstrap del Administrador inicial fuera del registro público

El primer Administrador se crea a partir de un usuario de Auth con correo
confirmado mediante `bootstrap_initial_admin`. La función:

- solo es ejecutable por `service_role` y por el propietario de la base;
- usa un bloqueo transaccional para impedir carreras;
- solo funciona mientras no exista ningún Administrador;
- no convierte perfiles ya existentes ni acepta usuarios anónimos;
- nunca se invoca desde Flutter ni depende de metadata controlada por cliente.

Motivo: el alta pública debe limitarse a Dueños y Alumnos. Un secreto de
bootstrap en el cliente permitiría autoascensos y no puede protegerse en una
aplicación web o móvil.

## 2026-07-27 — Observabilidad con minimización de datos

La capa de errores de Flutter continúa centralizada en `Observability` y solo
se activa cuando el despliegue aporta un `SENTRY_DSN`.

- `sendDefaultPii`, las capturas de pantalla, la jerarquía visual y la captura
  automática de peticiones fallidas permanecen desactivadas.
- El usuario se identifica únicamente por su UUID interno, sin nombre ni
  correo.
- La versión reportada es el commit del despliegue.
- En producción se muestrea el 5 % de las trazas; los errores siguen
  capturándose.
- Sin Sentry, los errores controlados solo muestran tipo y contexto en modo
  debug; no se imprime su contenido en builds de producción.

La disponibilidad web se vigila con una prueba sintética de solo lectura sobre
el dominio canónico y las rutas críticas. Web Analytics y Speed Insights no se
activan automáticamente porque su uso y coste requieren una decisión separada.

## 2026-07-27 — Identidad y firma de las aplicaciones móviles

Se conserva `com.itaca.itaca` como identificador candidato de Android e iOS
porque ya forma parte del código nativo y de los deep links. Debe comprobarse
su disponibilidad en Google Play Console y Apple Developer antes de la primera
alta; después del primer binario no se cambia.

Las compilaciones Android de producción nunca usan la clave debug. La firma se
inyecta desde secretos de GitHub y se entrega como Android App Bundle para Play
App Signing. iOS requiere firma administrada por la cuenta Apple y una
distribución posterior desde Xcode o App Store Connect.

La configuración Firebase se inyecta por plataforma durante la compilación y
no se comparte con otros proyectos. El cliente solo habilita push cuando
`PUSH_ENABLED=true`. `send-push` se despliega sin verificación JWT porque lo
invoca un programador, pero falla de forma cerrada si `CRON_SECRET` no existe o
no coincide.

## 2026-07-29 — Eliminación definitiva del árbol de progreso

El módulo de técnicas (pantallas, tablas `tecnicas`, `media_tecnica` y
`progreso_alumno_tecnica`, sus funciones y disparadores) se retira de raíz por
decisión de producto. No se vuelve a proponer.

Motivo: las técnicas que contenía eran una plantilla genérica de BJJ de relleno
—no el método Ítaca, que vive en el repositorio `itacaplus` y no se replica
aquí—, y mantener un módulo vacío de significado añadía superficie de código,
de base de datos y de permisos sin aportar nada al lanzamiento.

Comprobación previa al borrado, ejecutada contra producción antes de aplicar
`20260729090000_eliminar_arbol_progreso.sql`:

- `tecnicas`: 14 filas, exactamente las 14 de la plantilla sembrada por trigger.
- `media_tecnica`: 0 filas.
- `progreso_alumno_tecnica`: 14 filas, todas en el estado por defecto
  (`bloqueada`) y todas con `marcado_por = NULL`.

Es decir, ninguna fila creada ni evaluada por una persona: el borrado no
destruyó trabajo de nadie. La operación es irreversible.

`aprobar_academia` se redefinió **antes** de borrar `sembrar_tecnicas_default`,
para que la RPC no quedara en ningún momento apuntando a una función
inexistente. Dos suites pgTAP que antes comprobaban la siembra ahora comprueban
lo contrario: que el módulo sigue eliminado.

Aplicada a producción el 29/07/2026, a la vez que se fusionó el rediseño I+.

## 2026-07-30 — El cambio de modo baja a la barra inferior

El botón para saltar entre **Entrenamiento** y **Gestor** era un botón
flotante. Se ha movido al último sitio de la barra inferior, visible solo para
dueño y profesor.

Motivo: en un móvil de 412 px de ancho no caben dos botones flotantes uno al
lado del otro. El de modo mide 177 px y el de la acción de la pantalla
(«Crear clase») mide 234 px; sumados con los márgenes pasan de 440 px. Estando
centrado tapaba «Reservar plaza» y la última fila de Perfil; llevándolo a la
izquierda seguía solapándose 31 px con «Crear clase». No era un problema de
colocación sino de sitio: sobra un botón flotante.

Lo global va a la barra; el aire se reserva a la acción principal de cada
pantalla. Como efecto lateral, el cambio de modo pasa a estar siempre visible y
con su nombre escrito, en vez de depender de un icono y de una pulsación larga
para ver el rótulo.

Reglas que quedan y están cubiertas por pruebas
(`test/shared/botones_flotantes_test.dart`):

- En modo Entrenamiento no hay ningún botón flotante en Inicio.
- El botón de la pantalla nunca se solapa con la última tarjeta de su lista:
  las listas de pantallas **con** botón flotante llevan
  `espacioBotonesFlotantes` de hueco al final.
- Las pantallas **sin** botón flotante no llevan ese hueco: solo dejaría un
  vacío al final.

Los rectángulos se comparan enteros, no los de sus textos: una primera versión
de la prueba comparaba el texto del botón, que es más pequeño, y daba por bueno
un solape real de 31 px.

## 2026-07-30 — Apuntarse a clase sin tener la cuota pagada

`reservar_clase` rechazaba a cualquier Alumno sin suscripción activa y
cobrada. Pasa a ser un ajuste por academia, `exigir_cuota_para_reservar`, y
**por defecto no se exige**.

Motivo, en palabras de Cipri: prefiere que la gente se pueda apuntar aunque
no haya pagado y verlo marcado en la lista de la clase, para cobrarles en
mano cuando aparezcan por el gimnasio. Es como funciona hoy el negocio: la
gente entrena y paga cuando pasa por recepción.

Se hace con un interruptor y no quitando la comprobación, para poder volver
atrás desde la propia app sin tocar la base de datos. El ajuste vive en
Academia → Ajustes de reservas y solo lo cambia el Dueño.

Lo que **no** cambia: sigue haciendo falta cuenta activa, pertenecer a la
academia, que la clase sea futura, el aforo y la lista de espera.

En la lista de la clase, quien no tiene la cuota al día sale con una pastilla
roja «Sin cuota», hay un recuento arriba, y tocar su fila abre directamente
el cobro en efectivo. Las condiciones que decide esa marca son **las mismas**
que comprueba el servidor (activa, cobrada y dentro de fechas): si aquí se
relajaran, la app diría «al corriente» de alguien a quien el servidor
considera moroso.

Cubierto por `supabase/tests/reservar_sin_cuota_test.sql` (12 comprobaciones).
Lo que se protege ahí es que abrir esta puerta no abra ninguna otra: un
alumno no puede tocar el ajuste, ni quitarlo en la academia de al lado, ni
colarse en una clase que no es suya, y el Dueño sigue sin poder cambiar el
estado de su academia por la misma vía.

## 2026-07-30 — Los botones de la app son de ancho completo, y eso se nota

Causa raíz de tres fallos que Cipri fue encontrando por separado: el nombre
de la tarifa en vertical en «Mi cuota», lo mismo en Préstamos, y el nombre
del alumno estrujado en la lista de una clase.

El tema fija `minimumSize: Size.fromHeight(52)` en los botones, y
`Size.fromHeight` deja el **ancho en infinito**. Un botón así, puesto en el
hueco lateral de un `ListTile`, se queda todo el ancho disponible y al título
le deja una columna de un carácter. Dentro de un `Row` directamente revienta
con «BoxConstraints forces an infinite width».

Norma: la acción va **debajo del texto, a lo ancho** (`TarjetaFila`), y si de
verdad hace falta en línea, se acota con un `SizedBox`. `ListTile` tampoco
admite una pastilla de estado en `subtitle`: no llega ni a medirse.

## 2026-07-31 — Las tarifas pasan a llevar clases por ciclo

Hasta ahora una tarifa era nombre, precio y periodicidad: cuota plana, sin
límite de clases. **No era como funciona el negocio.** Cipri lo describió así:
«2 días por semana son 8 al mes, 3 por semana son 12; si la tarifa empieza el
5 de mayo, hasta el 5 de junio puede gastar las que tiene».

Decisiones tomadas con él el 30 y 31 de julio de 2026:

- **El ciclo es mensual y va de fecha a fecha**, no por mes natural. Del 5 de
  mayo al 5 de junio. `clases_incluidas` es **por mes**, no por periodo de
  cobro: una tarifa trimestral no da 24 clases de golpe, da 8 cada mes y se
  cobra cada tres. La periodicidad es de **facturación**; las clases van por
  mes.
- **Lo que sobra se pierde** al renovar. No se acumula.
- **`clases_incluidas` a NULL significa ilimitada.**
- **Sin clases no se puede reservar.** La app lo rechaza y le dice que renueve
  o compre sueltas.
- **Descuenta el profesor al confirmar la clase**, no el alumno al reservar. Y
  confirma a todos los apuntados, **vengan o no**: quien reserva y no aparece
  pierde la clase igual. Puede cancelar hasta 1 hora antes. Es deliberado:
  sin eso, la gente reservaría toda la semana y vendría cuando quisiera.
- **Pasar lista no es marcar ausentes**, es comprobar que todo el que está en
  el tatami está apuntado — o sea, que ha pagado.

**El agujero que esto deja, y cómo se tapa.** Si la clase solo se descuenta al
confirmar, alguien con 1 clase suelta puede reservar las 8 de la semana: al
reservar, el contador todavía no ha bajado. Por eso el número que decide si
puede reservar descuenta **también lo que ya tiene reservado en este ciclo**.
El descuento de verdad sigue siendo el del profesor; lo reservado solo
bloquea. Así «te quedan 6» es un número honesto y nadie acapara plazas.

**Se cuenta por la fecha de la clase, no por la de validación.** Si el
profesor pasa lista dos días tarde, la clase cuenta en el ciclo en el que se
dio, no en el que se apuntó.

**Cobro recurrente con tarjeta: no todavía.** Cipri quiere que las tarifas se
cobren solas cada mes hasta que él dé de baja. Eso es Stripe, y Stripe sigue
sin conectar a cobros reales. Se construye primero todo el mecanismo
funcionando con **cobro en mano**, que es lo que permite probarlo con gente de
verdad en paralelo con MAAT.

## 2026-07-31 — El calendario pasa a semana, sin puntos de aviso

`CalendarioScreen` usaba `table_calendar` en formato mes: una rejilla de
semanas con un punto negro bajo el día si había clase. Cipri pidió quitar los
puntos («molestan visualmente») y ver **solo la semana entera, lunes a
domingo**.

Al mirarlo, el mes-rejilla ya incumplía la skill `diseno-i-plus`, que desde
julio especifica: *«Calendario semanal — siete pastillas. El día seleccionado
en amarillo eléctrico con texto negro»*. La rejilla de meses y el día
seleccionado en negro (`AppColors.ink`) eran una desviación de esa norma que
nadie había corregido. Se reconstruye conforme a la guía en vez de parchear
la rejilla existente.

- Nuevo `_SemanaPildoras`: siete pastillas lunes-domingo. Seleccionado en
  `AppColors.acid`; hoy (si no está seleccionado) con un anillo fino de
  tinta; el resto, sin decoración. Sin puntos de ningún tipo.
- Se quita la dependencia `table_calendar`: solo la usaba esta pantalla.
- Los proveedores pasan de mes a semana: `visibleMonthProvider` →
  `visibleWeekProvider`, `clasesMesProvider` → `clasesSemanaProvider`. Encaja
  además con lo que ya hacía el servidor — la RPC se llama
  `listar_clases_semana` y antes se le pedía un mes entero para enseñar solo
  siete pastillas, que era pedir de más.
- Encontrado mirando la captura, no por ninguna prueba de comportamiento: la
  etiqueta del día (LUN, MAR…) en gris `subtle` sobre el amarillo de acento
  casi no se leía. En el día seleccionado pasa a tinta. Cubierto por una
  prueba que comprueba el color exacto del texto.

Pendiente: Cipri va a mandar capturas de MAAT para comparar y decidir si hay
algo más que mejorar en esta pantalla.

## 2026-08-02 — Cuarta aparición del botón sin acotar en un `Row`

El botón «Reservar»/«Agotado» del catálogo de tienda (`CatalogoTab`) vivía
suelto dentro de un `Row`, junto al nombre del producto. Por tema, los
botones son de ancho completo (`minimumSize: Size.fromHeight(52)`, ancho
infinito), así que se comía toda la fila y el nombre del producto («kimono»)
se caía en una columna de una letra por línea — capturas de pantalla de
Cipri.

Ya documentado en la skill `diseno-i-plus` §4 tras las tres apariciones
anteriores (una de ellas, `clase_detalle_screen.dart`, ya tiene el arreglo de
referencia: `SizedBox(width: 110)` alrededor del botón). Se aplica el mismo
arreglo aquí. Se añade `test/features/tienda/catalogo_tab_test.dart`, que
falla (con `pumpAndSettle` en bucle infinito) si el botón vuelve a quedar sin
acotar — comprobado revirtiendo el arreglo antes de darlo por bueno.

## 2026-08-02 — Enlace y QR de invitación a la academia

Hoy quien se registra como alumno elige su academia de un desplegable con
**todas las aprobadas de la plataforma**. Para el lanzamiento de una sola
academia eso es fricción de más (elegir entre una lista de una) y, cuando
haya más de una academia en la plataforma, expondría a la competencia. Cipri
pidió un QR/enlace que él pueda mandar directamente a la gente.

- `Routes.registro` acepta ahora un parámetro de consulta `academia` (p. ej.
  `/registro?academia=<id>`). Si viene relleno, `RegistroScreen` **no
  enseña el desplegable**: fija esa academia y solo muestra su nombre en
  modo lectura.
- Nueva pantalla `InvitarScreen` (ruta `/invitar`, solo dueño, junto a
  Equipo/Cobros en Academia): enseña el QR y el enlace completo
  (`https://itc2-reservas.vercel.app/#/registro?academia=<id>`), con un
  botón para copiarlo al portapapeles.
- **Sin migración.** La pantalla de invitación no necesita datos nuevos del
  servidor: el `academia_id` ya lo tiene el dueño en su propio perfil. Y
  como quien abre el enlace **todavía no está autenticado**, comprobar que
  esa academia sigue aprobada usa la misma RPC pública que ya existía para
  el desplegable (`listar_academias_aprobadas`) — no se toca RLS ni se
  añade acceso nuevo a la tabla `academias` para usuarios anónimos.
- Se añade la dependencia `qr_flutter` (dibuja el QR en el propio dispositivo,
  sin llamada de red — nada que romper si hay DNS filtrado).

## 2026-08-03 — El contador de clases pasa a bloquear de verdad

`clases_restantes()` existía desde el 31/07 pero no lo llamaba nadie: ni
`reservar_clase` lo comprobaba, ni el alumno lo veía en ningún sitio. Las
tarifas de «8 clases al mes» eran decorativas — Cipri lo señaló al pedir el
cierre de los obligatorios antes de meter a las ~300 personas de la
academia.

**La distinción que importa, y que no se puede perder:** esto NO es lo mismo
que `exigir_cuota_para_reservar` (30/07/2026). Esa decisión sigue en pie —
por defecto, quien no tiene NINGUNA cuota se puede apuntar igual y sale
marcado «sin cuota» para cobrarle en mano. El bloqueo nuevo es otro caso:
alguien que SÍ tiene una tarifa activa, con número de clases, y ya se las ha
gastado este ciclo. Ahí la app dice que no y le manda a renovar o comprar
una suelta. `reservar_clase` distingue los dos casos llamando a
`clases_restantes()`:

- `tiene_cuota = false` → no se toca nada, sigue el camino de siempre
  (bloquea solo si la academia exige cuota).
- `tiene_cuota = true` y `ilimitada = true` → sin límite, como hasta ahora.
- `tiene_cuota = true`, `ilimitada = false`, `disponibles <= 0` → se
  rechaza. Es el único caso nuevo.

Se reutiliza `clases_restantes()` en vez de repetir la cuenta: una sola
fuente de verdad para «cuántas te quedan», tanto si pregunta el servidor al
decidir como si pregunta la pantalla para enseñarlo.

En Flutter, «Mi cuota» (`TarifasScreen`, vista de alumno) enseña ahora
`incluidas`, `gastadas` y `disponibles` cuando la tarifa no es ilimitada, y
el error de reservar sin clases tiene su propio mensaje en vez de caer en
el genérico «no se ha podido completar la acción».

## 2026-08-08 — ITACA como academia única en v1

La app se lanza con una sola academia: ITACA (la academia de Cipri en Logroño).
La arquitectura multi-academia se preserva en la base de datos para expansión
futura (paso 11), pero el cliente se configura para trabajar solo con ITACA.

**Cambios en el cliente:**

- `AppConfig` añade `itacaAcademiaId` leyendo del `--dart-define` `ITACA_ACADEMIA_ID`.
- `RegistroScreen` ya no muestra un desplegable de academias: siempre fija ITACA.
  La pantalla sigue leyendo `listar_academias_aprobadas()` para validar que ITACA
  existe, pero no para elegir.
- El botón «Crear nueva academia» (`registerOwnerCta`) está comentado — en v1, no
  se permite el alta de nuevas academias.
- La ruta `/registroAcademia` (pantalla de alta de academia) está comentada.
- El rol `administrador` sigue siendo global (sin academia), pero en v1 no hay
  funciones de administración expuestas en Flutter (aprobaciones de academias,
  etc.). Ver §4 de `FREEZE.md`.

**Cambios en la base de datos: ninguno.** Las tablas `academias` y RLS siguen
como estaban. En producción habrá solo una fila en `academias` (ITACA).

**Recuperación en paso 11 (post-lanzamiento):** deshabilitar `ITACA_ACADEMIA_ID`,
descomentar rutas y botón, y reimplementar `AdminAcademiasScreen` con aprobaciones.

## 2026-08-08 — Sincronización de reservas, créditos y lista de espera

El flujo de reservas está completamente integrado y sincronizado:

**Reservar (`reservar_clase`):**
- Verifica que el usuario existe, está activo y pertenece a la academia
- Optionalmente (por academia), exige cuota activa y cobrada
- Si hay cuota con límite de clases, rechaza si no quedan clases
- Inscribe como 'inscrito' si hay plaza, o como 'espera' si la lista está activa
- Rechaza si aforo lleno y sin lista de espera

**Créditos/Cuotas (`clases_restantes()`):**
- Calcula `disponibles = incluidas - gastadas` en el ciclo actual
- Retorna `tiene_cuota`, `ilimitada`, `disponibles` y `ciclo_actual`
- Se reutiliza para mostrar saldo en UI y para bloquear en `reservar_clase`

**Lista de espera (`cancelar_reserva`):**
- Al cancelar, retira de la cola a quienes ya no cumplen condiciones (inactivos o sin cuota)
- Promociona automáticamente al primero de la cola FIFO si hay plazas
- Envía notificación al promovido

**Clases recurrentes (`generar_clases_recurrentes`):**
- Genera instancias futuras respetando zona horaria y cambios DST
- Corre diariamente (si está en el cron) o bajo demanda desde UI

Todas las operaciones son atómicas bajo transacción; las races son evitadas con
`for update` en las selects de `clases` e `inscripciones`. Las pruebas pgTAP
cubren todos los casos: cuota válida/inválida, lista de espera, cancelaciones
tardías, zona horaria, etc.

## 2026-08-08 — Hardening de Auth, RPC, RLS (v1 pre-lanzamiento)

El hardening de seguridad está en su lugar:

**Auth:**
- Solo el alta pública permite registrar Alumnos y Dueños
- El Administrador se crea con `bootstrap_initial_admin` (service_role, no disponible en Flutter)
- Nadie puede cambiar su propio rol ni convertirse en administrador

**RPC (PostgREST):**
- `anon` (sin autenticar) solo tiene acceso a `listar_academias_aprobadas()`
- `authenticated` (usuario logueado) tiene acceso a: `reservar_clase`, `cancelar_reserva`, `registrar_device_token`,
  `cambiar_rol_miembro` (restringida a dueño), `listar_clases_semana`, `ranking_mensual`
- Las funciones internas (triggers, cron, helper) están cerradas a `anon` y `authenticated`
- `service_role` (Edge Functions, backend) puede ejecutar todo

**Permisos en columnas:**
- Tabla `profiles`: columnas `rol` y `estado` tienen `revoke update` + grant explícito a columnas editables
- Tabla `academias`: `stripe_charges_enabled`, `stripe_onboarding_status`, `estado` tienen revoke similar
- Suscripciones: no se puede editar `estado` directamente; la cancelación pasa por una RPC (no implementada aún)

**RLS (Row Level Security):**
- Cada tabla con datos sensibles filtra por `current_academia_id()` (usuario dentro de su academia)
- El `administrador` (rol global) ve todos los registros
- Aislamiento multi-tenant verificado por pruebas pgTAP

**Pendiente para v1 post-lanzamiento:**
- Rate limiting en PostgREST (Supabase lo provee a nivel de plan, requiere configuración)
- Auditoría de cambios en perfiles y configuración de academia (quién cambió qué y cuándo)
- Webhook de Stripe con validación de firma (Edge Function desplegada pero no activada, ver FREEZE.md)

## 2026-08-08 — Errores y reintentos (v1 pre-lanzamiento)

**Manejo de errores:**
- Todos los errores de red/timeout se convierten a mensajes amigables en `mensajeErrorAmigable()`
- Los errores de validación vienen como excepciones de Supabase (ej: "Debes tener una cuota activa")
- Sentry captura automáticamente errores no controlados (opcional, requiere SENTRY_DSN)

**Reintentos:**
- Las operaciones críticas (`reservar_clase`, `cancelar_reserva`) son atómicas en la BD
- Sin reintentos automáticos en v1: Flutter intenta UNA vez y muestra el error
- Si falla, el usuario ve el mensaje y puede reintentar manualmente

**Logging:**
- Los errores controlados (`try/catch`) se imprimen en modo debug
- Los errores no controlados van a Sentry (con sampling 5% en producción)
- No hay auditoría de intentos fallidos (posible mejora futura)

Suficiente para v1. Las operaciones son atómicas, los errores son claros, y Sentry vigila lo
no controlado. Los reintentos automáticos pueden venir en paso 11 si detectamos fallos sistemáticos.

## 2026-08-08 — Cobertura de pruebas (v1 pre-lanzamiento)

Las pruebas pgTAP cubren el flujo completo de operaciones:

**Pruebas de funcionalidad:**
- `e2e_fake_user_journey` — registro → clase → reserva → cancelación → promoción lista espera
- `tarifas_por_clases` — cálculo de saldo, bloqueo sin clases
- `waitlist_policies` — aforo, lista de espera, cancelación tardía, promoción FIFO
- `clases_recurrentes` — generación futuras, zona horaria, DST
- `cuota_efectivo` — pago en mano, estados de suscripción
- `reconciliacion_pagos` — webhook Stripe, activación de cuotas

**Pruebas de seguridad:**
- `production_hardening` — se bloquea sin cuota, aforo se respeta, solo RPC para cancelación
- `rls_multitenant` — aislamiento de academia, dueño no ve otra academia, alumno no salta academias
- `function_permissions` — anon solo lista, authenticated limitado a 6 RPC, service_role completo
- `admin_bootstrap` — admin se crea fuera del registro, no se puede escalar desde cliente

**Pruebas de configuración:**
- `staff_management` — cambio de rol, restricciones
- `familias_tutores` — congeladas (tabla no aplicada aún)

**Ejecución:**
- CI: `supabase test db` ejecuta todas las suites en paralelo
- Local: `supabase test db --verbose` con DB local levantada
- Flutter: `flutter test test/` ejecuta tests de UI y lógica (excluye golden)
- CI Flutter: formato, análisis, codegen, unit tests, golden tests (separado)

Suficiente para v1. CI está automatizado y verde.

## 2026-08-08 — Despliegue controlado de v1 (pre-lanzamiento)

Checklist de despliegue:

**Pre-despliegue (local + staging):**
- [ ] CI verde: formato, análisis, tests Flutter y pgTAP
- [ ] Supabase local: `supabase start && supabase test db` pasan
- [ ] `dart format`, `flutter analyze` sin avisos
- [ ] Codegen actualizado: `dart run build_runner build --delete-conflicting-outputs`
- [ ] All screenshots/golden tests updated (if any visual changes)

**Despliegue de BD (Supabase):**
- [ ] `supabase migration list` muestra exactamente 26 versiones
- [ ] `supabase db push --dry-run` solo detecta nuevas (si las hay)
- [ ] Ejecutar Advisors en Supabase Console, revisar SECURITY DEFINER
- [ ] **NO** desplegar si alguna migración histórica aparece como pendiente

**Despliegue de frontend (Vercel):**
- [ ] Merge a rama `main` (o rama de producción si existe)
- [ ] Vercel construye sin errores, estado = `READY`
- [ ] Ejecutar `Production smoke` manual (GET /, /olvide-contrasena, /privacidad)
- [ ] Verificar dominio: `https://itc2-reservas.vercel.app`

**Post-despliegue (dentro de 1 hora):**
- [ ] Revisar logs de Vercel y Supabase por errores nuevos
- [ ] Si Sentry activo, confirmar release = commit hash
- [ ] Ejecutar bootstrap de Administrador (proceso único):
  - Crear usuario en Auth sin metadata
  - Confirmar correo
  - Copiar UUID
  - SQL: `select public.bootstrap_initial_admin('<uuid>'::uuid, 'Nombre', null);`
  - Verificar: `select * from public.profiles where rol = 'administrador';`
  - Iniciar sesión, comprobar panel de academias

**Monitoreo (primeros 7 días):**
- [ ] Diariamente: revisar errores Sentry, disponibilidad en smoke
- [ ] Semanalmente: comparar con MAAT en paralelo (sin meter dinero real)

**Documentación post-lanzamiento:**
- [ ] Actualizar fecha y versión en `PRODUCT.md`
- [ ] Documentar qué usuario es el Administrador
- [ ] Archivar este fichero en la wiki o GitHub Releases

Referencia completa: `OPERATIONS.md` secciones "Despliegue", "Observabilidad" e "Incidentes".

## 2026-08-08 — Plan post-lanzamiento v1: Paso 11 (retomar congeladas)

Después del lanzamiento y ~2 semanas de operación en paralelo con MAAT:

**Paso 11a — Familias y tutores (menores sin Auth propia):**
- Descomentar tabla `relaciones_familia` en migración 20260803*
- Redesign: `relaciones_familia` → nueva tabla `dependientes` (menor SIN Auth, padre SÍ)
- RPC `crear_dependiente(nombre, email_opcional, fecha_nacimiento)`
- RPC `listar_dependientes()` para ver hijos
- Descomentar pantalla `MisHijosScreen` y rutas en router
- Descomentar botón "Añadir hijo" en Perfil
- Pruebas pgTAP: dependientes no se pueden autocursar, padre ve sus hijos, admin ve todos

**Paso 11b — Stripe y pagos (webhook + flujo completo):**
- Descomentar `Stripe.publishableKey` en main.dart
- Descomentar ruta `/cobros` (ConectarStripeScreen)
- Desplegar Edge Function `activar-suscripcion-webhook` en Supabase
- Probar webhook con Stripe test mode: pago → activación de suscripción
- Implementar flujo de cancelación y reembolsos
- Descomentar botón "Conectar Stripe" en Perfil de Dueño
- Pruebas: pago simulado activa cuota, webhook válido activa, firma inválida rechaza

**Paso 11c — Tienda (inventario y compras):**
- Descomentar ruta `/tienda` en router
- Implementar stock atómico: descuento en transacción única al pagar
- Conectar pagos de productos con Stripe o cobro en mano
- Crear comprobante de compra (PDF o email)
- Integración con lista de espera si aplica (ej: notificación cuando hay stock)
- Pruebas: stock no se vuelve negativo, carrito persiste, comprobante se envía

**Paso 11d — Multi-academia (reactivar selector en registro):**
- Descomentar ruta `/registroAcademia` (RegistroAcademiaScreen)
- Descomentar botón "Crear academia" en RegistroScreen
- Descomentar ruta `/admin/academias` (AdminAcademiasScreen)
- Descomentar selector de academia en RegistroScreen (quitar AppConfig.itacaAcademiaId)
- Implementar flujo de aprobación de academias (Administrador)
- Pruebas: dueño crea academia, aparece como 'pendiente_aprobacion', admin aprueba

**Paso 11e — Cambios de escuela (transfer between academies):**
- Descomentar ruta `/solicitudes-cambio-escuela` si existe
- Implementar pantalla de solicitud + flujo de aprobación por dueño
- Solo aplica si multi-academia

**Paso 11f — Gestión de miembros (suspender, archivar):**
- Agregar columnas de estado: `suspendido`, `inactivo` a profiles
- Implementar RPC `cambiar_estado_miembro(perfil_id, nuevo_estado)` con auditoría
- Descomentar acciones en pantalla de Equipo
- Pruebas: suspendido no puede reservar, inactivo no aparece en listas

Criterio de lanzamiento de cada step: CI verde + pruebas integrales pasadas + sin regresiones en paralelo con MAAT.

Todos estos steps están ya documentados en `FREEZE.md` (secciones 1-6).

## 2026-08-10 — Fallo de seguridad en el despliegue a producción: `crear_perfil_hijo` abierta a cualquiera

Al aplicar la migración `familias_tutores` a producción (Supabase MCP), el
Security Advisor detectó que `crear_perfil_hijo` — función `SECURITY
DEFINER` que crea un perfil de hijo y lo cuelga de un `parent_id` — era
ejecutable por `anon` sin haber iniciado sesión. La función no comprueba
quién la llama (la comprobación de identidad se delega a la Edge Function
que la invoca con `service_role`), así que cualquiera podía crear perfiles
de "hijo" colgando de cualquier padre existente llamando directamente a
`/rest/v1/rpc/crear_perfil_hijo`.

**Causa:** la migración `20260723143656_harden_function_permissions.sql`
deja las funciones nuevas cerradas por defecto con `alter default
privileges ... revoke execute on functions from public, anon,
authenticated`. Pero `alter default privileges` solo protege a las
funciones creadas **por el mismo rol** que ejecutó ese `alter`. Las
migraciones aplicadas vía CLI/`supabase test db` (incluida la suite pgTAP
de CI) corren siempre bajo el mismo rol, así que ahí la protección por
defecto sí alcanzaba a `crear_perfil_hijo` y las pruebas pasaban en verde.
Pero aplicar una migración a producción vía la herramienta MCP de Supabase
puede correr bajo un rol distinto, que no hereda ese `alter default
privileges` — de ahí que el aviso solo apareciera en producción, no en CI.

**Arreglo:** migración `20260810101142_cerrar_execute_crear_perfil_hijo`
revoca `EXECUTE` de `public`, `anon` y `authenticated` explícitamente.
Confirmado con el Security Advisor de producción: el aviso desaparece.

**Regla de aquí en adelante:** ninguna migración que cree una función
`SECURITY DEFINER` puede confiar en el cierre por defecto. Cada una debe
llevar su propio `revoke`/`grant` explícito, igual que ya se hacía en
`reservar_clase`. Añadidas dos pruebas pgTAP en `familias_tutores_test.sql`
que comprueban que `anon` y `authenticated` no pueden ejecutar
`crear_perfil_hijo` directamente.

**Nota de higiene de migraciones:** aplicar vía MCP también genera un
timestamp de versión distinto al del nombre del archivo local si no se fija
explícitamente. Los archivos de `bloquear_reserva_sin_clases`,
`familias_tutores`, `reservar_sin_cuota` y `tarifas_por_clases` se
renombraron para que el nombre de archivo coincida exactamente con la
versión aplicada en producción y evitar que este desajuste se repita.

**Migración huérfana reconciliada (2026-08-10):** `20260729165614_cuota_en_efectivo`
estaba aplicada en producción sin archivo local. Se consultó
`supabase_migrations.schema_migrations` directamente: es un duplicado exacto,
letra por letra, de `20260729160000_cuota_en_efectivo` — probablemente
reaplicada sin querer 56 minutos después. No cambia el esquema (todo el SQL
es idempotente: `create or replace function`, `drop constraint if exists`).
Se reconstruyó el archivo local con el contenido exacto de producción. Las
33 migraciones del repositorio y las 33 de producción coinciden ahora
versión por versión — verificado por comparación directa, no de memoria.

## 2026-08-10 — CanvasKit servido desde el propio dominio, no desde Google

La web se quedaba cargando (girando) para siempre en redes con DNS filtrado,
incluso en incógnito (descarta caché de navegador). El servidor respondía
bien (200, HTML correcto, sin errores de runtime) — el fallo estaba en el
navegador, no en Vercel.

**Causa:** la app usa el motor gráfico CanvasKit para dibujar. El script de
arranque que genera Flutter por defecto (`flutter_bootstrap.js`) lo descarga
de `www.gstatic.com` (Google) salvo que se le diga lo contrario — el mismo
problema que ya se resolvió para las tipografías (§6 de `CLAUDE.md`), pero
sin resolver para CanvasKit. Como `AppSupabase.initialize()` corre antes de
`runApp()` en `main.dart`, si ese arranque nunca termina de descargar
CanvasKit, la app no llega ni a pintar el primer fotograma: gira para
siempre sin ningún error visible para el usuario.

**Arreglo:** `web/flutter_bootstrap.js` (plantilla que Flutter respeta al
compilar) fija `canvasKitBaseUrl: "canvaskit/"`, sirviendo CanvasKit desde
el propio dominio — Flutter ya empaquetaba esos archivos en
`build/web/canvaskit/`, solo faltaba decirle al loader que los usara.

**Verificado en rojo/verde:** con un navegador controlado (Playwright) que
bloquea toda petición a `gstatic.com`, el script antiguo pide
`canvaskit.wasm`/`canvaskit.js` a `www.gstatic.com` (falla, tal como le pasa
a Cipri). Con el arreglo, esas peticiones desaparecen por completo.

**Pendiente, menor:** el propio motor CanvasKit todavía pide
`fonts.gstatic.com/.../Roboto...woff2` como *fallback* quieto (no bloqueante)
cuando falta una tipografía para algún carácter. No causa el giro infinito
(es asíncrono y falla rápido, no cuelga), pero en una red con Google
bloqueado esos caracteres concretos podrían no dibujarse. Queda para otra
sesión: localizar qué texto dispara ese fallback y asegurarse de que está
cubierto por Inter Tight o JetBrains Mono.

## 2026-08-13 — Revisión de seguridad de las 27 funciones `SECURITY DEFINER`, de cara al piloto

Repaso completo de RLS/GRANT/`SECURITY DEFINER` en `public` antes de meter a
alumnos reales. Resultado: **un solo fallo concreto**, no una lista larga de
huecos — la política de la migración de julio (arriba) ya se venía
cumpliendo en la práctica.

**El fallo:** `academia_id_de(p_profile_id uuid)` devolvía la academia de
CUALQUIER perfil sin comprobar nada. Cualquier alumno autenticado podía
llamar a `/rest/v1/rpc/academia_id_de` con el id de cualquier otro perfil —
de cualquier academia, sin relación alguna — y averiguar a qué academia
pertenece. No permitía leer datos personales ni cambiar nada, pero sí
mapear la pertenencia de perfiles ajenos a academias, cosa que no le
incumbe a nadie salvo el propio interesado, su familia o su academia.

Se usa dentro de la política RLS `relaciones_familia_select`
(`arreglar_recursion_rls_familias.sql`), así que revocarle el `EXECUTE` a
`authenticated` sin más rompía esa política para todo el mundo: Postgres
comprueba el permiso de ejecutar una función en quien hace la consulta, no
en quien es su dueño, aunque la función sea `SECURITY DEFINER`. La
corrección (`20260813133000_endurecer_academia_id_de.sql`) no toca los
permisos: limita lo que la función devuelve a los tres casos que la
política realmente necesita — la propia academia, la de un hijo a su
cargo, o la de alguien que ya comparte su misma academia — y `null` para
cualquier otro perfil.

**El resto de las 27 no necesita revocarse ni moverse de esquema.** Cada
una de las RPC expuestas a `authenticated` (`reservar_clase`,
`cancelar_reserva`, `cambiar_rol_miembro`, `aprobar_academia`,
`rechazar_academia`, `resolver_cambio_escuela`, `activar_cuota_efectivo`,
`desactivar_cuota_efectivo`, `clases_restantes`, etc.) valida identidad,
rol y pertenencia a la academia dentro de su propio cuerpo — es el patrón
que ya exige la decisión de julio. El Security Advisor de Supabase marca
igualmente cada una como aviso (`WARN`): así de estricto es el linter con
cualquier `SECURITY DEFINER` alcanzable desde fuera, sepa o no validar por
dentro. Se documentan como excepciones explícitas, no se ignoran ni se
revocan en bloque. El detalle función por función va en el PR de esta
revisión, no aquí.

`listar_academias_aprobadas()` es la única accesible también para `anon`
— a propósito: hace falta antes de iniciar sesión, para el desplegable de
academias del registro.

**Se añadió una prueba pgTAP que faltaba:** `resolver_cambio_escuela` no
tenía ninguna prueba negativa que comprobara que un alumno no puede
resolver una solicitud de cambio de escuela ajena (sí las tenían
`cambiar_rol_miembro`, `aprobar_academia` y `rechazar_academia`). La RPC ya
validaba esto correctamente; ahora queda comprobado.

## 2026-08-13 — Cabeceras de seguridad en Vercel y límite al bucket de avatares

`vercel.json` no fijaba ninguna cabecera de seguridad: sin CSP, sin
`X-Frame-Options`, sin HSTS. Añadidas en el bloque `headers` de
`vercel.json` (aplican a todas las rutas, incluida `index.html`).

**CSP** compatible con lo que la app realmente carga: `script-src 'self'
'wasm-unsafe-eval'` (CanvasKit compila WebAssembly; no hace falta
`unsafe-eval` — no hay `eval()` en `main.dart.js` ni en los loaders),
`worker-src 'self' blob:` (Flutter/CanvasKit arrancan un Worker desde
blob:), `connect-src` limitado al propio proyecto Supabase
(`dpcdpcvjcutcqyqcacti.supabase.co`, `wss://` incluido para Realtime) más
los dominios de ingesta de Sentry (por si `SENTRY_DSN` se activa más
adelante — ver `OPERATIONS.md`, pendiente #5), `frame-ancestors 'none'` y
`X-Frame-Options: DENY` (redundantes a propósito: la cabecera cubre
navegadores que no leen CSP nivel 2). No se añaden dominios de Stripe: la
inicialización de `Stripe.publishableKey` está comentada en `main.dart`
(`// CONGELADO: Stripe`) desde el cierre de accesos congelados, así que
`js.stripe.com` no se carga hoy.

**Verificado de verdad, no solo leído:** build de producción real
(`flutter build web --release`) servido en local con un servidor que
replica exactamente estas cabeceras, cargado con Chromium vía Playwright.
Resultado: la app arranca, CanvasKit pinta el primer fotograma (pantalla
"Falta configuración de Supabase", la esperada sin secretos de build) y no
hay ninguna petición bloqueada por la CSP salvo la ya conocida y aceptada
de `fonts.gstatic.com` (arriba) — que es exactamente el comportamiento que
ya se quería (no depender de Google), solo que ahora queda explícito en
vez de fallar en silencio.

**Bucket `avatars` sin tope.** Tenía lectura pública y escritura para
cada usuario en su propia carpeta, pero sin `file_size_limit` ni
`allowed_mime_types`: nada impedía subir un archivo enorme o de un tipo
que no fuera imagen a través de la API de Storage directamente (sin pasar
por el cliente Flutter, que si usa `image_picker` con calidad 85). Migración
`20260813130136_limitar_avatares.sql`: 5 MiB, solo
`image/jpeg`/`image/png`/`image/webp`. Verificado en rojo/verde con
pgTAP: quitando la migración, los dos tests nuevos fallan exactamente con
`NULL` donde se esperaba el límite; restaurada, 167/167 en verde.

Ninguna de las dos cosas (cabeceras, migración) se ha aplicado a
producción: cabeceras en `vercel.json` solo surten efecto en el próximo
despliegue, y la migración de Storage queda pendiente de autorización como
el resto de migraciones de este trabajo.

## 2026-08-18 — Editar, cerrar y cancelar una clase ya publicada

Primera fase de mejoras tras el piloto (Cipri, a partir de comparar con
MAAT). Punto 1: el dueño no tenía forma de tocar una clase una vez creada.

**Tres estados, no un booleano.** `clases.estado` es `activa` (por
defecto) / `cerrada` / `cancelada`, decidido así con Cipri:

- **Cerrada** — deja de admitir reservas nuevas, pero la clase sigue en
  pie: quien ya tenía plaza la mantiene. Reversible, se puede reabrir.
- **Cancelada** — terminal. Libera a todos los apuntados (inscritos y
  lista de espera, pasan a `cancelado`) y les avisa por notificación push,
  el mismo mecanismo de `notificaciones_outbox` que ya usa la promoción de
  lista de espera. No se puede reabrir ni volver a cancelar.

**Editar la hora avisa si hay gente apuntada** (decisión de Cipri): la RPC
`editar_clase` compara la hora nueva con la antigua y, si cambia, encola
una notificación para cada inscrito/en espera. Cambiar solo el título, la
descripción o el aforo no notifica a nadie.

**El aforo no se puede bajar de las plazas ya confirmadas** — evita que
editar deje a alguien con reserva confirmada fuera de una clase que ya
tiene menos sitio del que ocupa.

**Cierre de un permiso que se había colado:** `clases` tenía UPDATE de
tabla completa para `authenticated`, acotado solo por la RLS `clases_update`
(que restringe la FILA — cualquier dueño/profesor de su academia — pero no
la COLUMNA). Sin cerrarlo, un dueño podría poner `estado = 'cancelada'`
con un UPDATE directo desde el cliente, saltándose el aviso a los alumnos
y la liberación de sus plazas. Mismo patrón que ya se aplicó a
`profiles`/`academias` en julio: `revoke update` de tabla completa +
`grant update` solo de las columnas editables a mano
(`titulo`, `descripcion`, `fecha_hora_inicio`, `fecha_hora_fin`,
`aforo_maximo`). `estado`/`cancelada_at` solo cambian a través de las RPC.

Probado en rojo/verde: quitando el `revoke`/`grant` de columnas, el test
del UPDATE directo deja de lanzar excepción y descuadra las siguientes
tres pruebas de la suite — confirma que la prueba mira donde debe.
203 pruebas pgTAP en verde con el arreglo puesto.

## 2026-08-18 — «Confirmar todos» también desde la vista de día

Primera fase de mejoras tras el piloto, punto 2. El botón ya existía
dentro de `ClaseDetalleScreen`; Cipri lo quiere también en la tarjeta de
cada clase de la vista de día («Hoy»), sin tener que entrar en cada una.

**Se manda a todos los inscritos, no solo a los pendientes.** Calcular
«quién falta por validar» exigiría traer la lista de asistencias además
de la de inscritos — dos consultas por confirmación en vez de una. Como
`marcarAsistenciaEnBloque` ya hace un `upsert` con `ignoreDuplicates`, dar
de alta a alguien ya validado no hace nada: es más simple mandarlos todos
y dejar que el propio `upsert` descarte los que sobran, en vez de calcular
la diferencia en el cliente.

**`listar_clases_semana()` sí necesita saber cuántos faltan**, para que la
tarjeta decida si mostrar el botón y con qué número, sin una consulta
aparte por tarjeta — construido sobre la misma RPC que el punto 1 (este PR
depende de aquel: mismo cambio de columna en la misma función, no una
arista falsa).

Verificado en rojo/verde: forzando `pendientes_confirmar` a `0` fijo en la
migración, el test que espera `1` falla exactamente como se espera.
Restaurado, 205 pruebas pgTAP en verde.
## 2026-08-19 — Primera versión de Miembros

Cipri mandó capturas de MAAT y pidió una pantalla de Miembros para el
panel del Dueño/Profesor: buscar por nombre, filtrar por cinturón, ver de
un vistazo quién tiene la cuota al día. MAAT tiene bastante más: cuatro
categorías de cuota (pagando/prueba/impagado/sin membresía), cinturones
de niños, "listo para graduarse", filtro de inactividad. Preguntado si
prefería todo eso de una vez o empezar sencillo, eligió **empezar
sencillo**: esta versión es solo nombre, cinturón (solo adultos, que es
lo único que hay en la base de datos) y cuota al día/sin cuota. El resto
queda para otra tanda, cuando se decida qué datos nuevos hacen falta en
la base de datos (`suscripciones` no tiene hoy estados de prueba ni
pausada, y no existe ninguna noción de "listo para graduarse" ni de
última asistencia — investigado antes de escribir una sola línea).

**Sin migración.** Reutiliza `profiles` y `suscripciones` tal como están;
el criterio de "cuota al día" es el mismo que ya usa
`ClasesRepository._alumnosConCuotaAlDia` (activa, cobrada y dentro de
fechas) — si aquí se relajara, Miembros diría "al día" de alguien a quien
el servidor considera moroso.

**No sustituye a `EquipoScreen`.** Equipo (alcanzable desde Academia) es
para gestionar: cambiar de rol, cobrar en efectivo, retirar una cuota.
Miembros es para *ver y encontrar* — un directorio, no un panel de
acciones. La única acción que tiene es tocar a alguien sin cuota para
cobrarle en el momento (`mostrarDarCuota`, la misma hoja que ya usan
Equipo y la ficha de una clase), reutilizada tal cual.

**Entra en la barra inferior de Gestor**, en el hueco que ya estaba
reservado (`main_shell.dart` lo decía explícitamente desde julio):
Hoy, Herramientas, **Miembros**, Novedades, Academia, más el cambio de
modo — seis sitios en total para dueño/profesor. Verificado que cabe sin
desbordar en 412 px con una captura de pantalla (no solo mirando el
código): todas las etiquetas se leen, nada se solapa.

Dos pruebas que fallaron por esto, arregladas correctamente (no
enmascaradas): `test/shared/navegacion_test.dart` tenía el índice de
"Academia" en la barra escrito a mano (era 3, pasa a 4 porque Miembros
entra antes). No es una prueba rota por el cambio — es una prueba que
hacía justo lo que tenía que hacer: avisar de que el orden cambió.

Verificado: `flutter analyze` limpio, suite completa
(`--exclude-tags=golden`) en 88/88, sin deriva de codegen. Rojo/verde de
verdad: rompiendo el filtro de cinturón (`if (false)` en vez de comparar
con el cinturón elegido), la prueba que espera que el filtro funcione
falla; restaurado, verde.

## 2026-08-20 — Cinturones de niños (sistema IBJJF) en Miembros

Cipri preguntó qué faltaba para las cuatro cosas de Miembros que se
quedaron fuera de la primera versión (prueba/pausada, cinturones de
niños, listo para graduarse, inactividad). Primera de las cuatro:
cinturones de niños — la más independiente de las otras tres, sin
decisiones de negocio pendientes una vez confirmado el sistema (IBJJF,
igual que la academia sigue ya).

**Trece colores nuevos** en `profiles.cinturon`
(`20260820202054_cinturones_ninos.sql`): blanco (compartido con el de
adulto, mismo color de salida), gris-blanca, gris, gris-negra,
amarilla-blanca, amarilla, amarilla-negra, naranja-blanca, naranja,
naranja-negra, verde-blanca, verde, verde-negra. Solo amplía un `CHECK`
de columna — no toca RLS ni permisos, así que no hace falta el patrón de
`revoke`/`grant` de tabla, pero sí una prueba pgTAP de regresión: que los
trece se acepten y que un color inventado se siga rechazando
(`cinturones_ninos_test.sql`, plan de 15).

**Los cinturones mixtos (`<base>_<franja>`) se resuelven sin tabla
nueva.** `gris_blanco` no es una entrada más en `AppColors.beltColors`:
`AppColors.belt()` corta por el `_` y usa el color base (`gris`); un
`AppColors.franjaCinturon()` nuevo resuelve el segundo color reutilizando
las mismas entradas de `blanco`/`negro` que ya existían. `PuntoCinturon`
pinta una franja inferior cuando el cinturón es mixto (`ColoredBox`
partido con `Expanded` dentro de un `Container` recortado en círculo), en
vez del punto sólido de siempre — así lo describe la skill
`diseno-i-plus`: "color base + franja inferior".

El filtro de cinturón de Miembros pasa de una fila de pestañas a un botón
que abre una hoja con dos secciones, **Adultos** y **Niños** — como en
MAAT—, cada cinturón con su punto de color y su nombre en español. No hay
una entrada "Blanco (Niños)" aparte: es el mismo color que el blanco de
adulto, así que filtrar por "Blanco" ya trae a los dos.

Verificado en rojo/verde en los dos lados:
- SQL: quitando dos colores de la lista del `CHECK`, el bloque que los
  inserta a los trece falla exactamente donde se esperaba; restaurado,
  198/198 en verde.
- Flutter: rompiendo `esCinturonMixto` para que devuelva siempre `false`,
  la prueba que comprueba el color base y la franja de un mixto falla;
  restaurado, verde. Suite completa (`--exclude-tags=golden`) en 90/90.

Quedan pendientes, cada una con sus propias decisiones de Cipri ya
tomadas mientras tanto (ver la conversación del 20/08): prueba (1 día),
pausada (indefinida o con fecha), y listo para graduarse (solo cambio de
color, no grados; cuenta desde la fecha de alta salvo que se actualice a
mano; total acumulado de entrenos, no mínimo semanal estricto; niños a 6
meses por cinturón, adultos a 2 años). Ninguna se ha empezado todavía.

## 2026-08-21 — Ficha de alumno: progreso hacia el siguiente cinturón

Cipri, tras probar el filtro de cinturón de Miembros: "los puedo filtrar
por el cinturon pero no puedo entrar en cada perfil y ver cuanto han
entrenando, proxima graducacion etc". Sobre las capturas de MAAT que
había mandado antes (ficha con pestañas Resumen/Actividad/Promociones),
confirmó por `AskUserQuestion` que de momento solo hace falta
**Promociones** (el anillo de progreso y el botón de promover): el resto
—teléfono, país, documentos, notas, gráficas de actividad— son datos que
la base de datos no guarda hoy y quedan para otra tanda.

**Nueva columna `profiles.fecha_inicio_cinturon`**
(`20260821071211_promociones_cinturon.sql`), no nula, con `default now()`.
Para quien ya estaba de alta, un `update` de una sola vez la pone a su
`created_at` (backfill). Para cualquier alumno nuevo a partir de esta
migración, el propio default ya es su fecha de alta — no hace falta tocar
el trigger de registro. El futuro importador de MAAT deberá pasar la
fecha de alta real de cada alumno al insertar, en vez de dejar el
default (lo prueba `promociones_cinturon_test.sql`, insertando una fila
con `fecha_inicio_cinturon` explícita y comprobando que se respeta).

**RPC `promover_cinturon(alumno_id, nuevo_cinturon)`**, mismo patrón que
`cambiar_rol_miembro`: `security definer`, exige Profesor/Dueño activo de
la misma academia que el alumno, y el `CHECK` de `cinturon` ya rechaza
cualquier color inventado. Cambia el cinturón **y** reinicia
`fecha_inicio_cinturon` a `now()` — el contador de entrenos empieza de
cero en el cinturón nuevo.

**Regla de "cuánto falta", confirmada por Cipri el 20/08 (ver la entrada
de cinturones de niños) y ahora implementada en
`lib/features/miembros/domain/progreso_cinturon.dart`:** el ritmo exigido
es 3 entrenos/semana; niños (con relación en `relaciones_familia`) 6
meses por cinturón — igual para cada uno de los doce pasos IBJJF—;
adultos 2 años por cinturón, igual para las cuatro transiciones
(blanco→azul→morado→marrón→negro). Cuenta el total acumulado de
asistencias desde `fecha_inicio_cinturon`, no un mínimo semanal estricto.
"Es menor" se resuelve consultando `relaciones_familia` (por `child_id`),
no `profiles.parent_id` — esa columna no existe en la base de datos; el
campo del mismo nombre en el modelo `Profile` de Flutter nunca se ha
rellenado porque no hay tal columna que seleccionar.

**La ficha se abre tocando a un alumno con la cuota al día** en la lista
de Miembros (antes esa fila no hacía nada). A quien no tiene cuota le
sigue pasando lo de siempre: tocar abre el cobro en efectivo, no la
ficha — son dos usos distintos del mismo hueco y no se pisan.

El botón "Promover a un nuevo cinturón" **no está condicionado a que el
anillo llegue al 100 %**: el profesor decide, el progreso es solo
informativo (los grados intermedios de blanco los sigue llevando Cipri a
mano). En el cinturón más alto que gestiona la app (negro en adultos,
verde-negra en niños) no hay ni anillo ni botón — promover más allá de
ahí es una decisión fuera de alcance que no estaba pedida.

Verificado en rojo/verde en los dos lados:
- SQL: quitando la comprobación de rol de `promover_cinturon` (`v_actor_rol
  not in (...)` → `false`), la prueba que espera que un Alumno no pueda
  promoverse deja de fallar como debía; restaurado, 206/206 en verde.
- Flutter: la fracción de progreso, el CHECK de siguiente cinturón y el
  diálogo de confirmación tienen sus propias pruebas unitarias y de
  widget (`progreso_cinturon_test.dart`, `ficha_miembro_screen_test.dart`).
  Suite completa (`--exclude-tags=golden`) en 103/103.

Nota de arquitectura para quien toque `progresoCinturonProvider`: la
clave del `family` lleva `fechaInicioCinturon` (el valor real, nulo o no)
en vez de un `DateTime.now()` ya resuelto — así la clave es estable y
comparable, y una prueba puede sobreescribir exactamente la misma
instancia del provider que construye la pantalla. Meter `DateTime.now()`
en la clave (el primer intento) hacía que ninguna prueba pudiera
adivinar la instancia exacta a sobreescribir y la pantalla se quedaba
cargando para siempre.

## 2026-08-21 — Se mantiene Stripe para cobros; queda pendiente añadir SEPA

Cipri preguntó qué opciones había para el cobro de cuotas y pidió
investigar todas antes de decidir. Comparadas Stripe (+ SEPA Direct
Debit), GoCardless, Redsys, PayPal/Square/SumUp: la recomendación fue
quedarse en Stripe —ya tiene Connect, webhooks y `suscripciones`
implementados— y **añadir domiciliación bancaria SEPA como método de
pago dentro del mismo Stripe**, en vez de solo tarjeta. En España el
77,5% de los pagos recurrentes son por domiciliación, no tarjeta, y es
lo que usan los gimnasios (probablemente también MAAT); además tiene
menos comisión y muchos menos cobros fallidos que la tarjeta. GoCardless
tiene comisión algo menor pero exigiría rehacer la integración entera
por un ahorro de decenas de euros al mes a este volumen — no compensa.

Cipri respondió **"de momento stripe"**: se queda con Stripe. No se ha
pedido todavía añadir SEPA como método de pago — sigue siendo trabajo
pendiente, sin empezar, y sigue en pie que no se conecta a Stripe real
hasta que haya semanas en paralelo con MAAT.

## 2026-08-18 — Los alumnos ven quién más está apuntado a una clase

Cipri lo pedía tal cual lo tienen en MAAT: "los alumnos me dicen que
quieren ver quien estan apuntados en las clases". Preguntado qué datos
enseñar, eligió **nombre, foto y cinturón** — no la opción mínima
(nombre y foto) que se le proponía.

**Sin migración ni cambio de permisos.** Las políticas RLS que ya existen
(`inscripciones_select`, `profiles_select`) dejan leer a cualquier
miembro de la academia — no solo al dueño o al profesor — las filas de
`inscripciones` y `profiles` de su propia academia. Un alumno ya podía
consultar esto por API; solo faltaba la pantalla. No hace falta pgTAP
nuevo porque no se toca ningún permiso: la prueba que existe (`test/
features/calendario/companeros_clase_test.dart`) es de Flutter.

**`listarCompaneros` es una consulta nueva, no reutiliza
`listarParticipantes`.** Esa otra trae también si cada alumno tiene la
cuota al día (mirando `suscripciones`), y eso es un dato de pago que un
compañero no debe ver. La nueva solo pide `alumno_id` +
`profiles(nombre, apellidos, foto_url, cinturon)`, filtrada a
`estado = 'inscrito'` — la lista de espera no se enseña a los
compañeros, no aporta nada verla.

Se toca la tarjeta de clase en modo Entrenamiento: tocar la clase (no el
botón de reservar/cancelar, que sigue teniendo su propio toque) abre una
hoja inferior con la lista. Verificado en rojo/verde quitando el `onTap`
de `calendario_screen.dart`: las dos pruebas que esperan ver la lista
fallan correctamente por no encontrar el texto; restaurado, las tres
pruebas nuevas pasan y el resto de la suite (`flutter test test/app
test/core test/shared test/features --exclude-tags=golden`, igual que
CI) sigue en verde.

Los fallos de `test/golden_archived/` al correr `flutter test test/golden
--tags=golden` son previos a este cambio (confirmado con `git stash`
sobre el mismo comando) — esa carpeta ya está excluida a propósito del
paso de pruebas unitarias en CI, pero el paso de imágenes doradas la
recoge igualmente porque `test/golden` es prefijo de `test/golden_
archived`. No se toca en este PR: es un tema aparte de la infraestructura
de pruebas, no de esta funcionalidad.

## 2026-08-18 — La lista de compañeros se descontrolaba con muchos apuntados

Cipri probó la vista previa con una clase real de 40 alumnos: la hoja
inferior se veía "desproporcionada" e "imposible" de usar.

Causa real, medida con una prueba de Flutter (no a ojo): la lista de
`companeros_clase_sheet.dart` usaba `shrinkWrap: true` sin ningún límite
de alto, dentro de un `Flexible` que le dejaba crecer todo lo que hiciera
falta. Con 40 filas, la lista llegaba a ocupar 764 de los 900 px de
pantalla de prueba — casi toda la hoja, dejando apenas título y hueco
para cerrar.

Arreglo: la lista va ahora dentro de un `ConstrainedBox` con
`maxHeight: MediaQuery.of(context).size.height * 0.5`. Con pocos
apuntados la hoja sigue compacta (el límite no se nota); con muchos, la
lista se para en la mitad de la pantalla y se desplaza ella sola, en vez
de tragarse la hoja entera.

**Verificado en rojo/verde de verdad:** añadida una prueba que mide con
`tester.getSize()` el alto real de la lista con 40 apuntados y espera que
no pase de 450 px (la mitad de los 900 de la prueba). Contra el código
sin arreglar dio 764 px —prueba en rojo, con el número real que veía
Cipri—; con el arreglo, verde.

## 2026-08-18 — La hoja de compañeros pasa a `DraggableScrollableSheet`

El arreglo anterior (`ConstrainedBox` a la mitad de la pantalla) seguía
sin convencer: Cipri lo probó otra vez y lo describió como "inestable,
brusco y nada fino", y "sigue siendo grande". El problema no era ya que
reventara —eso ya estaba arreglado—, sino cómo se abría: con
`shrinkWrap` calculando el alto exacto del contenido, la hoja saltaba de
golpe a su tamaño final en la propia animación de apertura, y ese tamaño
era siempre medio móvil aunque hicieran falta menos apuntados.

Se sustituye por `DraggableScrollableSheet`: abre a un tamaño inicial
más modesto (40 % de la pantalla) con una animación continua, sin el
salto de recalcular el alto intrínseco a mitad de apertura, y se puede
estirar arrastrando hasta el 85 % si hace falta ver más gente sin soltar
el dedo — el gesto nativo que ya se espera de una hoja así, en vez de un
tamaño fijo impuesto. Con pocos apuntados sigue sin ocupar de más: el
80/85 % es un tope, no un tamaño por defecto.

El fondo de la hoja pasa a pintarlo el propio `Container` (con las
esquinas redondeadas solo arriba) en vez de Material, con
`backgroundColor: Colors.transparent` en `showModalBottomSheet`: sin eso
asomaban las esquinas cuadradas de Material por detrás de las
redondeadas de la hoja.

Verificado igual que el arreglo anterior: la prueba que mide el alto de
la lista con 40 apuntados se mantiene (`Key('lista_companeros')`, tope de
450 px sobre una pantalla de prueba de 900). Rompiendo el rango
(`initialChildSize`/`minChildSize`/`maxChildSize` casi al 100 %) la
prueba vuelve a fallar con 810 px; restaurado, verde. El resto de la
suite (`flutter test test/app test/core test/shared test/features
--exclude-tags=golden`, igual que CI) sigue en 88/88.

## 2026-08-18 — Los compañeros de clase van en pantalla propia, no en hoja

Cipri mandó dos capturas de MAAT: en el calendario del día hay un botón
"Confirmar todos" en la propia tarjeta (eso ya lo tenemos, punto 2), y los
apuntados a una clase se ven **al entrar en la clase**, en una pantalla
propia con lista de asistentes — no antes, desde el calendario. Su
mensaje textual: "no se ven desde la vista diaria, solo cuando abres la
clase". La hoja inferior (`DraggableScrollableSheet`, arreglo del punto
anterior) no encajaba con eso por diseño, no solo por sensación: abría
directamente desde la tarjeta del día, que es justo lo que pidió que no
pasara.

Se sustituye `companeros_clase_sheet.dart` por
`companeros_clase_screen.dart`: una pantalla `Scaffold` normal con
`AppBar`, mismo patrón que ya usa `ClaseDetalleScreen` para el dueño/
profesor. Tocar la tarjeta en modo Entrenamiento navega con
`Navigator.push` en vez de abrir una hoja. Efecto colateral bueno: al ser
una pantalla completa, la lista ya no necesita ningún límite de alto
artificial —el problema de fondo de las dos vueltas anteriores—; una
`ListView` normal en una pantalla llena se comporta como cualquier otra
lista larga de la app.

Se mantienen los mismos datos (nombre, foto, cinturón; nada de pago) y el
mismo repositorio (`listarCompaneros`), solo cambia la presentación.

Verificado: `flutter analyze` limpio, sin deriva de codegen, suite
completa en 88/88. Rojo/verde de verdad quitando el `onTap` que navega a
la pantalla nueva: 3 de las 4 pruebas del archivo fallan correctamente
(no encuentran el título de la pantalla nueva ni a los compañeros);
restaurado, verde.

## 2026-08-18 — Ranking por mes, año o desde siempre

Cipri pidió mejorar el Ranking mirando MAAT: poder filtrar por mes, año o
histórico. Con `AskUserQuestion` se le presentaron dos alcances —solo el
filtro, o además una pestaña de gráficas de actividad como en MAAT— y
eligió el primero: **solo el filtro**, sin gráficas nuevas.

**Se sustituye `ranking_mensual` por `ranking_periodo`, no se añade al
lado.** La RPC vieja solo admitía un mes concreto; la nueva recibe
`p_desde`/`p_hasta` (`date`, ambos opcionales) y filtra por rango abierto:
nulo por un lado significa sin límite por ese lado. Los tres casos que
pidió Cipri son el mismo código con fechas distintas calculadas en
Flutter:

- **Mes**: primer y último día del mes en curso.
- **Año**: 1 de enero a 31 de diciembre del año en curso.
- **Siempre**: `p_desde`/`p_hasta` los dos nulos.

Mantener las dos funciones habría dejado `ranking_mensual` como RPC
huérfana (nada la llama ya desde Flutter) — superficie de permisos sin
uso, justo lo que la revisión de seguridad de julio fue cerrando. Se
borra en la misma migración que crea la nueva
(`20260818073509_ranking_periodo.sql`), y `function_permissions_test.sql`
ahora comprueba explícitamente que `ranking_mensual` ya no existe.

**Sigue incluyendo a los alumnos con 0 asistencias en el rango** —
propiedad que ya tenía `ranking_mensual` y que hacía falta conservar: cada
alumno tiene que ver su posición real, aunque sea la última.

**Verificado en rojo/verde, dos veces:**
- pgTAP (`supabase/tests/ranking_periodo_test.sql`, plan de 7): rompiendo
  el filtro de fecha (`and true` en vez de comparar con `p_desde`/
  `p_hasta`), 3 de 7 pruebas fallan con el recuento sin filtrar; restaurado,
  192/192 en verde en toda la suite.
- Flutter (`test/features/estadisticas/ranking_periodo_test.dart`):
  rompiendo el cálculo del último día del mes (`ahora.month, 28` en vez de
  `ahora.month + 1, 0`), la prueba del rango por defecto falla comparando
  contra el 31; restaurado, verde.

La pestaña usa `PestanasPildora`, un componente del sistema de diseño que
ya existía en el repositorio sin ningún sitio que lo usara todavía.

El antetítulo de `TituloPantalla` se renderiza en mayúsculas
(`.toUpperCase()` interno, como ya pasaba con `PastillaEstado` — ver PR de
gestión de clases). Una prueba buscaba `'Histórico'` tal cual y fallaba
por eso, no por ningún fallo de lógica; se corrigió la prueba, no el
widget.
## 2026-08-18 — Deshacer una asistencia confirmada por error

Tras probar «confirmar todos» (punto 2 de esta tanda), Cipri pidió poder
deshacer una confirmación suelta: *"puede que le doy a confirmar a todos
y me doy cuenta que a uno no quiero confirmarlo, quiero tener la
opción"*.

**No había ninguna forma de hacerlo, ni con RLS perfecta.** `asistencias`
solo tenía `GRANT INSERT` para `authenticated` — sin `GRANT DELETE` de
tabla, ninguna política de fila habría servido de nada (la misma lección
de julio con las columnas de Stripe, aplicada aquí a nivel de tabla).
Migración `20260818193559_deshacer_asistencia.sql`: añade el `GRANT
DELETE` y una política `asistencias_delete` con el mismo alcance que ya
usa `asistencias_insert` (profesor/dueño de la propia academia) — a
propósito **sin** restringir a "quien la validó": si el dueño marcó por
error y el profesor lo ve después, tiene que poder deshacerlo igual.

En la pantalla de la clase, la marca verde de un alumno ya confirmado
pasa a ser tocable: deshace justo esa asistencia, sin afectar a las
demás ni pedir confirmación aparte (es una acción de un toque, tan fácil
de deshacer como de repetir — a diferencia de «confirmar todos», que sí
avisa antes por tocar a mucha gente de golpe).

Verificado en rojo/verde en los dos lados:
- pgTAP (`supabase/tests/deshacer_asistencia_test.sql`, plan de 4):
  rompiendo la condición de rol de la política (`and false` en vez de
  comprobar profesor/dueño), la prueba de que el Profesor puede deshacer
  una asistencia falla correctamente; restaurado, 187/187 en verde.
- Flutter (`test/features/calendario/deshacer_asistencia_test.dart`):
  quitando el `onPressed` del icono, la prueba que espera ver el cambio
  falla; restaurado, verde. Suite completa
  (`--exclude-tags=golden`) en 86/86.

**Aplicada a producción** junto con las migraciones de los puntos 1, 2 y
4 de esta tanda (edición/cierre/cancelación de clase, confirmar todos
desde el día, ranking por periodo) — con luz verde explícita de Cipri
tras pedir dos veces las mismas funciones y no verlas, porque las cuatro
vistas previas de Vercel comparten la misma base de datos real y las
migraciones nunca se aplican solas.

## 2026-08-27 — Prueba (1 día) y tarifa Pausada

Siguiente punto confirmado por Cipri tras la tanda de Stripe: dos estados
nuevos de `suscripciones`, con las reglas que había fijado antes.

- **Prueba**: el Dueño deja a un alumno probar **exactamente 1 día**, sin
  cobrarle todavía. Cuenta como cuota al reservar, igual que una activa
  (así el alumno vive la reserva real, no una simulación), y caduca ella
  sola a las 24 horas — nadie tiene que acordarse de cerrarla.
- **Pausada**: el Dueño congela una cuota que ya existía (baja temporal,
  lesión...). Mientras dure, **no** cuenta para reservar — es justo lo
  contrario de la prueba, y es lo que distingue "pausada" de "sigue
  cobrando pero no viene". Admite dos modos: indefinida (hasta que el
  Dueño la reanude a mano) o con fecha, y entonces se reanuda ella sola.

Migración `20260827120000_prueba_y_pausada.sql`:
- `suscripciones_estado_check` y el índice único
  `suscripciones_activa_unica_idx` amplían la lista de estados «en curso»
  con `prueba` y `pausada` — sigue habiendo como mucho una cuota viva por
  alumno, prueba y pausa incluidas.
- `activar_cuota_efectivo` gana un parámetro `p_prueba` en vez de crear
  una función aparte: es el mismo camino (Dueño, en efectivo, cierra la
  cuota anterior), solo cambia a qué estado y fecha de fin aterriza. Como
  `create or replace` con una lista de parámetros distinta crea una
  función *nueva* en Postgres en vez de sustituir la anterior, hubo que
  borrar antes la de 3 argumentos explícitamente — si no, se habrían
  quedado las dos conviviendo, una de ellas fantasma.
- `pausar_cuota_efectivo` / `reanudar_cuota_efectivo`, nuevas: mismo
  patrón de permisos que `desactivar_cuota_efectivo` (solo Dueño, solo
  cuotas en efectivo — las de Stripe se gestionan desde Stripe).
- `expirar_pruebas_y_pausas()`, job de `pg_cron` cada 15 minutos (mismo
  patrón que `expirar_pagos_pendientes`): expira las pruebas caducadas y
  reanuda solas las pausas con fecha ya cumplida.
- `reservar_clase` amplía su condición de cuota a `estado in ('activa',
  'prueba')` — a propósito **sin** incluir `'pausada'`.

**Error real cazado durante la propia verificación, no en producción:**
al escribir `reservar_clase` de nuevo dentro de esta migración partí de
una copia antigua de la función (la de `reservar_sin_cuota`, del 30 de
julio) en vez de la versión vigente. Eso habría borrado silenciosamente
dos comprobaciones añadidas después: que la clase no esté cerrada
(`20260818063921_gestionar_clase_publicada.sql`) y el tope de clases
incluidas en la tarifa (`20260818063921` también, vía
`clases_restantes`). Lo delató la propia suite de pgTAP —
`gestion_clase_test.sql` y `tarifas_por_clases_test.sql` empezaron a
fallar en cuanto apliqué la migración— y no un despliegue real, porque
toda migración de este proyecto se prueba en local antes de acercarse a
producción. Corregido partiendo de la versión buena antes de seguir.

Como los permisos de columna de `suscripciones` no cambian (sigue
concedido solo `estado` a `authenticated`, el resto vía las funciones
`security definer`), no hacía falta tocar ningún `revoke`/`grant` de
tabla.

**Verificado en rojo/verde:**
- pgTAP (`supabase/tests/prueba_pausada_test.sql`, plan de 23, más el
  ajuste de firma en `cuota_efectivo_test.sql`): quitando `'prueba'` de
  la condición de `reservar_clase`, la prueba "con la prueba en marcha sí
  se puede reservar" falla correctamente con "Debes tener una cuota
  activa..."; restaurada, 264/264 en verde en toda la suite (antes 241).
- Flutter (`test/features/equipo/cuota_equipo_test.dart`, seis pruebas
  nuevas): las cuatro pastillas de estado (Sin cuota / Prueba / Pausada /
  Al día-Efectivo) y qué acciones ofrece el menú según el estado —
  "Iniciar prueba" solo sin cuota, "Pausar"/"Reanudar" solo con cuota en
  efectivo y en el estado que toca. Suite completa
  (`--exclude-tags=golden`) en 127/127.

En el lado de Flutter: `EquipoRepository` gana `iniciarPrueba`,
`pausarCuota`, `reanudarCuota`; `cuotasActivas` amplía su filtro y ahora
devuelve también `estado`. Dos hojas nuevas en `features/equipo/
presentation`: `iniciar_prueba_sheet.dart` (elegir tarifa, sin selector
de duración — la prueba es siempre 1 día) y `pausar_cuota_sheet.dart`
(indefinida o con fecha, con `showDatePicker` para la segunda). Van en
Equipo y no en Miembros, seguido el reparto ya decidido: Miembros es
para ver, Equipo es para gestionar.

`TarifasRepository.suscripcionActiva`, `ClasesRepository.
_alumnosConCuotaAlDia` y `MiembrosRepository.alumnosConCuotaAlDia`
amplían su condición para incluir `'prueba'` junto a `'activa'` — tienen
que seguir mirando exactamente lo mismo que `reservar_clase` en el
servidor, o Miembros/la lista de la clase dirían «al día» de alguien a
quien el servidor no dejaría reservar (o al revés). La vista "Mi cuota"
del propio alumno (`tarifas_screen.dart`) distingue ahora sus cuatro
estados con las pastillas correspondientes, y esconde el botón "Cancelar
suscripción" en prueba/pausada (no hay nada que cancelar en Stripe: esas
cuotas las gestiona el Dueño desde Equipo).

**Sin aplicar todavía a producción.** Pendiente de la autorización de
Cipri para esta migración en concreto.
