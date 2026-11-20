# Entrega de prueba privada — lista única

Encargo de Cipri del 17/11/2026: terminar RESERVAS-APP y entregar una versión
de prueba **privada**, completa para el día a día de ITACA JIU JITSU, con
Stripe en modo prueba. Esta lista es la memoria del encargo: cada sesión
empieza aquí. Se actualiza al cerrar cada bloque.

**Leyenda:** ✅ hecho y verificado (con dónde está la prueba) · 🔧 en curso ·
⬜ pendiente · 🙋 depende de Cipri.

## Reglas del encargo (no se negocian)

- Solo `CIPRIAN1984/RESERVAS-APP`, Vercel `itc2-reservas` y Supabase
  `itc2-reservas`. Nada de otros proyectos.
- Producción no se toca sin autorización expresa: ni borrar, ni importar de
  MAAT, ni permisos, ni ajustes, ni fusionar, ni desplegar.
- Se prueba en local o en una vista previa con base aislada y datos ficticios.
- Recursos nuevos o con coste: pedir permiso antes.
- Sin tarjetas reales, sin claves reales de Stripe, sin credenciales por chat.
- Una sola academia. Sin módulos nuevos ni rediseños. Lo que queda fuera se
  desactiva también en el servidor.
- «Lista para probar» = enlace privado + acceso seguro + el recorrido
  aprobar → pagar con tarjeta de prueba → cuota correcta → reservar →
  asistencia → exactamente una clase consumida, verificado con sesión
  iniciada y con pago real de Stripe de prueba (no simulado en la base).
- La entrega de prueba **no autoriza el lanzamiento**.

## Dónde se prueba

- **Local:** Supabase completo en Docker (`npx supabase start`), con las
  migraciones del repositorio y datos ficticios (`supabase/seed_prueba.sql`).
  Sin coste. Aislado de producción.
- **Vista previa privada (para el móvil de Cipri):** 🙋 necesita una base
  aislada alojada. Ver «Depende de Cipri».

## Bloque 1 — Acceso y privacidad — ✅ hecho en local (17/11/2026)

Migración `20261117090000_acceso_y_privacidad.sql`. **No aplicada en
producción** (necesita autorización).

| Requisito | Estado | Evidencia |
|---|---|---|
| La cuenta nueva nace pendiente; el enlace de registro no da acceso | ✅ | `acceso_y_privacidad_test.sql` 1–13 |
| El Dueño aprueba o rechaza desde Miembros | ✅ | pgTAP 47–49 · `altas_pendientes_test.dart` |
| Pendiente o de baja: sin acceso a datos de otros | ✅ | pgTAP 2–19 |
| Alumno ve lo suyo; tutor, lo de sus hijos | ✅ | pgTAP 20–35 |
| Compañeros y ranking por funciones acotadas | ✅ | pgTAP 26–28 |
| Profesor: sin importes, sin tarifas, sin certificados | ✅ | pgTAP 36–46 · `ficha_miembro_screen_test.dart` · `herramientas_screen_test.dart` |
| Un alumno no crea un pedido pagado o entregado | ✅ | pgTAP 53 |
| Tienda oculta y cerrada en el servidor | ✅ | pgTAP 51–52 · `accesos_perfil_test.dart` |
| Sin sesión no se lee ninguna tabla | ✅ | pgTAP 55 |
| Registro: enlace a «Iniciar sesión», mínimo 8 en pantalla y servidor local, enlace a privacidad | ✅ código · ⬜ captura en el recorrido |

Totales en local: 47 suites de base de datos (todas en verde salvo dos
comprobaciones del bucket de documentos que ya fallaban antes en este
entorno por la versión de la herramienta, no por estos cambios) y 281
pruebas de la app.

## Bloque 2 — Recorrido de la escuela — ✅ hecho en local (18/11/2026)

Migraciones `20261117100000_recepcion_y_clases_antiguas.sql` y
`20261117110000_lista_espera_apagada.sql`. **No aplicadas en producción.**

**Recorrido con sesión iniciada, en navegador a 412 px, contra el Supabase
local (`scripts/e2e_local/`)** — ✅ verificado de extremo a extremo con pago
en mano:

