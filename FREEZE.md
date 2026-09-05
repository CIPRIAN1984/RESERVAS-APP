# Funcionalidades Congeladas — v1 Pre-lanzamiento

**Fecha: 2026-08-08**  
**Estado: Congeladas hasta paso 11 (post-lanzamiento)**

Estas funcionalidades existen en el código pero están **desactivadas, ocultas o no desplegadas** intencionadamente. No se tocan hasta que se haya lanzado una versión estable de ITACA como academia única.

---

## 1. Familias y Tutores — DESCONGELADA (04/09/2026)

**Estado: funcionando. Base de datos y pantalla, las dos rehechas.**

No se descongeló la versión vieja: **se rehizo**. La de agosto estaba rota de
raíz (ver el histórico más abajo). Lo que hay ahora, del PR #57:

- Los menores son **perfiles normales sin cuenta** (`profiles.tiene_cuenta`
  a false). Se quitó la clave foránea `profiles.id -> auth.users.id` que
  hacía imposible crearlos, y el borrado en cascada que daba se recuperó con
  un disparador. **No** se creó la tabla `dependientes` que planteaba el plan
  original: al ser perfiles normales, las inscripciones, asistencias, cuotas,
  ranking, cinturones y graduación les funcionan sin tocar nada.
- `crear_hijo(nombre, apellidos, cinturon)` sustituye a `crear_perfil_hijo`,
  que se borró. Crea el perfil **dentro** de la función, así que no acepta el
  id de un perfil ajeno.
- `reservar_clase` y `cancelar_reserva` aceptan un segundo argumento
  opcional `p_alumno_id` para operar sobre un hijo, y solo si `es_padre_de`
  lo confirma.
- `profiles.entrena`: un padre que solo trae al niño no cuenta como alumno.
- 19 pruebas pgTAP en `supabase/tests/familias_v2_test.sql`.

**La pantalla, del 04/09/2026 (PR de «Mi familia»):**
- `MisHijosScreen` y `AgregarHijoSheet` **reescritas**, no descomentadas: las
  viejas llamaban a la Edge Function `crear-hijo`, que invocaba la difunta
  `crear_perfil_hijo`. `familia_repository.dart` va ahora contra la RPC
  `crear_hijo`.
- La Edge Function `crear-hijo` **borrada**, y con ella el modelo
  `RelacionFamilia`, que se quedó sin usar.
- La ruta `Routes.misHijos` vuelve al router, con el acceso «Mi familia» en
  Perfil — visible para todo el que pertenezca a una academia, tenga hijos o
  no: si solo se enseñara a quien ya los tiene, nadie podría dar de alta al
  primero.
- Interruptor «Yo también entreno» en Perfil, para el tutor que solo trae a
  sus hijos (columna `entrena`).
- Al padre **no se le pide el cinturón** del hijo: entra sin cinturón (que la
  app enseña como blanco) y gradúa el Dueño. Un padre no tiene por qué
  conocer la escala infantil de doce grados.

**Lo que todavía falta de familias:**
- **Reservar por un hijo desde el calendario.** La base de datos ya lo
  permite (`reservar_clase(p_clase_id, p_alumno_id)`), pero la pantalla aún
  no ofrece elegir para quién se reserva. Hace falta además que
  `listar_clases_semana` devuelva las reservas de los hijos: si no, el padre
  apunta a su hijo y la tarjeta de la clase sigue diciendo «Reservar plaza»,
  sin rastro de que el niño ya tiene plaza. **Es la siguiente tanda.**
- **Dar de baja a un hijo.** Cipri decidió que se borra todo (ver
  DECISIONS.md, 03/09/2026). Sin escribir todavía.

**Histórico, por si alguien se pregunta por qué se rehízo:** la primera
versión (10 de agosto) aplicó `relaciones_familia`, su RLS y
`crear_perfil_hijo()` en producción pese al congelamiento. Esa función
fallaba **siempre**: insertaba un perfil con un uuid nuevo contra una clave
foránea que exigía una fila en `auth.users`. Nunca creó un solo hijo.
Además, su política de inserción dejaba que cualquier persona con sesión se
declarase padre de cualquier otro perfil y le cambiara el nombre — agujero
cerrado el 03/09/2026 en el PR #56. Contexto completo en `DECISIONS.md`.

