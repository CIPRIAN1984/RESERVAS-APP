# ITACA

App Flutter para la gestión de academias de BJJ: clases y reservas, novedades, progreso técnico por cinturones, tienda con préstamos de material, tarifas con suscripciones y cobros vía Stripe Connect.

## Stack

- **Flutter** (Dart ≥ 3.12) con **Riverpod** (codegen), **go_router** y **freezed**.
- **Supabase**: autenticación, Postgres con RLS (migraciones en `supabase/migrations/`) y Edge Functions en Deno (`supabase/functions/`).
- **Stripe Connect**: cada academia conecta su propia cuenta; los pagos de tienda y suscripciones de tarifas se procesan con Edge Functions + webhook firmado.

## Estructura

```
lib/
  app/            # MaterialApp, router (guards por rol/estado), tema
  core/           # config, auth, cliente Supabase, modelos compartidos
  features/       # un módulo por funcionalidad (data / application / presentation)
    calendario/   # clases y reservas
    novedades/    # tablón de anuncios
    progreso/     # árbol de técnicas por cinturón
    tienda/       # catálogo, pedidos y préstamos
    tarifas/      # tarifas y suscripciones
    pagos/        # onboarding de Stripe Connect
    estadisticas/ # asistencia y ranking
    perfil/       # perfil y cambio de escuela
    onboarding/   # login, registro, aprobación pendiente
    admin/        # gestión de academias (rol administrador)
supabase/
  migrations/     # esquema, RLS y RPCs (0001..0021)
  functions/      # Edge Functions de Stripe (Deno)
```

Roles: `administrador` (plataforma), `dueño`, `profesor` y `alumno`.

## Puesta en marcha

1. Instala [Flutter](https://docs.flutter.dev/get-started/install) (canal stable) y ejecuta `flutter pub get`.
2. Copia la configuración local y rellena tus claves de Supabase/Stripe:

   ```bash
   cp dart_define.example.json dart_define.json
   ```

   `dart_define.json` está en `.gitignore`: nunca subas claves al repositorio.
3. Ejecuta la app:

   ```bash
   flutter run --dart-define-from-file=dart_define.json
   ```

   Si arrancas sin configuración, la app muestra una pantalla explicando qué falta en lugar de romperse.

### Codegen

Los ficheros `*.g.dart` / `*.freezed.dart` están versionados. Tras tocar modelos o providers anotados:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Backend (Supabase)

```bash
supabase link --project-ref <tu-project-ref>
supabase db push              # aplica supabase/migrations/
supabase functions deploy     # despliega las Edge Functions
supabase functions deploy stripe-webhook --no-verify-jwt
```

Las Edge Functions esperan estos secretos (`supabase secrets set`): `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` y, opcionalmente, `STRIPE_ONBOARDING_RETURN_URL` (URL de retorno del onboarding de Stripe; debe redirigir a la app mediante el deep link `itaca://`). Además `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` los inyecta Supabase automáticamente. El webhook de Stripe debe escuchar también eventos de cuentas conectadas (incluido `charge.refunded` para la reposición de stock).

La app registra el esquema de deep link `itaca://` (Android e iOS) para volver limpiamente tras el onboarding de Stripe, la confirmación de email de Supabase o un pago con redirección.

Las altas y bajas de clase pasan por las RPC `reservar_clase` y `cancelar_reserva`: el servidor valida identidad, academia, cuota cobrada y aforo bajo bloqueo. La cancelación de una tarifa usa `stripe-cancel-tarifa-subscription`, que cancela primero en Stripe y después reconcilia Postgres.

### Notificaciones push (FCM)

Están desactivadas por defecto (`PUSH_ENABLED=false`). Para activarlas:

1. Crea un proyecto Firebase y añade los ficheros nativos (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`); no se versionan.
2. Arranca la app con `--dart-define PUSH_ENABLED=true`.
3. En Supabase, define el secreto `FCM_SERVICE_ACCOUNT` (JSON completo de la service account) y `CRON_SECRET`, despliega la función `send-push` con `--no-verify-jwt`, y prográmala (pg_cron + pg_net o un cron externo) para drenar `notificaciones_outbox`.

El backend ya está listo: `device_tokens` guarda los tokens (RPC `registrar_device_token`), los eventos de negocio encolan en `notificaciones_outbox` (p. ej. al publicar una novedad) y `send-push` los entrega por FCM v1, borrando tokens muertos.

## Tests y análisis

```bash
flutter analyze
flutter test
supabase test db
```

Ambos se ejecutan en CI (GitHub Actions) en cada push y pull request.