1. Registro de una alumna por el enlace → pantalla «Revisa tu correo» → el
   correo llega al buzón de pruebas → enlace de confirmación → entra y ve «Tu
   alta está pendiente de aprobación» (perfil `pendiente_aprobacion`).
2. La dueña abre Miembros → «1 alta pendiente de aprobar» → «Aprobar a Nuria»
   → la alumna pasa a `activo`.
3. La dueña le cobra «Bono 10 sesiones» en mano → en la base: 80 €, 10
   clases, trimestral, del 18/11 al 18/02/2027.
4. La alumna reserva una clase → «INSCRITO».
5. El profesor, en modo Gestor, «Confirmar 1 alumno» → «Confirmar todos».
6. Saldo: **1 gastada, 0 reservadas, 9 disponibles de 10** (exactamente una).

| Requisito | Estado | Evidencia |
|---|---|---|
| alta → aprobación → tarifa → pago en mano → reserva → asistencia → saldo | ✅ | recorrido de arriba |
| Bono trimestral (periodos y precio) | ✅ | recorrido + `cobro_segun_tarifa_test.sql`, `saldo_por_ciclo_test.sql` |
| Renovación anticipada | ✅ | `renovacion_y_pausa_test.sql` |
| Clase extra | ✅ | `clases_extra_test.sql` |
| Pausa y reanudar | ✅ | `renovacion_y_pausa_test.sql`, `prueba_pausada_test.sql` |
| Aforo y reservas simultáneas | ✅ | `production_hardening_test.sql`, `ciclo_consumo_clases_test.sql` |
| Cancelaciones (a tiempo, tardía, perdonar) | ✅ | `ciclo_consumo_clases_test.sql`, `descuento_excepciones_test.sql` |
| Ausencias (no presentado consume) | ✅ | `ciclo_consumo_clases_test.sql` |
| Llegada sin reserva | ✅ | `apuntar_sin_reserva_test.sql` |
| Baja y reactivación | ✅ | `baja_alumno_test.sql` (con el acceso cerrado del bloque 1) |
| **Cobrar en recepción con la clase ya empezada** | ✅ **era un fallo real, arreglado** | `recepcion_y_clases_antiguas_test.sql` 1–10; en rojo sin el arreglo |
| **Consultar una clase antigua tras caducar la cuota** | ✅ **era un fallo real, arreglado** | ídem 11–15; en rojo sin el arreglo |
| «Sin cuota» / «Sin clases» son avisos, no deudas | ✅ | `reservas_sin_clases_test.sql` |
| Lista de espera apagada en el piloto | ✅ en la base de prueba y bloqueada en app y servidor | `lista_espera_apagada_test.sql` · `lista_espera_bloqueada_test.dart` · 🙋 en producción está **encendida** hoy |

Fallo de pantalla encontrado de paso y arreglado: el desplegable de zona
horaria de Ajustes de reservas se salía 149 px de la tarjeta en un móvil.

Totales en local, sobre base limpia: **49 suites, 695 comprobaciones de base
de datos en verde** y las pruebas de la app en verde.

## Bloque 3 — Stripe de prueba — ✅ hecho en local con Stripe simulado · 🙋 falta Stripe real

Migraciones `20261117120000_pagos_stripe_parte1.sql` y `…121000_…parte2.sql`;
funciones `stripe-checkout-tarifa`, `stripe-comprobar-pago`, `stripe-webhook`.
**No aplicadas ni desplegadas en producción.** Diseño en `DECISIONS.md`
(2026-11-17): pago único con Checkout, activado solo por el aviso firmado.

**Qué significa «verificado» aquí:** en local no hay Stripe real. Se usó
`stripe-mock` (valida la forma de las llamadas a la API) y avisos firmados con
el secreto de pruebas, que el webhook comprueba igual que los de Stripe. Esto
**no equivale** a un pago con la página real de Stripe.