---

## 2. Stripe y Pagos

**Estado:** Código presente, no configurado, funciones no desplegadas.

**Por qué se congela:**
- Solo lleva "conectar Stripe" en perfil del Dueño.
- Flujo de pago NO implementado.
- Webhook de Stripe NO desplegado.
- Usar dinero real sin esto listo es riesgo de compliance y fraude.

**Qué está oculto:**
- Ruta `/pagos/conectar-stripe` en router (comentada o eliminada).
- Pantalla `ConectarStripeScreen` en `lib/features/pagos/presentation/conectar_stripe_screen.dart`.
- Botón en perfil de Dueño: "Conectar Stripe".
- Imports innecesarios en `main.dart`: `Stripe.publishableKey` y `applySettings()`.
- **2026-08-13:** el bloque "Cobros" en Academia (`context.go(Routes.cobros)`,
  ruta sin `GoRoute`) y el botón "Suscribirse" en Tarifas (abría de verdad la
  hoja de pago de Stripe si la academia tenía `stripeChargesEnabled`) se
  quitan. El alta de cuota sigue siendo solo en mano (`dar_cuota_sheet.dart`).

**Qué está activo:**
- Cobro en mano (`dar_cuota_sheet.dart`) — mantener.
- Modelo de cuota (`suscripciones` en BD) — mantener.
- Webhook handler en Supabase — desactivado hasta ser probado.

**Qué hacer para retomarlo:**
- Desplegar Edge Function `activar-suscripcion-webhook`.
- Crear tests para el flujo Stripe → webhook → activación de cuota.
- Implementar cancelación y reembolsos.
- Probar con datos de test de Stripe.
- Ver `OPERATIONS.md` para procedimiento de activación.

---

## 3. Tienda y Productos

**Estado:** Esquema en BD, pantalla UI incompleta.

**Por qué se congela:**
- Stock NO es atómico.
- Pagos de productos NO están conectados.
- No hay comprobante de compra.
- Falta integración con cuotas y suscripciones.

**Qué está oculto:**
- Ruta `/tienda` en navegación principal (si existe).
- Pantalla de carrito si está incompleta.
- Botón "Comprar" en productos.
- **2026-08-13:** la tarjeta "Tienda y material" en Perfil y en Herramientas
  saltaba directamente a `TiendaScreen()` con `Navigator.push`, sin pasar por
  el router — por eso el bloqueo de rutas no la alcanzaba. Se quitan ambas.

**Qué está activo:**
- Tablas `productos`, `pedidos`, `prestamos` en BD.
- Lectura de productos desde API (para futura implementación).

**Qué hacer para retomarlo:**
- Implementar stock con transacción única.
- Conectar con Stripe o cobro en mano.
- Crear comprobante de compra.
- Integrar con lista de espera si aplica.

---

## 4. Registro Público de Academias

**Estado:** Código en rutas, flujo de aprobación.

**Por qué se congela:**
- ITACA es app exclusiva (academia única).
- El selector de academia en el registro debe desaparecer.
- La aprobación de academias (rol admin) no aplica.

**Qué está oculto:**
- Pantalla de registro: opción "Nueva academia" (solo "Unirse a academia existente").
- Academia selector: siempre hardcodeada a ITACA.
- Ruta `/admin/academias` si existe.
- RPC `aprobar_academia`, `rechazar_academia` — no expuestas en Flutter.

**Qué está activo:**
- Tabla `academias` en BD con ITACA como row único.
- Perfil inicial cargado con ITACA.

**Qué hacer para retomarlo:**
- No hacer nada. Una vez que sea multiacademia de nuevo, el flujo vuelve.

