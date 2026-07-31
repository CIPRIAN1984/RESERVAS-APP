# RESERVAS-APP (I+) — Memoria del proyecto

> Referencia maestra para trabajar en este repositorio. Léela antes de proponer nada.
> Si algo aquí contradice lo que ves en el código, **manda el código** — y avísale a Cipri del conflicto.

---

## 0. CÓMO TRABAJAR CON CIPRI (lo más importante)

**Cipri no es desarrollador.** Te habla en castellano y describe **lo que quiere conseguir**, no cómo hacerlo. Tú traduces eso a decisiones técnicas.

1. **Decide tú lo técnico.** No le preguntes qué paquete, qué patrón o qué nombre de tabla. Elige lo mejor y explica en una línea por qué.
2. **Pregunta solo lo que él decide mejor que tú**: qué debe hacer el producto, qué texto ve el usuario, qué prioridad tiene algo, si asume un riesgo.
3. **Explica en cristiano.** Si dices "RLS", añade en una frase qué es. Los riesgos, con consecuencias reales ("un alumno podría hacerse administrador"), no con jerga.
4. **Sé honesto con los fallos.** Si te equivocas, dilo y arréglalo. Él confía en lo que le dices y no puede verificarlo por su cuenta.
5. **Verifica antes de afirmar.** No digas "ya funciona" sin haberlo comprobado. Si no puedes (móvil real, cobros de verdad, correos), **dilo y dile exactamente qué debe probar él**.
6. **Trabajo terminado = probado.** `flutter analyze`, `flutter test` y el build en verde antes de decir que está hecho.
7. **Los pasos manuales, masticados.** SQL listo para copiar y pegar, con dónde pegarlo. Nunca "aplica la migración".

**Cómo presentar el trabajo:** qué has hecho, qué tiene que hacer él (si algo), y qué queda pendiente.

---

## 1. Qué es esta app

App de **reservas y gestión** para la academia de BJJ de Cipri (**ITC.2 Lab / Ítaca Jiu-Jitsu**, Logroño).
Sustituirá a **MAAT**, el software de terceros que usan hoy.

**Contexto crítico:** hay ~166 alumnos pagando y **unos 10.000 €/mes recurrentes** en juego. Nada que toque dinero se despliega sin fase de pruebas en paralelo.

**No confundir con:**
- **ITACA OS / `itacaplus`** — repositorio aparte, sistema pedagógico (Next.js). **No se mezclan.**
- **El prototipo I+ en React** — maqueta con datos falsos hecha para validar el diseño. No es esta app.

**Estado (julio 2026):** desplegada en Vercel y Supabase, sin usuarios reales todavía. Seguridad endurecida, cobros implementados pero **nunca conectados a Stripe real**.

---

## 2. Stack

- **App:** Flutter (Dart ≥ 3.12) · Riverpod · go_router · freezed
- **Backend:** Supabase — Auth, PostgreSQL con RLS, Edge Functions en Deno
- **Cobros:** Stripe Connect (cada academia cobra en su cuenta; el dinero no pasa por la plataforma)
- **Web:** Vercel → proyecto `itc2-reservas`
- **Base de datos:** proyecto Supabase `dpcdpcvjcutcqyqcacti` (`itc2-reservas`, eu-west-1)

**Comandos:**
```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release
dart run build_runner build --delete-conflicting-outputs   # tras tocar modelos/providers
```

Flutter **no viene instalado** en las sesiones nuevas. Instálalo antes de verificar:
```bash
git clone -b stable --depth 1 https://github.com/flutter/flutter.git /opt/flutter
export PATH=/opt/flutter/bin:$PATH
```

---

## 3. Modelo de datos (real, 26 migraciones)

**Núcleo:** `academias` · `profiles`
**Clases:** `clases` · `clases_recurrentes` · `inscripciones` · `asistencias`
**Contenido:** `novedades`
**Tienda:** `productos` · `pedidos` · `prestamos`
**Cobros:** `tarifas` · `suscripciones` · `stripe_webhook_events`
**Otros:** `solicitudes_cambio_escuela` · `device_tokens` · `notificaciones_outbox`

**Roles:** `administrador` (plataforma) · `dueño` (con ñ en la BD) · `profesor` · `alumno`
**Estados de perfil:** `activo` · `pendiente_aprobacion`

### Reglas de seguridad que NO se pueden romper

