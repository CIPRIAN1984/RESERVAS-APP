# Funcionalidades Congeladas — v1 Pre-lanzamiento

**Fecha: 2026-08-08**  
**Estado: Congeladas hasta paso 11 (post-lanzamiento)**

Estas funcionalidades existen en el código pero están **desactivadas, ocultas o no desplegadas** intencionadamente. No se tocan hasta que se haya lanzado una versión estable de ITACA como academia única.

---

## 1. Familias y Tutores

**Estado:** Código implementado, tabla NO aplicada en Supabase.

**Por qué se congela:**
- Necesita rediseño: menores sin Auth propia genera huérfanos.
- Cambio arquitectónico: tabla `relaciones_familia` debe ser reemplazada.
- No es bloqueador para v1: todas las clases pueden registrarse con perfil de alumno único.

**Qué está oculto:**
- Pantalla `AgregarHijoSheet` en `lib/features/perfil/presentation/agregar_hijo_sheet.dart`.
- Método `familia_repository.dart` (crear, listar, actualizar hijos).
- Ruta `/familia/agregar-hijo` en router.

**Qué hacer para retomarlo:**
- Diseñar tabla `dependientes` en lugar de `relaciones_familia`.
- Padres tienen Auth; menores no.
- Nueva migración, nuevas pruebas pgTAP, nueva RPC.
- Ver `DECISIONS.md` para contexto completo.

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

---

## 5. Cambios de Escuela (Transfer)

**Estado:** Tabla `solicitudes_cambio_escuela` en BD, no implementado en UI.

**Por qué se congela:**
- Academia única: no aplica.
- Tablas pueden permanecer pero sin exposición en Flutter.

**Qué está oculto:**
- RPC `resolver_cambio_escuela` — no disponible en Flutter.
- Pantalla de cambio de escuela — no implementada.

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

- [ ] Eliminar/comentar rutas de Familias en router.
- [ ] Eliminar/comentar rutas de Stripe en router.
- [ ] Ocultar botones de "Conectar Stripe", "Añadir hijo" en UI.
- [ ] Comentar Stripe.publishableKey en main.dart.
- [ ] Documentar en DECISIONS.md por qué se congelaron (si no está ya).
- [ ] Crear issue de GitHub para cada feature congelada (paso 11).
- [ ] Verificar que CI sigue en verde sin estas rutas.
- [ ] Hacer commit: "Congelar Familias, Stripe, Tienda, Cambios de escuela".

---

## Referencias

- **Rediseño de Familias:** ver DECISIONS.md sección "2026-08-03 — Familias y tutores".
- **Stripe ready:** ver OPERATIONS.md sección "Stripe en Producción".
- **Migraciones congeladas:** `supabase/migrations/20260803...familias_tutores.sql` (no aplicar aún).