**Pendiente de decisión (2026-08-13):** la pantalla `AdminAcademiasScreen`
("Academias", con botones Aprobar/Rechazar) sigue activa y es la primera
pestaña del Administrador de plataforma — no se ha tocado en este cierre.
No la puede ver ningún Alumno/Dueño/Profesor (solo quien tenga el rol
`administrador`, hoy solo Cipri), y hoy no muestra nunca nada pendiente
porque el único camino para crear una academia nueva (`RegistroAcademiaScreen`)
está congelado sin ningún acceso vivo. Se deja fuera de este PR porque
apagar del todo el modo Administrador es una decisión de producto, no un
descuido — está pendiente de que Cipri diga si quiere clausurarlo también
o dejarlo tal cual para el piloto.

---

## 5. Cambios de Escuela (Transfer)

**Estado:** Tabla `solicitudes_cambio_escuela` en BD, no implementado en UI.

**Por qué se congela:**
- Academia única: no aplica.
- Tablas pueden permanecer pero sin exposición en Flutter.

**Qué está oculto:**
- RPC `resolver_cambio_escuela` — no disponible en Flutter.
- Pantalla de cambio de escuela — no implementada.
- **2026-08-13:** en realidad sí estaba implementada e igual de accesible que
  las demás. Se quitan tres accesos vivos: el botón "Solicitar cambio de
  escuela" en Perfil (`Navigator.push` directo, todo Alumno lo veía), la fila
  "Cambios de escuela" en Academia (`context.go`, ruta sin `GoRoute`), y la
  pestaña "Cambios" de la barra inferior del Administrador (mismo problema:
  llevaba a una ruta que el router nunca resuelve).

**Qué está activo:**
- Tabla vacía en BD (innecesaria, pero puede quedarse).

**Qué hacer para retomarlo:**
- Si vuelve multiacademia, reimplementar flujo de solicitud.

---

## 6. Gestión de Miembros (Suspender, Archivar)

**Estado:** No implementado.

**Por qué se congela:**
- Está en lista "después" del plan, pero es crítico antes de lanzamiento.
- El Dueño necesita poder dar de baja (no solo convertir a alumno).
- Debe haber auditoría de cambios.

**Qué está oculto:**
- Acciones "Suspender", "Dar de baja", "Archivar" en pantalla de equipo.

**Qué hacer para retomarlo:**
- Implementar estados en `profiles`: `activo`, `suspendido`, `inactivo`.
- RPC `cambiar_estado_miembro` con auditoría.
- Pruebas de que las suspensiones bloquean reservas.

---

## Checklist de Congelamiento

- [x] Eliminar/comentar rutas de Familias en router.
- [x] Eliminar/comentar rutas de Stripe en router.
- [x] Ocultar botones de "Conectar Stripe", "Añadir hijo" en UI (completado
      del todo el 2026-08-13: el router ya bloqueaba las rutas con nombre,
      pero quedaban botones que saltaban directo con `Navigator.push`/
      `MaterialPageRoute`/`context.go` a rutas sin `GoRoute`, sin pasar por
      ese bloqueo — ver las entradas fechadas 2026-08-13 en cada sección).
- [x] Comentar Stripe.publishableKey en main.dart.
- [ ] Documentar en DECISIONS.md por qué se congelaron (si no está ya).
- [ ] Crear issue de GitHub para cada feature congelada (paso 11).
- [ ] Verificar que CI sigue en verde sin estas rutas.
- [x] Hacer commit: "Congelar Familias, Stripe, Tienda, Cambios de escuela".

---

## Referencias

- **Familias, rediseño ya hecho (base de datos):** ver DECISIONS.md,
  "2026-09-03 — Familias y tutores, segunda versión (base de datos)".
- **Stripe ready:** ver OPERATIONS.md sección "Stripe en Producción".
- **Migraciones de familias, ya aplicadas:** `20260903120000_cerrar_agujero_relaciones_familia.sql`
  y `20260903130000_familias_tutores_v2.sql`. La vieja
  `20260810100946_familias_tutores.sql` sigue en el historial (no se editan
  migraciones aplicadas), pero la función que creaba ya no existe.
