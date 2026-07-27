# Decisiones técnicas

## 2026-07-23 — Permisos explícitos para funciones Supabase

Las funciones del esquema `public` se consideran API remota porque PostgREST
puede exponerlas como RPC. Por tanto:

- `PUBLIC`, `anon` y `authenticated` no reciben `EXECUTE` por defecto.
- Cada migración debe conceder explícitamente las RPC que necesite Flutter.
- Las funciones internas, de trigger, cron o mantenimiento quedan accesibles
  solo para su propietario y `service_role`.
- Las funciones fijan `search_path`; no dependen del valor de la sesión.
- Las funciones `SECURITY DEFINER` deben validar identidad y rol cuando sean
  RPC públicas. Los avisos restantes del Security Advisor se revisan como
  excepciones explícitas, no se ignoran globalmente.

Motivo: reducir la superficie RPC, evitar que helpers internos se conviertan
en endpoints y mantener los permisos reproducibles entre entornos Supabase.

## 2026-07-27 — Bootstrap del Administrador inicial fuera del registro público

El primer Administrador se crea a partir de un usuario de Auth con correo
confirmado mediante `bootstrap_initial_admin`. La función:

- solo es ejecutable por `service_role` y por el propietario de la base;
- usa un bloqueo transaccional para impedir carreras;
- solo funciona mientras no exista ningún Administrador;
- no convierte perfiles ya existentes ni acepta usuarios anónimos;
- nunca se invoca desde Flutter ni depende de metadata controlada por cliente.

Motivo: el alta pública debe limitarse a Dueños y Alumnos. Un secreto de
bootstrap en el cliente permitiría autoascensos y no puede protegerse en una
aplicación web o móvil.

## 2026-07-27 — Observabilidad con minimización de datos

La capa de errores de Flutter continúa centralizada en `Observability` y solo
se activa cuando el despliegue aporta un `SENTRY_DSN`.

- `sendDefaultPii`, las capturas de pantalla, la jerarquía visual y la captura
  automática de peticiones fallidas permanecen desactivadas.
- El usuario se identifica únicamente por su UUID interno, sin nombre ni
  correo.
- La versión reportada es el commit del despliegue.
- En producción se muestrea el 5 % de las trazas; los errores siguen
  capturándose.
- Sin Sentry, los errores controlados solo muestran tipo y contexto en modo
  debug; no se imprime su contenido en builds de producción.

La disponibilidad web se vigila con una prueba sintética de solo lectura sobre
el dominio canónico y las rutas críticas. Web Analytics y Speed Insights no se
activan automáticamente porque su uso y coste requieren una decisión separada.

## 2026-07-27 — Identidad y firma de las aplicaciones móviles

Se conserva `com.itaca.itaca` como identificador candidato de Android e iOS
porque ya forma parte del código nativo y de los deep links. Debe comprobarse
su disponibilidad en Google Play Console y Apple Developer antes de la primera
alta; después del primer binario no se cambia.

Las compilaciones Android de producción nunca usan la clave debug. La firma se
inyecta desde secretos de GitHub y se entrega como Android App Bundle para Play
App Signing. iOS requiere firma administrada por la cuenta Apple y una
distribución posterior desde Xcode o App Store Connect.

La configuración Firebase se inyecta por plataforma durante la compilación y
no se comparte con otros proyectos. El cliente solo habilita push cuando
`PUSH_ENABLED=true`. `send-push` se despliega sin verificación JWT porque lo
invoca un programador, pero falla de forma cerrada si `CRON_SECRET` no existe o
no coincide.
