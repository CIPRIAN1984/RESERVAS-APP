---
name: seguimiento
description: Lista de cosas importantes que hay que revisar de vez en cuando para que no se olviden entre sesiones de Claude Code — cada sesión empieza sin memoria (§9.1 de CLAUDE.md), así que esto es lo que sustituye a "acordarse". Consúltala al empezar una sesión de mantenimiento o revisión general, y añade una entrada en cuanto detectes algo que necesite seguimiento futuro.
---

# Seguimiento

Cada sesión de Claude Code empieza con amnesia total: solo quedan `CLAUDE.md`,
`DECISIONS.md` y lo que esté escrito aquí. Las cosas que hay que **revisar
de vez en cuando** (no arreglar ya, no son bugs abiertos) se pierden fácil
entre sesiones porque nadie las tiene apuntadas en ningún sitio que se
consulte solo. Esta lista es ese sitio.

No es un backlog de tareas ni sustituye a `DECISIONS.md` (el porqué de las
decisiones ya tomadas) ni a las `[ ]` de las checklists operativas de ese
mismo fichero. Es específicamente para: *"esto hay que volver a mirarlo
pasado un tiempo, o antes de que pase X"*.

---

## Activo

### Disponibilidad de `com.itaca.itaca` en Google Play y Apple Developer

- **Por qué importa:** es el identificador candidato de la app para Android
  e iOS (ya está en el código nativo y en los deep links). Si alguien más lo
  registra antes, hay que cambiarlo en todo el proyecto. Si Cipri ya
  publicó el primer binario con este identificador, **ya no se puede
  cambiar** — así que la comprobación tiene que pasar sí o sí antes de esa
  primera subida.
- **Cada cuánto:** una vez por sesión que toque publicación en tiendas, o
  cuando Cipri pregunte por el lanzamiento en Android/iOS.
- **Qué comprobar:** que `com.itaca.itaca` sigue libre en Google Play
  Console y en Apple Developer (Cipri es quien tiene las cuentas y puede
  mirarlo — pídeselo si no se ha comprobado todavía).
- **Cuándo dejar de repetirlo:** en cuanto se confirme la disponibilidad y
  se suba el primer binario con ese identificador. Anota el resultado en
  `DECISIONS.md` y mueve esta entrada a "Resuelto".
- **Fuente:** `DECISIONS.md`, decisión "Identidad y firma de las
  aplicaciones móviles" (2026-07-27).

### El repositorio de GitHub sigue siendo público

- **Por qué importa:** cualquiera puede leer todo el código, las
  migraciones (el diseño completo de permisos) y el historial de
  decisiones. No hay claves dentro —el CI lo vigila—, pero regala a un
  atacante el mapa de la app que va a manejar datos de 166 alumnos y sus
  cobros. Lo señaló la auditoría externa del 23/09/2026.
- **Cada cuánto:** en cada sesión de revisión, hasta que sea privado.
- **Qué comprobar:** `search_repositories` con
  `repo:CIPRIAN1984/RESERVAS-APP` → `"private": true`. Solo lo puede
  cambiar Cipri: GitHub → el repositorio → Settings → abajo del todo,
  «Danger Zone» → Change visibility → Make private. Vercel y Supabase
  siguen funcionando igual.
- **Cuándo dejar de repetirlo:** cuando salga `private: true`.
- **Fuente:** auditoría externa del 23/09/2026; comprobado de nuevo el
  28/09/2026: sigue público.

### Protección contra contraseñas filtradas en Supabase (desactivada)

- **Por qué importa:** sin ella, un alumno puede registrarse con una
  contraseña que ya circula en filtraciones públicas; es la puerta más
  fácil para que alguien entre en su cuenta. Es el único aviso de
  seguridad de Supabase que no se arregla desde código.
- **Cada cuánto:** en cada sesión de revisión, hasta que esté activada.
- **Qué comprobar:** asesor de seguridad de Supabase (`get_advisors`,
  tipo security): no debe salir `auth_leaked_password_protection`. Lo
  activa Cipri en el panel de Supabase → Authentication → Sign In /
  Providers → Email → «Prevent use of leaked passwords».
- **Cuándo dejar de repetirlo:** cuando el asesor deje de mostrarlo.
- **Fuente:** auditoría completa del 27/09/2026 (`DECISIONS.md`).

### La web bloquea hoy los pagos de Stripe (a propósito)

- **Por qué importa:** la política de seguridad de la web (`vercel.json`)
  no deja cargar `js.stripe.com` ni conectar con la API de Stripe, y
  `Permissions-Policy` lleva `payment=()`. Mientras Stripe no esté
  conectado es lo correcto; el día que se conecte, **el pago con tarjeta
  fallará en la web** hasta abrir esas tres cosas.
- **Cada cuánto:** antes de conectar Stripe real (decisión que solo toma
  Cipri, tras semanas en paralelo con MAAT).
- **Qué comprobar:** en `vercel.json`, añadir `https://js.stripe.com` a
  `script-src` y `frame-src`, `https://api.stripe.com` a `connect-src`, y
  quitar `payment=()`. Probar un pago en modo test en la vista previa.
- **Cuándo dejar de repetirlo:** cuando un pago de prueba funcione en la
  web de producción.
- **Fuente:** auditoría completa del 27/09/2026.

### Rendimiento de las políticas RLS al crecer

- **Por qué importa:** el asesor de rendimiento marca 22 políticas que
  evalúan `auth.uid()` fila a fila. Con ~166 alumnos no se nota; con
  varias academias o años de historial, las listas grandes (asistencias,
  inscripciones) se volverán lentas.
- **Cada cuánto:** cada tres meses, o si alguien dice que una lista tarda.
- **Qué comprobar:** `get_advisors` tipo performance y el tiempo de
  `listar_clases_semana` y de la pantalla Miembros. Si hace falta,
  reescribir las políticas con `(select auth.uid())`, con su pgTAP.
- **Cuándo dejar de repetirlo:** cuando se reescriban, o si la app se
  queda en una sola academia pequeña y nunca pasa de lento.
- **Fuente:** auditoría completa del 27/09/2026 (`DECISIONS.md`).

---

## Cómo añadir algo aquí

Cuando detectes algo que hay que volver a mirar más adelante — no ahora
mismo, sino pasado un tiempo o antes de un evento concreto — añade una
entrada nueva en "Activo" con esta forma:

```
### Título corto de una línea

- **Por qué importa:** qué pasa si nadie lo revisa (consecuencia real).
- **Cada cuánto:** con qué frecuencia, o qué evento lo dispara.
- **Qué comprobar:** el paso concreto, con comando o sitio exacto si lo hay.
- **Cuándo dejar de repetirlo:** la condición de salida. Todo seguimiento
  tiene que poder terminar.
- **Fuente:** de dónde sale esto (fichero y fecha), si viene de otro sitio.
```

No inventes entradas. Si algo no tiene un "por qué importa" concreto y una
condición de salida clara, probablemente sea una tarea normal — va a
`DECISIONS.md` o se resuelve directamente, no aquí.

---

## Resuelto / ya no aplica

(vacío por ahora — cuando una entrada de "Activo" deje de necesitar
seguimiento, muévela aquí con la fecha y el motivo, en vez de borrarla.)