- **Aislamiento por academia**: todo filtra por `current_academia_id()`. Un dueño nunca ve otra academia.
- **`profiles` y `academias` tienen columnas revocadas**: el cliente no puede cambiarse el `rol`, el `estado` ni las columnas de Stripe. Se hizo con `revoke update` de tabla + `grant update (columnas)`. **Un `revoke` de columna suelto no sirve si ya existe un GRANT de tabla completa** — lección aprendida en la migración 0013.
- **Reservar pasa siempre por la RPC `reservar_clase`**, que bloquea la fila de la clase (no se puede superar el aforo con reservas simultáneas). Exigir cuota activa y cobrada es **opcional por academia** (`academias.exigir_cuota_para_reservar`, por defecto `false`): decisión de Cipri de julio de 2026, prefiere que la gente se apunte igual y verlos marcados «sin cuota» en la lista de la clase para cobrarles en mano.
- **El alta de usuario es atómica**: el trigger `handle_new_user` crea perfil y academia en la misma transacción del registro. El rol lo impone el servidor.
- **Las suscripciones solo las activa el webhook de Stripe** con `service_role`. El alumno no puede auto-activarse.

### RPCs que usa la app
`reservar_clase` · `cancelar_reserva` · `listar_clases_semana` · `ranking_mensual` · `cambiar_rol_miembro` · `aprobar_academia` · `rechazar_academia` · `resolver_cambio_escuela` · `listar_academias_aprobadas` · `registrar_device_token` · `generar_mis_clases_recurrentes`

---

## 4. Decisiones ya tomadas — no volver a proponerlas

- ✅ **Se conserva la arquitectura multi-academia** por debajo, aunque el lanzamiento sea de una sola academia.
- ❌ **El árbol de progreso (técnicas) está ELIMINADO de raíz** (julio 2026, decisión de Cipri: *"quítalo de raíz para siempre, no lo quiero"*). Se borraron las pantallas, las tablas `tecnicas` / `media_tecnica` / `progreso_alumno_tecnica` y sus funciones. Las técnicas que había eran una plantilla genérica de relleno, **no el sistema Ítaca** — el método pedagógico vive en `itacaplus` y no se replica aquí. Hay una prueba pgTAP que falla si alguien lo reintroduce. **No volver a proponerlo.**
- ❌ **No conectar Stripe real** hasta que haya semanas de funcionamiento en paralelo con MAAT.
- ❌ **No mezclar este repositorio con `itacaplus`.**
- ✅ **Identidad visual:** ver §6 y la skill `diseno-i-plus`.

---

## 5. Qué falta para poder lanzar

1. **Familias y tutores** — un padre con varios hijos. Hay clases infantiles; sin esto no se lanza.
2. **Gestión de alumnos por el dueño** — altas, bajas, pausas, cobro en efectivo, deudas, excepciones.
3. **Documentos** — certificado médico y descargo de responsabilidad firmado.
4. **Grupos por edad y nivel** y reglas de quién puede reservar qué.
5. **Importador desde MAAT** — 166 alumnos, no se meten a mano.
6. **Publicación en tiendas** (Android/iOS) — cuentas a nombre de Cipri.

**Riesgo mayor, y no es técnico:** mover las suscripciones vivas del Stripe de MAAT al propio. Muchas veces obliga a que cada alumno vuelva a introducir la tarjeta. Es negociación + campaña, no código.

---

## 6. Identidad visual y navegación

La app adopta el diseño **I+**: claro, monocromo, con amarillo eléctrico como único acento y color reservado a lo que significa algo (cinturones y estados de pago). Tipografías **Inter Tight** y **JetBrains Mono**, incrustadas como assets (no de Google Fonts: en redes con DNS filtrado la carga remota falla). **Solo hay tema claro.**

**Dos modos con barra inferior**, no menú lateral:
- **Entrenamiento** (todos): Inicio · Estadísticas · Novedades · Perfil
- **Gestor** (dueño y profesor): Hoy · Herramientas · Novedades · Academia — con hueco reservado para *Miembros*
- El **Administrador de plataforma** no tiene modos: Academias · Cambios · Perfil

El cambio de modo es **el último sitio de la barra inferior**, visible solo para dueño y profesor (a ellos la barra les sale con cinco sitios). Estuvo en un botón flotante y hubo que quitarlo: tapaba «Reservar plaza», el final de Perfil y hasta el botón «Crear clase» de la propia pantalla — en un móvil de 412 px dos botones flotantes no caben uno al lado del otro. El router bloquea las rutas de gestor a los alumnos, no solo las oculta.

Las cabeceras las pone el router con `PantallaConTitulo`, en un único sitio.

👉 **Antes de tocar cualquier pantalla, invoca la skill `diseno-i-plus`.**

---

## 7. Verificación

