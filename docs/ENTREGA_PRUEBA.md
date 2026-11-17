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

## Bloque 2 — Recorrido de la escuela

| Requisito | Estado | Evidencia |
|---|---|---|
| alta → aprobación → tarifa → pago en mano → reserva → asistencia → saldo | ⬜ | prueba de extremo a extremo en local, con sesión iniciada |
| Bono trimestral (periodos y precio) | ✅ en producción (#87) | `cobro_segun_tarifa_test.sql`; ⬜ repetir en el recorrido |
| Renovación anticipada | ✅ (#84) | `renovacion_y_pausa_test.sql`; ⬜ recorrido |
| Clase extra | ✅ (#88) | `clases_extra_test.sql`; ⬜ recorrido |
| Pausa | ✅ (#84) | ídem; ⬜ recorrido |
| Aforo con reservas simultáneas | ✅ | `reservar_clase` con candado; pgTAP |
| Cancelaciones (a tiempo / tardía / perdonar) | ✅ (#82) | pgTAP; ⬜ recorrido |
| Ausencias (no presentado consume) | ✅ (20/09) | pgTAP; ⬜ recorrido |
| Llegada sin reserva | ✅ (#92) | `apuntar_sin_reserva_test.sql`; ⬜ recorrido |
| Baja y reactivación | ✅ (06/09) | pgTAP; ⬜ revisar con el cierre de acceso del bloque 1 |
| Cobrar en recepción con la clase ya empezada | ⬜ | reproducir; arreglar si falla |
| Consultar una clase antigua tras caducar la cuota que la cubría | ⬜ | reproducir; arreglar si falla |
| «Sin cuota» / «Sin clases» son avisos, no deudas | ✅ (#89) | `reservas_sin_clases_test.sql` |
| Lista de espera apagada en el piloto (no hay avisos verificados) | ⬜ | apagada en los datos de prueba; en producción 🙋 |

## Bloque 3 — Stripe de prueba

Diseño elegido (se anota en `DECISIONS.md` al implementarlo): **pago único
por periodo con la página de pago de Stripe (Checkout)**, con las mismas
condiciones que el cobro en mano. La cuota la activa el servidor al recibir
la confirmación firmada de Stripe, nunca el navegador. Nada se convierte en
suscripción automática sin que Cipri lo acuerde.

| Requisito | Estado | Evidencia |
|---|---|---|
| Revisar lo existente y reutilizar | ⬜ | |
| Pago correcto activa la cuota del alumno correcto, una sola vez, aunque cierre la página | ⬜ | pago real en el entorno aislado de Stripe |
| Pago fallido, abandonado, pendiente | ⬜ | |
| Reintento y notificación duplicada | ⬜ | |
| Cancelación / devolución | ⬜ | |
| Mismas condiciones que en mano; no duplica derechos | ⬜ | pgTAP |
| Detectar un fallo de cobro sin que avise el alumno | ⬜ | aviso al Dueño en la app |
| Cobro recurrente | 🙋 no acordado | |

## Bloque 4 — Preparar la prueba

| Requisito | Estado |
|---|---|
| Calendario con clases futuras ficticias, tarifas, cuentas de dueño/profesor/alumno | ⬜ |
| Recorrido en navegador a tamaño móvil, con sesión iniciada | ⬜ |
| Guía breve para el móvil de Cipri | ⬜ |
| Correo: entrega, confirmación y recuperación | ⬜ (en local con buzón de pruebas); en la vista previa 🙋 |
| Navegación del registro y errores visibles | ⬜ |
| Permisos de tutor y documentos comprobados antes de incluir menores | ⬜ |
| Señalar qué texto de privacidad hay que revisar | ⬜ |

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

Bloque 2: recorrido completo con sesión iniciada contra el Supabase local
(datos ficticios en `supabase/seed_prueba.sql`), en navegador a tamaño móvil.
