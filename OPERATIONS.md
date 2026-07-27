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

El 27 de julio de 2026 se compararon las 22 migraciones remotas del proyecto
`dpcdpcvjcutcqyqcacti` con los archivos locales. El nombre lógico, el tamaño en
bytes y la huella MD5 del SQL normalizado coinciden exactamente en los 22 casos.

Los archivos locales usan desde entonces las mismas versiones temporales
registradas en producción (`20260712124546…20260712124745`). Este cambio solo
reconcilia el historial: no modifica el SQL, el esquema ni los datos.

Antes de ejecutar `supabase db push`:

1. Confirmar con `supabase migration list` que las 22 versiones coinciden en
   local y remoto.
2. Comprobar que solo aparecen como pendientes las migraciones nuevas.
3. Ejecutar primero `supabase db push --dry-run`.
4. Detener la operación si una migración histórica aparece como pendiente.
