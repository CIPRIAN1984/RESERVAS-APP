# Despliegue v1 — Guía Ejecutiva

**Fecha creada:** 2026-08-08  
**Rama:** `claude/app-setup-github-nohews` (commit `4fda3ff`)  
**Responsable:** Cipri (ejecución), Claude (coordinación)

---

## ⚠️ CRÍTICO: Pre-despliegue en máquina local

Antes de tocar nada en producción, ejecuta **en tu máquina** (no en remoto):

### 1. Verificar migración

```bash
cd ~/RESERVAS-APP
git fetch origin
git checkout claude/app-setup-github-nohews
git pull

# Iniciar stack local
supabase start

# Esperar 30s, luego:
supabase migration list --local
# Debe mostrar 31 migraciones locales

supabase test db
# TODOS los tests pgTAP deben pasar (13 suites)
```

**Si falla migration list o tests:** detener, NO continuar. Reportar errores exactos.

### 2. Verificar Flutter CI localmente

```bash
flutter pub get
flutter analyze
flutter test
# Sin avisos ni errores

# Regenerar codegen (si toca modelos o providers):
dart run build_runner build --delete-conflicting-outputs
```

**Si falla:** detener. El build debe estar limpio.

### 3. Verificar formato

```bash
dart format lib supabase/functions --set-exit-if-changed
# Debe terminar con exit 0 (sin cambios pendientes)
```

---

## 📦 Fase 1: Supabase (Producción)

### Paso 1a: Dry-run de migraciones

```bash
supabase migration list --linked
# Debe mostrar exactamente 22 versiones (julio 27, reconciliadas)
# Si aparece alguna de las 9 nuevas como "pending", está bien — son nuevas.

supabase db push --dry-run
# Revisar que SOLO aparecen las 9 nuevas como pendientes:
# - 20260803090000_bloquear_reserva_sin_clases.sql
# - 20260803100000_familias_tutores.sql
# - (7 más desde familias merged en julio)
```

**Detener si alguna migración HISTÓRICA (julio o antes) aparece como pending.**

### Paso 1b: Ejecutar migraciones

```bash
supabase db push
# Esperar a que complete (2-3 min típico)
```

**Verificar en Supabase Console:**
- [ ] `supabase/migrations/` muestra todas las 31 fechas
- [ ] Ningún error en logs

### Paso 1c: Ejecutar Advisors (Security + Performance)

En Supabase Console (`dpcdpcvjcutcqyqcacti`):
1. SQL Editor → "Advisors" (arriba a la derecha)
2. Hacer clic en "Security Advisor" y "Performance Advisor"
3. Revisar avisos:
   - Si aparecen `SECURITY DEFINER` en funciones: confirmar que corresponden a RPCs públicas con validación interna
   - Ignorar avisos de `rls` (RLS está activado a propósito)
4. Si hay avisos críticos nuevos: **PARAR y reportar**

---

## 🌐 Fase 2: Vercel (Frontend)

### Paso 2a: Crear PR a `main` (si no existe)

```bash
# Si estás en claude/app-setup-github-nohews:
git push origin claude/app-setup-github-nohews

# Abrir GitHub → crear PR a rama `main`
# Título: "v1 Pre-lanzamiento: congelación de features y hardening"
# 
# Body:
# ## Summary
# - 11-step pre-launch plan complete
# - 6 features safely frozen (Familias, Stripe, Tienda, Multi-academia, Transfer, Member mgmt)
# - ITACA hardcoded as single academy for v1
# - Deployment checklist prepared in DECISIONS.md
# 
# ## Test Plan
# - [x] CI: formato, análisis, pgTAP (13 suites), tests Flutter
# - [x] Supabase: migraciones sincronizadas (31 totales)
# - [x] Flutter: sin avisos, build limpio
# - [ ] Vercel: deploy y smoke test
# - [ ] Admin bootstrap completado
```

### Paso 2b: Esperar a que CI pase

En GitHub:
- Vercel build: debe ser `READY` (estado verde)
- GitHub Actions: todos en verde (flutter, supabase, security-scan)

Si alguno falla: **PARAR, revisar logs, reportar error exacto.**

### Paso 2c: Hacer merge a `main`

```bash
# En GitHub, hacer merge (Squash o regular, sin importa)
# Vercel desplegará automáticamente en 2-3 min

# Esperar a que despliegue y confirmar estado = READY
```

---

## ✅ Fase 3: Post-despliegue (primeras 24h)

### Paso 3a: Verificar disponibilidad

```bash
# En navegador o curl:
curl -I https://itc2-reservas.vercel.app/
# Status: 200

curl -I https://itc2-reservas.vercel.app/olvide-contrasena
# Status: 200

curl -I https://itc2-reservas.vercel.app/privacidad
# Status: 200
```

