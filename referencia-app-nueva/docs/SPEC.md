# Plan de app de gestión de gimnasio tipo Maat (PWA)

Nov 13, 2026 · @Edu

## Resumen

La app se construye como PWA (web instalable) con React + TypeScript en el cliente y Supabase (Postgres) como backend, alojada gratis en Cloudflare Pages. Es la única vía que funciona en Android e iOS sin cuenta de desarrollador, y todo el entorno corre en local con Docker.

Decisiones que propongo:

- **Distribución:** PWA. Sin tiendas, sin cuotas, una sola base de código.
- **Stack:** React 19 + Vite + TypeScript + Tailwind en cliente; Supabase (Postgres, Auth, RLS, Edge Functions) en servidor.
- **Coste:** 0 €/mes en el arranque; ITACA+ añade el alojamiento de vídeo, del orden de 5 a 15 $/mes. El primer gasto razonable sería Supabase Pro (25 $/mes) si se quiere copia de seguridad diaria.
- **Alcance:** primero reservas, asistencia y cinturones. Stripe e ITACA+, la plataforma de vídeo por suscripción, forman la Fase 3.
- **Supuesto de partida:** una app para un solo gimnasio (el tuyo), con el esquema preparado para varias sedes. Si la idea es venderla a otros gimnasios, cambia bastante; está en preguntas abiertas.

Valoración crítica, sin adornos:

1. **Clonar Maat entero no es buena idea.** Más de la mitad de su superficie es facturación: Stripe, reintentos de cobro, impuestos, facturas, 15 monedas, migraciones. Para un gimnasio propio eso es lo más caro de construir, lo más arriesgado y lo que menos valor añade. Lo que se usa a diario es reservar, pasar lista y ver el progreso.
2. **No emitas facturas desde tu app.** Con Verifactu, el software que factura en España debe cumplir requisitos técnicos propios. La app debe registrar cobros y exportarlos; la factura sale de un programa ya adaptado.
3. **La PWA tiene un coste real en iPhone.** La instalación es manual desde Safari y las notificaciones solo funcionan una vez instalada. Es asumible para alumnos de un gimnasio a los que puedes enseñárselo en persona; sería un problema serio para captar usuarios desconocidos.
4. **El plan gratuito de Supabase no es producción con garantías.** No incluye copias diarias y pausa el proyecto tras una semana sin actividad. Con uso diario no se pausa, pero la copia semanal hay que montársela uno.
5. **El mantenimiento es tuyo para siempre.** Maat cuesta 49–59 $/mes más un 1 % por transacción. Si tu objetivo fuera solo ahorrar esa cuota, no compensa. Compensa si quieres las mejoras de la sección siguiente o control total de los datos.

## Qué ofrece Maat hoy

