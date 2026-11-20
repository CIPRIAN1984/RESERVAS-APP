# ITACA Jiu Jitsu

App web instalable (PWA) del gimnasio ITACA Jiu Jitsu: reservas, asistencia, cinturones, cobros, monitores e ITACA+ (vídeo por suscripción).

> **Estado:** pasos 1 a 4 hechos: inicio de sesión, roles, horario real, reservas en tiempo real, tarifas, asistencia con check-in por QR y lista sin conexión. Cinturones, cobros y vídeos siguen siendo datos de ejemplo. Ver [docs/PROGRESS.md](docs/PROGRESS.md).

**En producción:** https://itaca-jiu-jitsu.pages.dev — cómo publicar y migrar en [docs/PRODUCCION.md](docs/PRODUCCION.md).

## Probarla

Requisitos: Node.js 20 o superior.

```bash
npm install
npm run dev
```

Abre http://localhost:5173. En escritorio se ve como un móvil centrado; para verla como en el teléfono, usa el modo dispositivo del navegador.

| Comando | Qué hace |
| --- | --- |
| `npm run dev` | Servidor de desarrollo |
| `npm test` | Pruebas de las reglas de negocio (Vitest) |
| `npm run build` | Comprueba tipos y genera `dist/` con el service worker |
| `npm run preview` | Sirve la versión de producción |

## Con servidor (Supabase local)

Requisitos: Docker Desktop y la [CLI de Supabase](https://supabase.com/docs/guides/local-development/cli/getting-started).

```bash
npm run db:start      # arranca Supabase en Docker y aplica migraciones y seed
supabase status       # muestra la URL y la clave pública (anon)
cp .env.example .env.local   # y pega ahí la clave anon
npm run dev
```

Entra con un usuario de prueba de `supabase/seed.sql` (`admin@itaca.test` para editar el horario, `cipri@itaca.test` profesor, `elena@itaca.test` alumna). El enlace mágico llega al buzón local: http://127.0.0.1:54324. Studio (panel de la base de datos): http://127.0.0.1:54323.

| Comando | Qué hace |
| --- | --- |
| `npm run test:db` | Pruebas pgTAP de permisos, horario y reservas |
| `npm run test:concurrency` | Dos reservas a la vez por la última plaza (dos conexiones reales) |
| `npm run db:reset` | Rehace la base desde las migraciones y el seed |
| `npm run db:stop` | Para los contenedores |

## Pantallas

| Ruta | Pantalla | Diseño |
| --- | --- | --- |
| `/` | Hoy (alumno) | 01 |
| `/horario` | Horario con reservas y lista de espera | 02 |
| `/clase/:id` | Detalle de clase, check-in, cancelar | 03 |
| `/staff` | Pasar lista (profesor), funciona sin conexión | 04 |
| `/progreso` | Cinturón, criterios de grado, asistencia | 05 |
| `/tarifas` | Tarifas y suscripción a ITACA+ | 06 |
| `/reservas` | Mis reservas | — |
| `/staff/kiosco` | Modo kiosco: QR de check-in y quién ha fichado | — |
| `/staff/cobros` | Cobros por tarifa y método, impagos | 07 |
| `/itaca` | ITACA+: buscador, seguir viendo, currículos | 08 |
| `/itaca/video/:id` | Vídeo y currículo | 09 |
| `/staff/monitores` | Monitores | 10 |
| `/staff/monitores/:id` | Ficha de monitor, currículo, sustituto, exportar horas | 11 |
| `/perfil`, `/instalar`, `/staff/alumnos`, `/staff/horario`, `/staff/mas` | Pantallas de apoyo | — |

La vista del personal se abre desde **Perfil → Abrir vista del personal** mientras no haya inicio de sesión.

## Estructura

```text
docs/
  SPEC.md            plan completo (especificación)
  PROGRESS.md        qué está hecho y qué falta
  DECISIONS.md       decisiones tomadas y por qué
  diseno/            maquetas HTML y PNG de las 11 pantallas
src/
  app: App.tsx       rutas por rol
  components/        UI base (botones, tarjetas, chips, hojas), iconos, layouts
  features/          student, staff, itaca
  lib/
    logic.ts         reglas de negocio puras (reservar, cancelar, check-in…)
    logic.test.ts    pruebas de esas reglas
    store.tsx        estado de la app (se sustituirá por Supabase)
    data.ts          datos de ejemplo
  styles/tokens.css  colores, tipografía y modo oscuro
public/              iconos de la app y fuentes
```

El color de acento es `--accent` en [src/styles/tokens.css](src/styles/tokens.css): cambiarlo ahí lo cambia en toda la app.

## Licencias

Fuentes Barlow Condensed e Inter con licencia SIL Open Font License (ver `public/fonts/`). Nombres, clases, importes y cifras son datos de ejemplo; `[NOMBRE]` y `[PRECIO]` marcan lo que falta por decidir.
