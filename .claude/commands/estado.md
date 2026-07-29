---
description: Foto del estado del proyecto en lenguaje claro — qué está hecho, qué está a medias y qué queda.
---

Dale a Cipri una foto del estado de la app. **Él no es desarrollador: escribe en cristiano, sin jerga ni volcados técnicos.**

Averigua primero por tu cuenta, sin pedirle nada:

1. **Sincronía**: `git fetch` y compara la rama actual con `origin/claude/app-setup-github-nohews`. ¿Hay trabajo sin fusionar?
2. **Salud**: con Flutter en el PATH, ejecuta `flutter analyze` y `flutter test`. ¿Verde?
3. **Pull requests abiertos**: cuáles hay, si su CI está en verde y si esperan algo de él.
4. **Despliegue**: último despliegue de producción en Vercel (proyecto `itc2-reservas`) y si está correcto.
5. **Migraciones**: cuántas hay en `supabase/migrations/` y si alguna está pendiente de aplicar.

Luego responde en cuatro bloques cortos:

- **Qué funciona hoy** — en términos de lo que puede hacer una persona con la app.
- **Qué está a medias** — con una frase de por qué.
- **Qué necesita de ti** — decisiones, cuentas o pruebas que solo puede hacer él.
- **Qué haría yo ahora** — una recomendación, no una lista de opciones.

Si algo no lo has podido comprobar, **dilo**. No rellenes huecos con suposiciones.
