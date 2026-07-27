# Operaciones

## Validación de permisos Supabase

Antes de aplicar una migración de permisos:

1. Ejecutar `supabase start`.
2. Ejecutar `supabase test db`.
3. Ejecutar los Security y Performance Advisors.
4. Confirmar que cada aviso restante de funciones `SECURITY DEFINER`
   corresponde a una RPC pública intencionada con validación interna.
5. Verificar en un entorno no productivo los roles `anon`, `authenticated` y
   `service_role`.

## Estado del historial remoto

El 23 de julio de 2026 se comprobó que el proyecto remoto
`dpcdpcvjcutcqyqcacti` contiene las 22 migraciones funcionales, pero su tabla
de historial usa versiones temporales `20260712124546…20260712124745`, mientras
el repositorio conserva los nombres `0001…0022`.

No ejecutar `supabase db push` contra producción hasta comparar ambos
historiales y reconciliarlos de forma explícita. La reconciliación debe:

- demostrar que el esquema remoto corresponde al resultado de `0001…0022`;
- conservar los datos reales;
- evitar reaplicar migraciones antiguas;
- quedar documentada antes de aplicar migraciones nuevas.

Este bloqueo no afecta a las pruebas locales ni a CI, que reconstruyen la base
desde cero usando los archivos versionados.
