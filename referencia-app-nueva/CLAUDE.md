# Normas del proyecto

Lee `docs/SPEC.md` y `docs/PROGRESS.md` antes de empezar. Las pantallas de referencia están en `docs/diseno/`.

## Stack fijado

React 19 + Vite + TypeScript + Tailwind 4 en cliente, React Router 7, vite-plugin-pwa. Backend previsto: Supabase (Postgres, Auth, RLS, Edge Functions). Pruebas: Vitest (después pgTAP para RLS y Playwright).

## Principios de arquitectura

1. **La base de datos manda.** Aforo, elegibilidad por plan y plazos de cancelación se comprueban en funciones SQL. El cliente solo pide. Hasta entonces, esas reglas viven en `src/lib/logic.ts` y son la especificación de las funciones SQL.
2. **Todo lleva `gym_id`.** Una sola sede hoy, varias mañana sin migrar datos.
3. **Sin conexión, solo lo necesario.** Lectura cacheada de horario, reservas y perfil. Escritura en cola únicamente para pasar lista y check-in, con un identificador generado en el móvil para que reenviar no duplique.
4. **La clave de servicio nunca sale del servidor.** El cliente usa solo la clave pública y RLS.
5. **Migraciones SQL versionadas en el repositorio.**
6. **Horas en UTC en la base, Europe/Madrid en pantalla.** Las clases recurrentes se definen en hora local.

## Forma de trabajar

- Un paso del "Plan de construcción" de `docs/SPEC.md` por sesión.
- No avances de paso sin las pruebas en verde (`npm test` y `npm run build`).
- Actualiza `docs/PROGRESS.md` y haz commit al terminar.
- Pregunta antes de añadir una dependencia.
- Colores y fuentes solo desde `src/styles/tokens.css`; nada de colores sueltos salvo el texto sobre el acento.
- Las pantallas solo leen y escriben a través de `useApp()` (`src/lib/store.tsx`), para que el cambio a Supabase quede aislado.
- Textos de la interfaz en español; i18n (ES/EN) pendiente.