### Paso 3b: Revisar logs (primera hora)

**Vercel:** 
- Deploy log: sin errores (copilot → deployments → itc2-reservas)
- Runtime logs: abrir app en navegador, revisar console

**Supabase Console:**
- Database → Logs: revisar últimas transacciones
- Edge Functions → Logs: si hay función ejecutándose, revisar

**Sentry (si está configurado):**
- Nuevo release debe coincidir con commit `4fda3ff`

### Paso 3c: Bootstrap del Administrador (PROCESO ÚNICO)

Este paso **solo se ejecuta UNA VEZ** la primera vez y **SOLO si no existe ya un perfil con rol='administrador'**.

1. En Supabase Console → Auth → crear usuario:
   - Email: `[tu-email-admin]` (ejemplo: `cipri@itaca.local`)
   - Contraseña: aleatoria, luego confirmada
   - **NO marcar "Auto confirm email"** — irá por flujo de confirmación real
   - **NO** reutilizar una cuenta de Alumno o Dueño

2. Confirmar el email:
   - Buscar en inbox el mail de confirmación de Auth
   - Hacer clic en "Confirm Email"

3. Copiar UUID del usuario:
   - Auth → Users → buscar el usuario nuevo
   - Copiar `UID` (UUID largo de 36 caracteres)

4. Ejecutar bootstrap (copiar y pegar exactamente):

   **En Supabase Console → SQL Editor:**
   ```sql
   select public.bootstrap_initial_admin(
     '[PEGA_AQUI_EL_UUID]'::uuid,
     'Cipri',
     null
   );
   ```

   Ejemplo real:
   ```sql
   select public.bootstrap_initial_admin(
     '550e8400-e29b-41d4-a716-446655440000'::uuid,
     'Cipri',
     null
   );
   ```

5. Verificar resultado:
   ```sql
   select id, rol, estado, academia_id
   from public.profiles
   where rol = 'administrador';
   ```
   Debe mostrar exactamente 1 fila con `rol='administrador'`, `estado='activo'`, `academia_id=NULL`.

6. **IMPORTANTE:** La función rechaza:
   - Usuarios sin email confirmado
   - Perfiles existentes
   - Cualquier intento posterior (idempotencia: si ejecutas 2 veces, la segunda falla)

### Paso 3d: Probar acceso Admin

1. Abrir navegador: `https://itc2-reservas.vercel.app/#/login`
2. Login con `[tu-email-admin]` + contraseña
3. Debe mostrar: **Panel de Academias**
4. Verificar:
   - [ ] Puede ver ITACA en la lista
   - [ ] Puede acceder al panel de la academia
   - [ ] Puede ver la sección de "Cambios de escuela" (aunque esté vacía)

---

## 🚨 Si algo falla

| Fase | Error | Acción |
|---|---|---|
| Migraciones | Migración histórica aparece como "pending" | STOP inmediatamente. Contactar soporte Supabase. |
| pgTAP tests | Un test falla | STOP. Revisar logs exactos, reportar. |
| Vercel CI | Build falla | STOP. Revisar logs de GitHub Actions. |
| Vercel deploy | Status ≠ READY | Revisar runtime logs. Si es error persistente, revertir merge. |
| Admin bootstrap | Función rechaza | Verificar: UUID correcto, email confirmado, sin perfil previo. |

---

## 📋 Checklist de Finalización

- [ ] **Pre-despliegue:** CI verde, tests locales pasan, formato limpio
- [ ] **Migraciones:** Supabase muestra 31 versiones, dry-run solo ve nuevas
- [ ] **Advisors:** Revisados, sin avisos críticos nuevos
- [ ] **Vercel:** PR a `main` abierta, CI pasa, merge hecho, deploy READY
- [ ] **Smoke tests:** GET / , /olvide-contrasena, /privacidad → 200 OK
- [ ] **Admin bootstrap:** Ejecutado, perfil verificado, login funciona
- [ ] **Logs:** Vercel + Supabase revisados, sin errores nuevos en 1h
- [ ] **Documentación:** PRODUCT.md actualizado con fecha v1 y versión

---

## ℹ️ Referencias

- **DECISIONS.md:** Todas las decisiones técnicas y paso 10 (este despliegue)
- **OPERATIONS.md:** Procedimientos de despliegue, incidentes, recuperación
- **FREEZE.md:** Qué está congelado y por qué
- **CLAUDE.md:** Arquitectura y cómo trabajar en el proyecto

---

**Última revisión:** 2026-08-08 · Rama: `4fda3ff` · Estado: Listo para despliegue
