# Cómo usar este código

Copia del código de la app de ITACA Jiu Jitsu preparada para compartir. El autor permite reutilizar el código que necesites.

**Qué no incluye:** claves de acceso, tokens, contraseñas ni datos de alumnos. Los datos de contacto del gimnasio están sustituidos por valores de ejemplo (`contacto@tu-gimnasio.com`, `+34600000000`…) y el identificador del proyecto de Supabase por `TU_PROJECT_REF`.

## Arrancarla en tu ordenador

Necesitas Node 20 y Docker Desktop.

```bash
npm install
npm run db:start        # Supabase local en Docker
npm run db:reset        # crea las tablas y carga datos de prueba
cp .env.example .env.local
```

Rellena `VITE_SUPABASE_ANON_KEY` en `.env.local` con la clave pública que muestra `npx supabase status`, y:

```bash
npm run dev             # http://localhost:5173
```

Sin `.env.local` la app arranca en modo demo, con datos de ejemplo y sin servidor.

Los correos de prueba (enlaces para entrar) llegan a Mailpit: http://127.0.0.1:54324. Usuarios de prueba: ver `supabase/seed.sql` (por ejemplo `admin@itaca.test`).

## Pruebas

```bash
npm test                # lógica de la app (Vitest)
npm run test:db         # permisos y reglas de la base de datos (pgTAP)
```

## Publicarla con tu propia cuenta

Crea tu proyecto en Supabase y en Cloudflare Pages, cambia `TU_PROJECT_REF` en `supabase/config.toml` y sigue `docs/PRODUCCION.md`. Para reutilizarla en otro gimnasio, cambia también el nombre, el logotipo (`src/components/BrandMark.tsx`, `public/`) y los datos de `supabase/production/setup.sql`.

La documentación del diseño y las decisiones está en `docs/` (`SPEC.md`, `PROGRESS.md`, `DECISIONS.md`).