- `flutter analyze` sin ningún aviso y `flutter test` en verde son el mínimo.
- Las pruebas de base de datos son **pgTAP** en `supabase/tests/` (11 suites). Se ejecutan en CI con `supabase test db`.
- **Para cambios visuales no basta con que compile**: hay que mirarlo renderizado. Hay un banco de pruebas visual en `test/golden/` que dibuja pantallas con las tipografías reales y guarda la imagen (`flutter test --update-goldens test/golden`). Invoca la skill `verificar-app`.
- CI (GitHub Actions): formato, análisis, deriva de codegen, tests, build web, pgTAP y escaneo de secretos.

---

## 8. Documentación viva del repositorio

| Fichero | Para qué |
|---|---|
| `DECISIONS.md` | Decisiones técnicas con su porqué |
| `OPERATIONS.md` | Procedimientos: despliegue, migraciones, incidentes |
| `PRODUCT.md` | Qué hace la app de cara al usuario |
| `PRIVACY.md` | Datos personales y privacidad |
| `MOBILE_RELEASE.md` | Publicación en Android/iOS |

Manténlos al día cuando cambien las cosas que describen.

---

## 9. Protocolo de trabajo (grafo, bucle y arnés)

Adaptado de la plantilla que trajo Cipri el 30/07/2026. **Los papeles están al
revés en la plantilla original**: allí el usuario ejecuta y la IA aconseja.
Aquí es al contrario — Claude tiene el repositorio, la terminal, Supabase,
GitHub y Vercel; Cipri decide producto y prueba en el móvil. Lo que sigue es
la versión que sí encaja con este montaje.

### 9.1 Memoria (amnesia cero)

- Cada sesión empieza **sin recordar nada**. El único mapa son `CLAUDE.md` y
  `DECISIONS.md`. Si algo no está escrito ahí, en la próxima sesión no existe.
- **Escribe la decisión antes de escribir el código**, no después. Si a mitad
  de una tanda se decide una regla de negocio, va a `DECISIONS.md` en ese
  momento. Perder la decisión cuesta mucho más que perder el código.
- Lee del repositorio lo que necesites — es gratis y es la fuente de verdad.
  A Cipri se le pide **solo lo que únicamente él puede dar**: qué debe hacer
  el producto y qué ve en su móvil.

### 9.2 Aristas falsas (qué depende de qué de verdad)

- Antes de encadenar A → B, pregúntate: **¿B necesita algo que produce A?**
  Si no, van en paralelo o en cualquier orden.
- Ejemplos reales de este repositorio:
  - **Arista de verdad:** la migración va **antes** del merge. Al revés, la
    web pide una columna que aún no existe.
  - **Arista falsa:** documentación y pruebas. Se hacían seguidas por
    costumbre; no dependen entre sí.
- **Fontanería al código, criterio a la IA.** Formatear, mapear campos o
  elegir una ruta se resuelve con una línea de Dart o de SQL, no razonando.

### 9.3 Bucle de evidencia

- **No des nada por bueno porque el código se vea bien.** Todo cambio va con
  dos respuestas:
  1. ¿Cómo se prueba que funciona? (el comando exacto)
  2. ¿Cómo se prueba que **fallaría** si estuviera mal?
- La segunda es la que vale: **deshaz el arreglo a propósito y comprueba que
  la prueba se pone roja.** Sin eso no sabes si la prueba mira donde debe. En
  julio de 2026 esto cazó dos pruebas que pasaban por el motivo equivocado.
- **Freno de dos intentos.** Si un enfoque falla dos veces seguidas, no lo
  intentes una tercera: declara que ese camino no va y cambia de estrategia.
  Pasó con el botón de cambio de modo — moverlo de sitio falló dos veces
  hasta aceptar que sobraba un botón flotante, no que estuviera mal puesto.

### 9.4 Filtros antes de entregar

Antes de dar por cerrado un bloque grande, míralo desde tres ángulos
independientes:

1. **Integridad:** ¿rompe datos, permisos o el aislamiento entre academias?
2. **Rendimiento:** ¿mete una consulta por fila, o un redibujado de más?
3. **Mantenimiento:** ¿respeta la skill `diseno-i-plus` y lo ya decidido?

**Un PR, un tema.** Los cambios de un PR pueden tocar varios ficheros si son
la misma cosa (modelo + repositorio + pantalla + prueba), pero **no mezcles
dos temas** en el mismo PR: si uno se cae, se cae el otro.

### 9.5 Comunicación

La plantilla pedía «sin preámbulos, respuestas en diff». **Eso no se aplica
aquí**: Cipri no lee Dart y un diff no le dice nada. Lo que sí se aplica es
ser breve y concreto — sin cortesías de relleno, sin repetir lo ya dicho, y
con la estructura de §0: qué se ha hecho, qué tiene que hacer él, qué queda.
