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