Maat es un software de gestión para gimnasios de BJJ, MMA y deportes de combate, con app en las tiendas, un único plan de 49 $/mes (anual) o 59 $/mes y un 1 % por transacción. Esta tabla resume su [página de funciones](https://maatapp.com/features) y en qué fase lo cubre este plan.

| Módulo | Lo que hace Maat | En este plan |
| --- | --- | --- |
| Horario y reservas | Reserva en un toque, aforo, lista de espera con promoción automática, clases recurrentes, festivos, política de no presentados, sincronización de calendario, roles | Fase 1 |
| Asistencia y cinturones | Conteo por semana, mes y año, requisitos de clases por cinturón, aviso de "listo para graduar", historial de promociones, ranking, rachas, resumen anual | Fase 1 (ranking y rachas en Fase 2) |
| Altas y consentimientos | Pruebas gratuitas, exención de responsabilidad con firma digital en PDF, contacto de emergencia, perfil obligatorio antes de reservar, perfiles de niños bajo cuenta del tutor | Fase 1 (perfiles) y Fase 2 (firma) |
| Planes y membresías | Ilimitado, N clases por semana, bonos de créditos, clase suelta, congelaciones, cambios de plan con prorrateo, reglas por disciplina, venta de extras | Fase 2 (planes) y Fase 3 (prorrateo, extras) |
| Mensajería | Confirmaciones, recordatorios, avisos de lista de espera y de pago, anuncios, push, email, WhatsApp y SMS | Fase 2 (push y email) |
| Analítica | Ingresos, bajas, popularidad por franja, carga por instructor, segmentación de alumnos | Fase 2 |
| Cobros | Tarjeta, Apple Pay, Google Pay, domiciliación SEPA, suscripciones recurrentes, reembolsos, portal del alumno, todo sobre Stripe | Fase 2 (registro manual) y Fase 3 (Stripe) |
| Recuperación de impagos | Reintentos automáticos, avisos previos, bloqueo de reservas con deuda, panel de morosos | Fase 2 (bloqueo y panel) |
| Cupones y referidos | Descuentos fijos o porcentuales, promociones temporales | Fase 3 |
| Facturas e impuestos | Facturas con marca, IVA por país, resúmenes fiscales, exportación CSV | Solo exportación CSV |
| Multi-sede, idiomas, monedas | Varias sedes, 6 idiomas, 15 monedas, zonas horarias | Esquema multi-sede; ES y EN; solo EUR |
| Migración | Importación CSV y plantillas desde otros programas | Solo importación CSV de alumnos |

## Qué mejoraría respecto a Maat

Las mejoras con más valor están en lo que Maat no cubre para un gimnasio español y en la parte técnica del tatami, no en igualar su facturación. Lo que sigue no aparece en su página de funciones.

| Mejora | Qué es | Fase |
| --- | --- | --- |
| Cobros a la española | Registrar Bizum, efectivo y transferencia en dos toques, con estado de cuota visible para el alumno. Maat solo lista domiciliación SEPA para Alemania | 2 |
| Remesas SEPA propias | La app genera el fichero de adeudos (pain.008) para subirlo al banco, sin pasarela ni comisión por operación | 3 |
| Pasar lista sin cobertura | El profesor marca asistencia sin conexión y se sincroniza al volver la red | 1 |
| Check-in por QR | Un QR en la puerta o en una tablet en modo kiosco; el alumno entra con la cámara | 1 |
| Criterios de graduación más finos | Además de número de clases: tiempo mínimo en el cinturón, visto bueno del profesor y sistema infantil separado | 1 |
| Diario técnico | El profesor apunta qué se dio en cada clase; el alumno ve las técnicas que ha visto y las que se perdió, con enlace a vídeo | 3 |
| Plan de clases | Programación semanal o por bloques, visible antes de reservar | 3 |
| Competición | Calendario de torneos, inscritos del equipo, resultados y palmarés en el perfil | 3 |
| Licencias y seguro | Fecha de caducidad de licencia federativa y seguro por alumno, con aviso antes de vencer | 2 |
| Familias | Un tutor con varios hijos, reserva en bloque y descuento familiar | 2 |
| Clases particulares y open mat | Reserva de huecos con un profesor concreto y sesiones libres sin instructor | 3 |
| Retención por cohortes | Qué porcentaje de los que se apuntaron cada mes sigue a los 3, 6 y 12 meses, y lista de alumnos cuya frecuencia está cayendo | 2 |
| Datos sin ataduras | Exportación completa en CSV y copia de la base de datos en tu poder | 1 |

Donde Maat seguirá siendo mejor: app nativa en las tiendas, notificaciones más fiables en iPhone, cobros con tarjeta ya resueltos y soporte. Conviene tenerlo presente al decidir cuánto invertir en la Fase 3.

## Alcance por fases

Tres fases, cada una utilizable por sí sola en el gimnasio antes de empezar la siguiente. La Fase 1 ya sustituye a la hoja de asistencia y al grupo de WhatsApp para reservar.

**Fase 0 — Cimientos**

- Repositorio, entorno local con Supabase en Docker, despliegue en Cloudflare Pages.
- PWA instalable vacía con inicio de sesión, probada en un Android y un iPhone reales.
- Sistema de diseño: colores, tipografía y componentes base.

**Fase 1 — Tatami (producto mínimo)**

- Roles: propietario, administrador, profesor, recepción, alumno.
- Perfiles de adulto y de menor bajo la cuenta de un tutor; contacto de emergencia.
- Horario con clases recurrentes y puntuales, festivos y cierres.
- Reservas con aforo, lista de espera con promoción automática y plazo de cancelación.
- Asistencia: lista del profesor (funciona sin conexión) y check-in por QR.
- Cinturones y grados: historial, reglas de graduación, filtro "listo para graduar".
- Importación de alumnos por CSV y exportación completa.

**Fase 2 — Gestión**

- Planes (ilimitado, N por semana, bono de créditos, clase suelta, prueba) y congelaciones.
- Registro manual de cobros, estado de cuota, bloqueo de reservas con deuda, panel de impagos.
- Notificaciones push y email: confirmaciones, recordatorios, lista de espera, anuncios.
- Consentimientos con firma digital y PDF guardado.
- Licencias y seguro con avisos de caducidad; familias y descuento familiar.
- Ranking, rachas e hitos; panel de analítica con retención por cohortes.
- Enlace de calendario (ICS) para Google, Apple y Outlook.

**Fase 3 — Ampliaciones**

- Stripe e ITACA+: suscripción de vídeo como extra a la cuota. Después, si se decide, las cuotas del gimnasio por Stripe o por remesa SEPA.
- Tienda de extras, cupones y seminarios.
- Diario técnico, plan de clases, competición, clases particulares y open mat.

**Fuera de alcance:** emisión de facturas, varias monedas, SMS y API de WhatsApp de pago, plantillas de migración desde otros programas, interfaz para gestionar varias sedes.

## Distribución sin cuenta de desarrollador

Una PWA es la única opción que llega a Android e iOS sin pagar ni registrarse en ninguna tienda: el alumno abre una dirección web y la añade a su pantalla de inicio. Se abre a pantalla completa, con icono propio, y funciona sin conexión para lo que se haya cacheado.

|  | Android (Chrome) | iPhone y iPad (Safari) |
| --- | --- | --- |
| Instalación | Aviso automático "Instalar app" | Manual: Compartir → Añadir a pantalla de inicio |
| Notificaciones push | Sí | Sí desde iOS 16.4, solo con la app ya instalada |
| Sin conexión | Sí | Sí, con menos almacenamiento disponible |
| Tareas en segundo plano | Parcial | No |
| Cámara para QR | Sí | Sí |

Consecuencias para el diseño:

- **Pantalla de instalación guiada.** La app detecta la plataforma y enseña los pasos exactos; en iPhone, con capturas. Un QR en la recepción lleva a esa pantalla.
- **El permiso de notificaciones se pide tras un toque del usuario** y después de instalar, nunca al abrir.
- **Nada crítico depende solo del push.** Cada aviso importante tiene copia por email y aparece en una bandeja dentro de la app.
- **Prueba en iPhone real en la Fase 0.** Algunas guías de 2026 siguen diciendo que las PWA no funcionan como app en la UE; Apple anunció ese cambio en 2024 y lo retiró, pero se comprueba en un móvil antes de construir encima.

Alternativas descartadas:

| Opción | Por qué no |
| --- | --- |
| App nativa o React Native en las tiendas | Exige cuenta de Apple (99 $/año) y de Google Play (25 $ una vez) |
| APK instalado a mano en Android | Funciona sin cuenta, pero deja fuera a los iPhone y obliga a activar "orígenes desconocidos" |
| TestFlight o firma con Apple ID gratuito | TestFlight requiere cuenta de pago; la firma gratuita caduca a los 7 días |

Si algún día quieres estar en las tiendas, el mismo código se envuelve con Capacitor sin reescribir la app.

Fuentes: [MobiLoud](https://www.mobiloud.com/blog/progressive-web-apps-ios), [Monterail](https://monterail.com/blog/pwa-for-apple-ios), [MagicBell](https://www.magicbell.com/blog/pwa-ios-limitations-safari-support-complete-guide).

## Arquitectura

Un cliente estático que habla directamente con Postgres a través de Supabase, con las reglas de negocio y los permisos dentro de la base de datos. No hay servidor propio que mantener, y un cliente manipulado no puede saltarse un aforo ni ver los cobros de otro alumno.

| Capa | Elección | Motivo |
| --- | --- | --- |
| Interfaz | React 19 + Vite + TypeScript | El ecosistema más amplio y el que mejor genera un modelo de código |
| Estilos | Tailwind CSS + componentes propios sobre Radix | Accesibilidad resuelta, aspecto totalmente a medida |
| Rutas | React Router | App de una sola página; no hace falta renderizado en servidor |
| Datos en cliente | TanStack Query con caché persistida en IndexedDB | Lectura sin conexión y refresco automático |
| Validación | Zod, con tipos generados desde el esquema de la base | Un solo origen de verdad para los tipos |
| PWA | vite-plugin-pwa (Workbox) | Manifiesto, service worker y actualización de versiones |
| Idiomas | i18next, ES y EN | Textos fuera del código desde el primer día |
| Autenticación | Supabase Auth: enlace mágico por email y Google | Sin contraseñas que gestionar |
| Base de datos | Postgres con seguridad a nivel de fila (RLS) | Permisos por rol dentro de la base |
| Lógica crítica | Funciones SQL (RPC) transaccionales | Reservar plaza y promover lista de espera sin condiciones de carrera |
| Tareas programadas | pg\_cron | Generar sesiones, recordatorios, caducidades |
| Código de servidor | Edge Functions (Deno) | Envío de push (VAPID), email, webhooks de Stripe |
| Tiempo real | Supabase Realtime | Aforo en vivo en la pantalla de la clase |
| Archivos | Supabase Storage, cubos privados | PDF firmados, fotos de perfil |
| Alojamiento web | Cloudflare Pages | Gratis, HTTPS y dominio propio |
| Email | Proveedor transaccional con plan gratuito (Resend o similar) | Confirmaciones y copia de cada aviso |
| Pruebas | Vitest, pgTAP para RLS, Playwright | Los permisos se prueban, no se suponen |

Por qué no Next.js: no hay nada que renderizar en servidor ni que posicionar en buscadores. Una app estática es más simple, se cachea entera para uso sin conexión y se aloja gratis en cualquier sitio.

Principios que el código debe respetar:

1. **La base de datos manda.** Aforo, elegibilidad por plan y plazos de cancelación se comprueban en funciones SQL. El cliente solo pide.
2. **Todo lleva `gym_id`.** Una sola sede hoy, varias mañana sin migrar datos.
3. **Sin conexión, solo lo necesario.** Lectura cacheada de horario, reservas y perfil. Escritura en cola únicamente para pasar lista y check-in, con un identificador generado en el móvil para que reenviar no duplique.
4. **La clave de servicio nunca sale del servidor.** El cliente usa solo la clave pública y RLS.
5. **Migraciones SQL versionadas en el repositorio.** El entorno local y el de producción se crean con los mismos ficheros.
6. **Horas en UTC en la base, Europe/Madrid en pantalla.** Las clases recurrentes se definen en hora local para que el cambio de hora no las mueva.

Flujo de una reserva: el alumno toca "Reservar" → el cliente llama a `book_session` → la función bloquea la fila de la sesión, comprueba plan, deuda y aforo → devuelve plaza o puesto en lista de espera → Realtime actualiza el aforo en los demás móviles. Al cancelar, `cancel_booking` promueve al primero de la lista y una Edge Function le envía el aviso.

## Opciones de base de datos y backend

Supabase es la recomendación: es la única opción gratuita que trae juntos Postgres, autenticación, permisos por fila, tiempo real y entorno local idéntico al de producción. Los datos de un gimnasio son relacionales (alumno, plan, clase, reserva, cobro) y encajan mal en una base documental.

| Opción | Tipo | Punto fuerte | Pega principal | Encaje |
| --- | --- | --- | --- | --- |
| **Supabase** | Postgres gestionado + auth + storage + funciones | Todo integrado, RLS, se ejecuta entero en local, código abierto y migrable | El plan gratuito pausa tras 7 días sin actividad y no trae copias diarias | Recomendado |
| Cloudflare D1 + Workers | SQLite en el borde | Sin pausas, mismo proveedor que el alojamiento | Autenticación, permisos y tiempo real hay que construirlos | Plan B |
| PocketBase | Un binario con SQLite, auth y panel | Muy simple, datos en un solo fichero | Necesita un servidor encendido que mantienes tú | Si quieres alojarlo en casa |
| Firebase (Firestore) | Base documental de Google | Push y autenticación muy maduros, sin pausas | Datos relacionales forzados, consultas limitadas, difícil salir | No recomendado aquí |
| Neon | Solo Postgres sin servidor | Postgres puro con ramas | Faltan auth, storage y funciones | Solo como pieza suelta |

Límites del plan gratuito de Supabase, según guías contrastadas con su página de precios entre mayo y noviembre de 2026: 500 MB de base de datos, 1 GB de archivos, 5 GB de tráfico de salida, 50.000 usuarios activos al mes y 2 proyectos. Conviene confirmarlos en [supabase.com/pricing](https://supabase.com/pricing) antes de empezar.

Por qué esos límites sobran: 200 alumnos con 150 asistencias al año son unas 30.000 filas anuales, pocos megabytes. El único recurso que puede apretar es el almacenamiento si se guardan muchos PDF o fotos.

Cómo cubrir las dos pegas del plan gratuito:

- **Pausa por inactividad.** Con reservas diarias no ocurre. En agosto o en un cierre largo, una tarea programada que haga una consulta diaria lo evita.
- **Copias de seguridad.** Una GitHub Action semanal que ejecute `pg_dump` y guarde el fichero cifrado. Es gratis y te da la copia que el plan no incluye.
- **Cuándo pagar.** Cuando la app sea la única fuente de verdad de los cobros, los 25 $/mes del plan Pro compran copias diarias y eliminan la pausa.

Fuentes: [Supabase, pausa de proyectos](https://supabase.com/kb/faqs/platform/free-project-pausing), [IT Path Solutions](https://www.itpathsolutions.com/supabase-free-tier-limits), [MakerKit](https://makerkit.dev/blog/saas/supabase-pricing).

## Modelo de datos

Unas 25 tablas en Postgres, todas con `gym_id`, claves UUID y marcas de creación y modificación. La asistencia y los cobros son registros que nunca se borran: se anulan con un estado.

| Tabla | Contenido clave | Fase |
| --- | --- | --- |
| `gyms` | Nombre, zona horaria, ajustes (plazo de cancelación, política de no presentados) | 0 |
| `profiles` | Persona: nombre, fecha de nacimiento, foto, contacto de emergencia; `user_id` vacío si es un menor sin cuenta | 0 |
| `gym_members` | Perfil + sede + rol (owner, admin, coach, front\_desk, member) + estado | 0 |
| `guardianships` | Tutor → menor | 1 |
| `disciplines` | BJJ Gi, No-Gi, MMA, infantil… | 1 |
| `class_templates` | Clase recurrente: día de la semana, hora local, duración, profesor, aforo, disciplina, nivel | 1 |
| `class_sessions` | Cada clase concreta: inicio y fin, aforo, profesor, estado (programada, cancelada, hecha) | 1 |
| `closures` | Festivos y cierres | 1 |
| `bookings` | Sesión + alumno + estado (reservada, en espera, cancelada, no presentado) + puesto en lista | 1 |
| `attendances` | Sesión + alumno + método (profesor, QR, kiosco) + hora; única por sesión y alumno | 1 |
| `rank_systems`, `ranks` | Sistema adulto e infantil; cinturones y grados ordenados | 1 |
| `promotion_rules` | De rango a rango: clases mínimas, meses mínimos, requiere visto bueno | 1 |
| `promotions` | Alumno, rango, fecha, quién graduó, nota | 1 |
| `audit_log` | Quién cambió qué y cuándo en datos sensibles | 1 |
| `plans` | Tipo (ilimitado, N por semana, créditos, suelta, prueba), precio, ciclo, disciplinas permitidas | 2 |
| `subscriptions` | Alumno + plan + estado + fechas + congelaciones | 2 |
| `credit_ledger` | Movimientos de créditos de bonos, con caducidad | 2 |
| `payments` | Importe, periodo, método (efectivo, Bizum, transferencia, SEPA, Stripe), estado, referencia externa | 2 |
| `documents`, `signatures` | Versiones de consentimientos; quién firmó, cuándo y ruta del PDF | 2 |
| `licenses` | Licencia federativa y seguro: número, caducidad | 2 |
| `announcements` | Anuncios a todos o a un grupo | 2 |
| `push_subscriptions`, `notifications` | Suscripciones de cada dispositivo; bandeja y registro de envíos | 2 |
| `products`, `orders`, `coupons` | Tienda, seminarios y descuentos | 3 |
| `techniques`, `session_notes` | Biblioteca técnica y qué se dio en cada clase | 3 |
| `competitions`, `competition_entries` | Torneos, inscritos y resultados | 3 |

Funciones transaccionales:

- `book_session(session_id, profile_id)`: bloquea la sesión, valida plan, deuda y aforo; devuelve plaza o puesto en espera.
- `cancel_booking(booking_id)`: aplica el plazo de cancelación y promueve al siguiente.
- `check_in(session_id, profile_id, client_id)`: idempotente; admite alumnos sin reserva si hay hueco.
- `generate_sessions(weeks)`: crea las sesiones de las próximas semanas desde las plantillas, saltando cierres.
- `promotion_candidates(gym_id)`: alumnos que cumplen las reglas de su siguiente rango.

Reglas de acceso (RLS):

| Rol | Ve y modifica |
| --- | --- |
| Alumno | Su perfil, los de sus menores, sus reservas, asistencia, rangos y cobros; el horario completo |
| Profesor | Lo anterior, más listas de sus clases, asistencia y rangos de todos los alumnos. No ve cobros |
| Recepción | Alumnos, reservas, asistencia y registro de cobros. No cambia planes ni ajustes |
| Administrador y propietario | Todo lo de su sede; solo el propietario gestiona roles |

Cada política lleva una prueba automatizada que intenta leer datos ajenos y debe fallar.

## Pagos y facturación en España

La app empieza registrando cobros a mano y deja el cobro automático para la Fase 3. Así resuelve desde el principio lo que más duele en el día a día (saber quién ha pagado) sin tocar dinero real ni normativa.

| Vía | Cómo funciona | Coste | Esfuerzo |
| --- | --- | --- | --- |
| Registro manual | Recepción marca la cuota como pagada e indica Bizum, efectivo o transferencia | Ninguno | Bajo (Fase 2) |
| Remesa SEPA propia | La app genera el fichero pain.008 del mes y se sube a la banca online | El que cobre el banco por remesa | Medio |
| Stripe | Checkout alojado por Stripe, suscripciones, tarjeta y SEPA, portal del cliente | Comisión por operación; consulta la tarifa vigente | Alto: webhooks, impagos, reembolsos |

Notas sobre cada vía:

- **Remesa SEPA.** Requiere que la entidad que cobra tenga contrato de adeudos con su banco e identificador de acreedor, y un mandato firmado por cada alumno. La firma del mandato se guarda con el mismo módulo de consentimientos.
- **Stripe.** Necesita una cuenta a nombre de la entidad que cobra, no cuenta de desarrollador. Al usar su página de pago, los datos de tarjeta nunca pasan por tu app. Como es una web y no una app de tienda, no se aplican las comisiones de Apple ni de Google.
- **Bizum.** No tiene una vía sencilla de cobro automático para un negocio pequeño fuera del TPV virtual del banco. Se registra a mano.

Facturas y Verifactu:

- El calendario vigente en el BOE obliga a las sociedades a usar un sistema de facturación adaptado desde el 1 de enero de 2027, y al resto de obligados desde el 1 de julio de 2027.
- Hacienda ha anunciado su intención de aplazarlo a octubre de 2028. A 25 de octubre de 2026 ese aplazamiento no constaba en el BOE.
- Un programa que emite facturas debe cumplir requisitos técnicos de registro y encadenado. No merece la pena construirlo.
- **Recomendación:** la app emite solo justificantes de pago internos y exporta los cobros del mes en CSV. Las facturas las genera un programa adaptado o la gestoría.

No soy asesor fiscal ni abogado. Qué obligaciones exactas tiene la entidad que cobra (club o sociedad) y si sus cuotas llevan IVA conviene confirmarlo con la gestoría antes de la Fase 2.

Fuentes: [Infoautónomos](https://www.infoautonomos.com/blog/verifactu-cuando-es-obligatorio-a-quien-afecta/), [Noticias Jurídicas](https://noticias.juridicas.com/actualidad/noticias/20735-nueva-prorroga:-verifactu-no-sera-obligatorio-hasta-2027-para-sociedades-y-otros-contribuyentes/), [B2Brouter](https://www.b2brouter.net/es/verifactu-octubre-2028/), [Ecosistema Startup](https://ecosistemastartup.com/?p=122083).

## Métricas de pagos

La pantalla Cobros responde de un vistazo a cuánto se ha cobrado este mes, cuánto falta y cuánto aporta cada tarifa. Todo sale de las tablas `subscriptions` y `payments`, así que funciona igual con cobros manuales que con Stripe. Solo la ven propietario y administrador.

| Métrica | Cómo se calcula | Para qué sirve |
| --- | --- | --- |
| Previsto del mes | Suma de las cuotas de las suscripciones activas en el periodo | El objetivo contra el que se mide lo cobrado |
| Cobrado y pendiente | Pagos confirmados del periodo; previsto menos cobrado | Saber cuánto dinero falta y de cuántos alumnos |
| Por tarifa | Alumnos activos, previsto, cobrado y porcentaje del total de cada plan | Ver qué tarifas sostienen el gimnasio |
| Por método | Cobrado por Bizum, efectivo, transferencia, SEPA y Stripe | Cuadrar caja y banco |
| Impagos | Importe y alumnos con cuota vencida, por antigüedad (menos de 15 días, 15 a 30, más de 30) | Reclamar a tiempo |
| Altas y bajas | Suscripciones que empiezan y terminan en el mes; tasa de bajas | Medir la retención en dinero |
| Ingreso medio por alumno | Previsto dividido entre alumnos de pago | Efecto de descuentos y mezcla de tarifas |
| Evolución | Cobrado por mes en los últimos 12 meses, con el mismo mes del año anterior | Estacionalidad y crecimiento |
| ITACA+ | Suscriptores, ingresos, altas y bajas, y qué parte son alumnos del gimnasio | Saber si el vídeo se paga a sí mismo |
| Comisiones | Importe de comisiones de Stripe y neto recibido | Comparar el coste real de cada método |

Decisiones de diseño:

- **Los pagos anuales se reparten en 12 meses** en las métricas de ingreso recurrente y aparecen enteros en "cobrado". Son dos preguntas distintas y la pantalla muestra ambas.
- **Cada cobro guarda la tarifa y el precio del momento.** Cambiar un precio después no altera los meses pasados.
- **Las métricas son vistas SQL**, no cálculos en el móvil. Así el número es el mismo en la app y en la exportación CSV.
- **Cada cifra se puede tocar** para ver la lista de alumnos o cobros que la componen.

Estas métricas se construyen en el paso 6 (cobros y por tarifa) y en el paso 8 (evolución y cohortes); las de ITACA+ y comisiones, en el paso 11.

## Check-in por QR

El alumno abre la app al llegar, pulsa "Check-in con QR" y apunta la cámara a un cartel en la entrada. El servidor valida y la lista del profesor se actualiza al instante. Empieza con un cartel fijo; solo se pasa a un QR que cambia si aparece picaresca.

| Variante | Qué hace falta | Ventaja | Inconveniente |
| --- | --- | --- | --- |
| **Cartel con QR fijo** (recomendada para empezar) | Un cartel impreso | Coste cero, nada que mantener | Una foto del cartel permitiría fichar desde casa |
| QR que cambia cada 30 segundos | Una tablet o un móvil viejo en recepción mostrando el código | La foto no sirve | Un dispositivo encendido y con red |
| QR personal del alumno | El alumno enseña su código; lo lee una tablet o el móvil del profesor | Sirve para niños sin móvil, con tarjeta impresa | Hace falta alguien o algo que escanee |
| Lista del profesor | Nada | Siempre funciona, también sin red | Trabajo manual |

Cómo se evita el abuso con el cartel fijo, sin hardware:

1. El QR solo contiene un código de la sede. Fuera de la app no hace nada.
2. Solo se escanea desde dentro de la app, con la sesión del alumno iniciada.
3. El servidor acepta el check-in únicamente dentro de una ventana, por ejemplo desde 30 minutos antes hasta 15 después del inicio de una clase.
4. Con reserva, ficha en esa clase. Sin reserva, ficha si queda plaza y su tarifa lo permite.
5. Si tiene la cuota pendiente, ficha igualmente y el profesor ve el aviso; bloquear en la puerta es decisión del gimnasio.
6. El profesor ve quién ha fichado y puede quitar a quien no esté en el tatami.

Detalles técnicos:

- La cámara se abre con la API del navegador y una librería de lectura de QR; no requiere app nativa. Se prueba en iPhone instalado en el paso 0.
- El escáner va dentro de la app porque, en iPhone, escanear con la cámara del sistema abre Safari y no la app instalada.
- Si no hay cobertura, el check-in queda en cola con su hora y se valida al recuperar la red.
- La confirmación es una pantalla completa con nombre, clase y un sonido, visible para el profesor de un vistazo.
- La variante de QR cambiante reutiliza todo: solo cambia que el código lleva una firma con caducidad.

## Monitores y currículo

El administrador ve a cada monitor con las clases que imparte, sus horas y la asistencia que reúne, y decide qué currículo se da en cada clase. El currículo se asigna a la clase, no a la persona: así un sustituto continúa donde iba el grupo y los alumnos no pierden el hilo. La vista por monitor se deriva de sus clases.

Qué puede hacer el administrador:

- Dar de alta monitores y asignarlos a clases recurrentes o a una sesión concreta.
- Poner un sustituto en una sesión sin tocar la clase recurrente.
- Crear currículos: bloques de varias semanas con las técnicas de cada sesión.
- Asignar un currículo a cada clase, con fecha de inicio y ritmo.
- Ver si cada monitor va al día: sesiones dadas frente a las previstas y clases sin registrar.
- Exportar las horas impartidas por monitor y mes.

Qué ve el monitor: en la pantalla de pasar lista aparece "hoy toca" con la unidad del currículo. Al cerrar la lista confirma lo que dio, o anota qué dio en su lugar. No ve cobros ni datos de otros monitores.

| Métrica por monitor | Cómo se calcula |
| --- | --- |
| Clases por semana | Clases recurrentes asignadas |
| Horas impartidas | Suma de la duración de las sesiones dadas en el mes, sustituciones incluidas |
| Asistencia media | Media de asistentes por sesión impartida |
| Seguimiento del currículo | Sesiones registradas según lo previsto frente al total |
| Retención de sus grupos | Alumnos que siguen viniendo a sus clases a los 3 meses |

Tablas nuevas o ampliadas:

| Tabla | Contenido clave |
| --- | --- |
| `class_templates`, `class_sessions` | Ya tenían monitor; la sesión añade monitor sustituto |
| `curricula` | Nombre, disciplina, nivel, duración en semanas |
| `curriculum_units` | Orden, semana, técnicas de la sesión y vídeo asociado si existe |
| `curriculum_assignments` | Clase recurrente, currículo, fecha de inicio, estado |
| `session_notes` | Qué unidad se dio realmente en cada sesión y quién la dio |

Un mismo currículo sirve para el tatami y para ITACA+. La unidad que se da en clase enlaza con su vídeo, de modo que el alumno ve en la app qué toca esta semana y, si está suscrito, repasa la técnica después.

A tener en cuenta:

- **Medir a los monitores por asistencia tiene trampa.** La clase de las 19:00 siempre llena más que la de las 7:00. Las cifras sirven para ver tendencias de un mismo grupo, no para comparar personas.
- **El registro de lo dado debe costar un toque.** Si exige escribir, no se hará y el seguimiento quedará vacío.
- **Las horas exportadas son un dato de gestión**, no una nómina. Cómo se retribuye a cada monitor queda fuera de la app.

Se construye en el paso 2 (monitores y asignación a clases), el paso 4 ("hoy toca" y registro al cerrar la lista) y el paso 11 (currículos enlazados con vídeo).

## ITACA+: vídeo por suscripción con Stripe

ITACA+ es una sección de la misma app con vídeos de clases, técnicas sueltas y currículos, a la que se accede con una suscripción de Stripe aparte de la cuota del gimnasio. Al ser una web y no una app de tienda, la suscripción no paga comisión a Apple ni a Google.

Contenido:

| Tipo | Qué es | Dónde aparece |
| --- | --- | --- |
| Clase grabada | Vídeo ligado a una sesión del horario | En el detalle de esa clase y en "Clases que te perdiste" |
| Técnica | Clip corto etiquetado por posición, tipo (pasaje, sumisión, raspado) y nivel | Biblioteca con buscador y filtros |
| Currículo | Serie ordenada de técnicas con progreso | Cursos, por ejemplo "Fundamentos de guardia cerrada" |

Cómo funciona el acceso:

1. El alumno pulsa "Suscribirme a ITACA+" y paga en la página de Stripe Checkout. La app nunca ve la tarjeta.
2. Stripe avisa por webhook a una Edge Function, que crea o renueva un **derecho de acceso** con fecha de fin.
3. Al abrir un vídeo, otra función comprueba ese derecho y devuelve una dirección de reproducción firmada que caduca en pocas horas.
4. Sin derecho vigente se ve la ficha y un avance, no el vídeo. Compartir el enlace no sirve: caduca.
5. Altas, bajas, cambio de tarjeta y recibos se gestionan en el portal de cliente de Stripe.

El derecho de acceso es independiente de cómo se obtuvo. Eso permite regalarlo a mano, incluirlo en un plan superior del gimnasio o venderlo a gente de fuera sin tocar el código de reproducción.

Stripe entra primero por ITACA+ y no por las cuotas. Es un ingreso nuevo, sin alumnos que migrar ni mandatos que recoger, y permite aprender webhooks e impagos con poco riesgo. Las cuotas del gimnasio pueden pasar a Stripe después reutilizando todo lo construido.

Tablas nuevas:

| Tabla | Contenido clave |
| --- | --- |
| `videos` | Identificador en el proveedor, título, tipo, disciplina, etiquetas, duración, estado, visibilidad (libre, alumnos, ITACA+), sesión asociada |
| `courses`, `course_items` | Currículos y orden de sus vídeos |
| `video_progress` | Por alumno y vídeo: segundo alcanzado y completado |
| `entitlements` | Alumno, producto, origen (Stripe, manual, plan), vigencia |
| `stripe_customers`, `stripe_subscriptions` | Enlace entre perfil y objetos de Stripe; estado de la suscripción |
| `stripe_events` | Eventos recibidos, para procesar cada uno una sola vez |

Pasos de construcción, a continuación del paso 8:

| Paso | Qué pedir | Hecho cuando |
| --- | --- | --- |
| 9 | Stripe en modo de pruebas: producto ITACA+, Checkout, portal de cliente, webhooks, `entitlements` | Una suscripción de prueba concede el acceso y su cancelación lo retira |
| 10 | Biblioteca de vídeo: subida reanudable desde el móvil del profesor, catálogo, reproductor con dirección firmada, progreso | Un usuario sin suscripción no reproduce un vídeo ni copiando el enlace |
| 11 | Currículos, vídeos ligados a sesiones, buscador por posición y técnica, impagos y avisos de renovación | Un alumno completa un currículo y ve la clase que se perdió |

Valoración crítica:

- **El coste real es el tiempo de grabar y editar, no el alojamiento.** Subir cada clase de 90 minutos sin editar llena la biblioteca de horas que casi nadie ve. Rinde más grabar la explicación técnica del día, de 5 a 10 minutos, y ligarla a la sesión.
- **En una clase grabada salen alumnos.** Hace falta consentimiento de imagen de cada uno y del tutor en menores. Lo más limpio es encuadrar solo al profesor y a su compañero de demostración.
- **Una PWA no descarga vídeo para verlo sin conexión** de forma fiable. ITACA+ será solo en streaming.
- **Protección razonable, no absoluta.** Las direcciones firmadas frenan el enlace compartido; nada impide grabar la pantalla. El DRM de verdad cuesta del orden de 100 $/mes y no compensa a esta escala.
- **Fiscalidad.** Una suscripción de vídeo es un servicio digital y puede tributar distinto de la cuota deportiva, con reglas propias si se vende fuera de España. Stripe cobra una comisión por operación. Ambas cosas se confirman con la gestoría y en la tarifa vigente de Stripe antes del paso 9.

Decisiones de ITACA+ por tomar:

- [ ] ¿Solo para alumnos del gimnasio o también para gente de fuera?
- [ ] Precio mensual y si hay opción anual.
- [ ] ¿Se incluye en algún plan del gimnasio o es siempre un extra?
- [ ] Qué se graba: clase entera, solo la explicación, o ambas.
- [ ] Cuánto tiempo se conservan las clases grabadas (las técnicas y currículos, siempre).
- [ ] Quién graba, edita y sube, y con qué frecuencia.

## Alojamiento de vídeo

Bunny Stream es la opción más barata para este caso: cobra por gigabyte almacenado y servido, codifica gratis y tiene un mínimo de 1 $/mes. Para una biblioteca de 100 horas vista por 50 suscriptores sale en torno a 7 $/mes, frente a unos 14 $ en Mux y 42 $ en Cloudflare Stream.

| Proveedor | Cómo cobra | Tarifas publicadas | Coste estimado del ejemplo |
| --- | --- | --- | --- |
| **Bunny Stream** | Por GB almacenado y GB servido | 0,01 $/GB al mes de almacenamiento (Fráncfort); 0,01 $/GB servido en Europa; codificación H.264 hasta 1080p gratis; mínimo 1 $/mes | Unos 7 $/mes |
| Mux | Por minuto almacenado y minuto servido | 0,0024 $ por minuto almacenado al mes a 720p; 100.000 minutos servidos gratis al mes, luego 0,0008 $; el plan gratuito admite solo 10 vídeos | Unos 14 $/mes a 720p, más a 1080p |
| Cloudflare Stream | Por minuto almacenado y minuto servido | 5 $ por 1.000 minutos almacenados; 1 $ por 1.000 minutos servidos; sin nivel gratuito | Unos 42 $/mes |
| YouTube no listado | Gratis | Sin control de acceso: quien tiene el enlace, lo ve | No sirve para contenido de pago |
| Almacenamiento propio + codificación propia | Por GB | Depende del proveedor | Barato solo a gran escala; hay que construir codificación, reproductor y firma |

El ejemplo supone 100 horas de vídeo (6.000 minutos) y 50 suscriptores que ven 4 horas al mes cada uno (12.000 minutos). Para Bunny he supuesto unos 4 GB almacenados por hora con todas las calidades y 1,5 GB servidos por hora vista; son estimaciones mías, no cifras del proveedor. Su calculadora oficial da el número exacto.

Por qué Bunny encaja mejor aquí:

- **El almacenamiento crece sin dolor.** Grabar 30 horas de clases al mes añade alrededor de 1,20 $/mes en Bunny y 9 $/mes en Cloudflare Stream. Al año son unos 14 $ frente a más de 100 $ mensuales solo por guardar.
- **Incluye lo necesario.** Reproductor, calidades adaptativas y direcciones firmadas con caducidad van incluidos en el precio. El DRM empresarial es de pago y no hace falta.
- **Empresa y almacenamiento en la UE.** Simplifica el encaje con el RGPD.
- **Integración sencilla.** La app guarda solo el identificador del vídeo; el fichero nunca pasa por Supabase.

Cuándo mirar otra opción: si la biblioteca es pequeña y se ve mucho, Mux puede salir parecido gracias a sus minutos gratuitos. Cloudflare Stream solo compensa por simplicidad de facturación.

Para mantener el coste bajo:

- Grabar a 1080p como máximo; 720p basta en móvil y reduce almacenamiento y tráfico.
- Caducar las clases grabadas a los pocos meses y conservar técnicas y currículos.
- Subir desde el móvil directamente al proveedor con subida reanudable, sin pasar por el servidor.
- No reproducir automáticamente ni precargar vídeo en las listas.
- Guardar la abstracción del proveedor en un solo módulo, para poder cambiarlo.

Fuentes: [Bunny Stream, precios](https://bunny.net/pricing/stream/), [Bunny, documentación de precios](https://docs.bunny.net/stream/pricing), [Cloudflare Stream, precios](https://developers.cloudflare.com/stream/pricing/), [Mux, precios](https://mux.com/pricing), [Orb, captura de precios de Mux](https://www.withorb.com/pricing-atlas/mux), [Swarmify, análisis de Bunny Stream](https://swarmify.com/blog/bunny-stream-review/). Tarifas tomadas de resúmenes de búsqueda en noviembre de 2026; confírmalas en las páginas oficiales.

## Diseño gráfico

El lenguaje visual de Maat es blanco y negro con un único acento amarillo: fondo blanco, tarjetas gris muy claro con esquinas muy redondeadas, botones negros en forma de píldora y titulares en mayúsculas condensadas y pesadas. La app toma ese lenguaje, con nombre, logotipo e iconos propios; no se copian sus recursos.

Valores de partida, estimados a ojo sobre su web el 13 de noviembre de 2026:

| Elemento | Valor | Uso |
| --- | --- | --- |
| Fondo | `#FFFFFF` | Pantallas |
| Superficie | `#F4F4F2` | Tarjetas y bloques |
| Texto | `#0A0A0A` | Texto y botones primarios |
| Texto secundario | `#6B6B6B` | Etiquetas y ayudas |
| Acento | `#FFE14D` | Una sola llamada a la acción por pantalla |
| Éxito | `#D9F5DD` con texto `#1B7A33` | Chips de "Activo", "Reservada" |
| Aviso y error | `#FFE9C7` y `#FBE0E0` | Lista de espera, impago |
| Radio | 24 px en tarjetas, píldora en botones y chips |  |
| Titulares | Barlow Condensed 800 o Anton, en mayúsculas | Títulos de pantalla |
| Texto | Inter o DM Sans, 16 px de base | Todo lo demás |

Todos los colores viven como variables en un solo fichero, de modo que cambiar el amarillo por el color del gimnasio es editar una línea. El modo oscuro invierte fondo y texto y mantiene el acento.

Navegación con barra inferior de cuatro o cinco pestañas, distinta según el rol:

| Alumno | Personal |
| --- | --- |
| Hoy: próxima clase y botón de reservar | Hoy: clases del día y pasar lista |
| Horario: semana con aforo en vivo | Alumnos: búsqueda, filtros, ficha |
| Progreso: cinturón, grados, asistencia, rachas | Horario: plantillas, sesiones, cierres |
| Perfil: plan, cobros, familia, documentos | Cobros: cuotas del mes e impagos |
|  | Más: graduaciones, anuncios, analítica, ajustes |

Pantallas de la Fase 1: bienvenida e instalación, inicio de sesión, Hoy, Horario, detalle de clase, mis reservas, progreso, perfil, lista de asistencia, escáner QR, lista de alumnos, ficha de alumno, graduar, editor de horario.

Reglas de interfaz móvil:

- Zonas táctiles de 44 px como mínimo y acción principal al alcance del pulgar.
- Respeto de las zonas seguras del iPhone (muesca y barra inferior).
- Reservar y cancelar responden al instante y se confirman después con el servidor.
- Estados vacíos, de carga y sin conexión diseñados, no improvisados.
- Contraste AA: el amarillo solo lleva texto negro encima.

Antes de programar conviene maquetar las cinco pantallas clave (Hoy, Horario, detalle de clase, pasar lista, progreso) y fijar el diseño con ellas.

## Seguridad y RGPD

La app guarda datos de menores y firmas, así que la protección de datos es un requisito de diseño desde la Fase 0. El responsable del tratamiento es la entidad que gestiona el gimnasio, no tú como desarrollador.

- **Menores.** En España el consentimiento propio vale desde los 14 años; por debajo lo da el tutor. Los menores de 14 no tienen cuenta: los gestiona el perfil del tutor.
- **Datos de salud.** Son categoría especial. Recomiendo no guardar historial médico ni lesiones: basta un campo libre opcional de "observaciones para el profesor" con consentimiento expreso, o dejarlo en papel.
- **Mínimo de datos.** Nombre, contacto, fecha de nacimiento, contacto de emergencia. Sin DNI salvo que la licencia federativa lo exija, y en ese caso solo visible para administración.
- **Región.** Proyecto de Supabase en una región de la UE y contrato de encargo de tratamiento aceptado con cada proveedor.
- **Derechos.** Botón de exportar mis datos y proceso de borrado que anonimiza la asistencia en lugar de romper las estadísticas.
- **Fotos y vídeos.** Consentimiento de imagen separado del de responsabilidad, revocable.
- **Accesos.** Roles con RLS probado, doble factor para administradores, registro de auditoría en cobros, rangos y roles.
- **Secretos.** Claves de servicio, de Stripe y de push solo en variables de entorno del servidor; nunca en el repositorio.
- **Copias.** Copia semanal cifrada y una prueba de restauración al menos una vez.
- **Textos legales.** Política de privacidad y aviso legal visibles antes del registro.

Esto es orientación técnica, no asesoramiento legal. El texto de los consentimientos y el registro de actividades de tratamiento debería revisarlos alguien con conocimiento de protección de datos.

## Plan de construcción con Opus 5.5

El código se construye en nueve pasos cortos, más tres para Stripe e ITACA+ descritos en su sección, cada uno en una sesión nueva que termina con pruebas en verde y un commit. Este documento, exportado a Markdown, es la especificación que el modelo lee al empezar cada sesión.

Qué instalar en tu ordenador:

- Node.js LTS y Git.
- Docker Desktop (Supabase local corre en contenedores).
- Supabase CLI.
- Cuentas gratuitas de GitHub, Supabase y Cloudflare. Ninguna es de desarrollador de Apple o Google.

Estructura del repositorio:

```text
gym-app/
  CLAUDE.md               normas del proyecto para el modelo
  docs/
    SPEC.md               este plan, exportado
    DECISIONS.md          decisiones tomadas y por qué
    PROGRESS.md           qué paso está hecho y qué queda
  supabase/
    migrations/           SQL versionado: tablas, RLS, funciones
    functions/            Edge Functions: push, email, stripe
    tests/                pruebas pgTAP de permisos y funciones
    seed.sql              datos de ejemplo
  src/
    app/                  rutas y layouts por rol
    features/             schedule, bookings, attendance, ranks, members, billing
    components/ui/        botones, tarjetas, chips, hojas
    lib/                  cliente supabase, cola offline, fechas, i18n
    styles/tokens.css     colores, radios, tipografía
    locales/              es.json, en.json
  public/                 manifiesto e iconos
  e2e/                    pruebas Playwright
```

Contenido de `CLAUDE.md`: stack fijado, los seis principios de arquitectura, "lee `docs/SPEC.md` y `docs/PROGRESS.md` antes de empezar", "no avances de paso sin pruebas en verde", "actualiza `PROGRESS.md` y haz commit al terminar", "pregunta antes de añadir una dependencia".

| Paso | Qué pedir | Hecho cuando |
| --- | --- | --- |
| 0 | Proyecto Vite + React + TS + Tailwind, Supabase local, PWA instalable, tokens de diseño, despliegue en Cloudflare Pages | Se instala en un Android y un iPhone y muestra una pantalla de inicio |
| 1 | Tablas `gyms`, `profiles`, `gym_members`, `guardianships`; inicio de sesión; RLS por rol con pruebas | Las pruebas de permisos fallan al leer datos ajenos |
| 2 | Disciplinas, plantillas, sesiones, cierres, `generate_sessions`; pantallas Horario y editor | El horario de cuatro semanas se genera desde las plantillas |
| 3 | `bookings`, `book_session`, `cancel_booking`, aforo en tiempo real; Hoy, detalle de clase, mis reservas | Dos reservas simultáneas a la última plaza dan una plaza y una espera |
| 4 | Asistencia: lista del profesor con cola sin conexión, QR y modo kiosco | Se pasa lista en modo avión y sincroniza sin duplicados |
| 5 | Rangos, reglas, graduaciones, "listo para graduar", pantalla Progreso; importación y exportación CSV | Fase 1 completa: se usa una semana real en el gimnasio |
| 6 | Planes, suscripciones, créditos, cobros manuales, bloqueo por deuda, panel de impagos | Un alumno con deuda no puede reservar |
| 7 | Push, email, bandeja, recordatorios programados, anuncios, consentimientos con firma, licencias | Un aviso de lista de espera llega a un iPhone instalado |
| 8 | Ranking, rachas, analítica con cohortes, enlace ICS, copia semanal automatizada | Fase 2 completa |

Plantilla de mensaje para cada sesión:

```text
Lee CLAUDE.md, docs/SPEC.md y docs/PROGRESS.md.
Implementa el paso N: <texto de la tabla>.
Antes de escribir código, propón el plan de ficheros y las migraciones SQL y espera mi visto bueno.
Escribe primero las pruebas de permisos y de las funciones SQL.
Al terminar: ejecuta todas las pruebas, actualiza PROGRESS.md y haz commit.
```

Consejos de trabajo:

- **Un paso por sesión.** Pedir la app entera de una vez produce código que parece completo y no lo está.
- **Revisa tú las migraciones SQL y las políticas RLS.** Es donde un error cuesta caro; el resto se corrige fácil.
- **Usa el gimnasio como banco de pruebas** al final de cada fase, con cinco o diez alumnos, antes de abrirlo a todos.
- **La Fase 3 se planifica después**, con lo aprendido del uso real.

## Riesgos y decisiones abiertas

Cinco decisiones tuyas condicionan el plan; la primera puede cambiar la arquitectura de cobros y el esfuerzo total.

- [ ] **¿Solo para tu gimnasio o para ofrecerla a otros?** El plan asume lo primero. Venderla implica alta de gimnasios, cobros por cuenta de terceros, soporte y contratos.
- [ ] **Nombre e identidad.** Hace falta nombre, icono y color de acento propios antes del paso 0.
- [ ] **Cómo se cobra hoy y quién cobra.** Determina si la Fase 3 es remesa SEPA, Stripe o ninguna.
- [ ] **Clases infantiles.** Si las hay, perfiles de menores y sistema de cinturones infantil entran en la Fase 1; si no, se aplazan.
- [ ] **Número de alumnos y de profesores.** Para dimensionar aforos, roles y la prueba piloto.

| Riesgo | Efecto | Mitigación |
| --- | --- | --- |
| Push poco fiable o instalación confusa en iPhone | Alumnos que no reciben avisos | Prueba en el paso 0, guía de instalación, copia por email, bandeja interna |
| Cambios en el plan gratuito de Supabase | Coste inesperado o migración | Postgres estándar y migraciones en el repositorio: se mueve a otro proveedor |
| Pérdida de datos sin copias | Se pierde asistencia y cobros | Copia semanal automatizada desde el paso 8, o plan Pro |
| Error en permisos (RLS) | Un alumno ve datos de otro | Pruebas automatizadas de cada política y revisión manual |
| Alcance que crece | La Fase 1 no llega a usarse | Fases cerradas; nada de la Fase 3 antes de un mes de uso real |
| Dependencia de una sola persona | Si lo dejas, la app se queda sin mantenimiento | Documentación en el repositorio y exportación completa de datos siempre disponible |

## Fuentes

- [Maat, página de funciones](https://maatapp.com/features), consultada el 13 de noviembre de 2026.
- [Supabase, pausa de proyectos gratuitos](https://supabase.com/kb/faqs/platform/free-project-pausing).
- [IT Path Solutions, límites del plan gratuito de Supabase](https://www.itpathsolutions.com/supabase-free-tier-limits).
- [MobiLoud, PWA en iOS](https://www.mobiloud.com/blog/progressive-web-apps-ios).
- [Monterail, PWA en iOS](https://monterail.com/blog/pwa-for-apple-ios).
- [Infoautónomos, calendario de Verifactu](https://www.infoautonomos.com/blog/verifactu-cuando-es-obligatorio-a-quien-afecta/).
- [B2Brouter, aplazamiento anunciado de Verifactu](https://www.b2brouter.net/es/verifactu-octubre-2028/).

Los límites de Supabase y las fechas de Verifactu proceden de resúmenes de búsqueda, no de las páginas oficiales leídas completas; confírmalos antes de decidir sobre ellos.
