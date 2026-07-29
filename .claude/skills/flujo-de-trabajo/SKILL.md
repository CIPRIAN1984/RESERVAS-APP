---
name: flujo-de-trabajo
description: Cómo trabajar en RESERVAS-APP de principio a fin — ramas, pull requests, migraciones de base de datos y despliegue. Úsala al empezar cualquier cambio y antes de fusionar.
---

# Flujo de trabajo — RESERVAS-APP

```
rama al día → cambios → verificar → PR en borrador → CI en verde → Cipri prueba → fusionar
```

Cipri **no es desarrollador**: él aprueba y prueba; lo técnico lo decides tú.

---

## 1. Empezar siempre desde la rama base actualizada

La rama por defecto del repositorio es **`claude/app-setup-github-nohews`** (nombre heredado; es la "main" real).

```bash
git fetch origin claude/app-setup-github-nohews
git checkout -B <rama-nueva> origin/claude/app-setup-github-nohews
```

⚠️ Los PR se fusionan con **squash**: el commit de tu rama desaparece y aparece otro nuevo con el mismo contenido. Si sigues trabajando sobre una rama vieja, git ve dos commits distintos con los mismos cambios y **provoca conflictos**. Rama nueva desde la base actualizada, siempre.

---

## 2. Un cambio, una rama, un PR

Nombra las ramas por lo que hacen: `claude/diseno-tema-claro`, `claude/familias-tutores`.

**Commits:** en castellano, explicando **por qué**, no solo qué. Si corriges algo, di qué fallaba.

---

## 3. Antes de commitear

```bash
export PATH=/opt/flutter/bin:$PATH
flutter analyze && flutter test
```

Y si tocaste modelos o providers, regenera el codegen y commitea el resultado (el CI falla si se desvía).

Para cambios visuales, además: **captura de pantalla** (skill `verificar-app`).

---

## 4. Migraciones de base de datos

- Van en `supabase/migrations/`, numeradas en orden. **Nunca edites una migración ya aplicada**: crea una nueva.
- Toda migración que toque permisos necesita su prueba pgTAP en `supabase/tests/`.
- **Ojo con los permisos de columna:** un `revoke update (columna)` no hace nada si el rol ya tiene `UPDATE` de tabla completa. Hay que revocar la tabla y volver a conceder solo las columnas permitidas. (Se descubrió en vivo: un dueño pudo activarse los cobros de Stripe él solo.)
- **Nunca ejecutes `supabase db push` contra producción** sin decírselo a Cipri antes y explicarle qué cambia.

---

## 5. Pull request

- Créalo **en borrador**.
- Cuerpo: objetivo, cambios, cómo se validó, y qué queda fuera de alcance.
- Espera a que el CI esté en verde (formato, análisis, codegen, tests, build web, pgTAP, secretos).
- **No fusiones sin que Cipri lo apruebe** si el cambio se ve o toca dinero.

Cada PR genera una **vista previa en Vercel**: pásale el enlace a Cipri para que lo mire desde el móvil.

---

## 6. Qué NO se hace nunca sin permiso explícito

- Conectar Stripe real o tocar claves de producción.
- Ejecutar migraciones contra la base de datos de producción.
- Publicar en Google Play o App Store.
- Mezclar nada con el repositorio `itacaplus`.
- Borrar o reescribir datos de alumnos.

---

## 7. Si algo se rompe

1. Di **qué** se rompió y **qué consecuencia** tiene, sin maquillar.
2. Si está en producción, prioriza revertir sobre arreglar (`git revert`, o volver al despliegue anterior en Vercel).
3. Anota la causa en `DECISIONS.md` para no repetirla.