| Requisito | Estado | Evidencia |
|---|---|---|
| Revisar lo existente y reutilizar | ✅ | Se reutilizó Connect/`stripe_charges_enabled`; las suscripciones recurrentes y la tienda se retiran (410) |
| Pago correcto activa la cuota de la alumna correcta, una vez, aunque cierre la página | ✅ simulado | `pagos_stripe_test.sql` (41) · `stripe_local.cjs` (25) · navegador `t10`: botón → pago 50 € → aviso firmado 200 → cuota «2 días por semana / activa / stripe» → «Pago recibido» |
| Pago fallido, abandonado (caducado), pendiente | ✅ simulado | pgTAP + `stripe_local.cjs` |
| Reintento y aviso duplicado | ✅ | clave determinista; pgTAP y `stripe_local.cjs` |
| Importe o moneda que no cuadran | ✅ | pasa a `revisar`, no activa nada |
| Devolución | ✅ simulado | `registrar_devolucion_stripe` |
| Mismas condiciones que en mano; sin derechos duplicados | ✅ | misma función `_alta_cuota` |
| Detectar un fallo de cobro sin que avise la alumna | ✅ | «Pagos con problema» en Academia → Cobros (test de pantalla) |
| Navegación al volver de Stripe | ✅ **era un fallo real, arreglado** | `destino_tras_cargar_test.dart` (en rojo sin el arreglo) + navegador |
| Cobro recurrente | 🙋 no acordado → no existe | |
| **Pago con la página real de Stripe y avisos reales** | 🙋 **bloqueado** | necesita clave `sk_test_…` y un punto de entrada público para el webhook |

## Bloque 4 — Preparar la prueba

| Requisito | Estado | Evidencia |
|---|---|---|
| Datos ficticios: clases futuras, tarifas, dueño/profesor/alumnos/tutora con menor | ✅ local | `scripts/sembrar_prueba.py` (se niega a correr contra producción) |
| Recorrido en navegador a 412 px con sesión iniciada | ✅ local | `scripts/e2e_local/t1…t10` |
| Guía breve para el móvil | ✅ | `docs/GUIA_PRUEBA_MOVIL.md` |
| Correo: confirmación y recuperación | ✅ recuperación en español (buzón de pruebas) · ⚠️ la confirmación llegaba en inglés: plantilla en español añadida (`supabase/templates/confirmation.html`), **sin verificar en vivo** hasta reiniciar la pila local · 🙋 correo real en la vista previa | |
| Navegación del registro y errores visibles | ✅ | `t1_registro.cjs`; mínimo 8 en pantalla y servidor |
| Permisos de tutor y documentos | ✅ | `documentos_alumno_test.sql` (tutor ve solo a su hijo; alumno no sube por otro; otra academia no escribe), `familias_v2_test.sql`, pgTAP 36–46 (profesor sin certificados) |
| Texto de privacidad que hay que revisar | ⚠️ **señalado** | La pantalla «Privacidad y datos» (27/07/2026) **no menciona** certificados médicos (dato de salud), descargo firmado ni menores/tutores. Que lo revise alguien de protección de datos **antes de incluir menores**. No se ha reescrito. |
| Enlace privado para el móvil | 🙋 bloqueado | ver abajo |

## Depende de Cipri (agrupado)

1. 🙋 **Base aislada alojada para el enlace privado.** Opciones: una rama de
   Supabase del proyecto `itc2-reservas` (tiene coste por horas) o hacerlo
   todo en local y enseñarlo con capturas. Sin esto no hay enlace para el
   móvil.
2. 🙋 **Clave del entorno aislado de Stripe**, por formulario seguro (no por
   chat).
3. 🙋 **¿Cobro recurrente con tarjeta?** Por defecto: no; cada pago es de un
   periodo.
4. 🙋 **Tienda:** queda fuera y cerrada salvo que diga lo contrario.
5. 🙋 Ajustes de producción que solo puede hacer él: confirmación de correo,
   contraseñas filtradas, mínimo de contraseña, segundo factor del
   administrador, repositorio privado.
6. 🙋 Limpieza de producción: inventario pendiente de presentar. No autorizada.
7. 🙋 Texto de privacidad (responsable, menores, certificados médicos): que lo
   revise alguien de protección de datos.

## Próxima acción

Todo lo que se puede probar sin tus claves está hecho y probado. Para dar el
paso a «lista para probar» (enlace privado + pago con la página real de Stripe)
hacen falta los puntos 1 y 2 de arriba. Hasta entonces **no se puede decir
«lista para probar»**.
