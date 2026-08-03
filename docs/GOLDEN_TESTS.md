# Golden Tests (Pruebas Visuales)

## Estado Actual (2026-08-03)

Los golden tests están **excluidos de CI** temporalmente por problemas de infraestructura de testing visual. Esto **no afecta a la funcionalidad** de la app.

| Test | Status | Problema | Prioridad |
|------|--------|---------|-----------|
| calendario_golden_test | ❌ Falla en CI | Renderizado diferente en CI vs local | 🟡 Media |
| estadisticas_golden_test | ❌ Falla en CI | Renderizado diferente en CI vs local | 🟡 Media |
| tarifas_golden_test | ❌ Falla en CI | Renderizado diferente en CI vs local | 🟡 Media |
| academia_golden_test | ⚠️ Sin datos | Necesita revisar | 🟡 Media |
| componentes_golden_test | ⚠️ Sin datos | Necesita revisar | 🟡 Media |
| invitar_golden_test | ⚠️ Sin datos | Necesita revisar | 🟡 Media |
| shell_golden_test | ⚠️ Sin datos | Necesita revisar | 🟡 Media |

## Cómo Ejecutar Localmente

```bash
# Solo golden tests
flutter test --tags=golden

# Todos excepto golden (lo que corre CI)
flutter test --tags='!golden'

# Un golden test específico
flutter test test/golden/calendario_golden_test.dart
```

## Cuándo Actualizar Golden Baselines

Si has cambiado la UI intencionalmente y necesitas actualizar las imágenes base:

```bash
flutter test --tags=golden --update-goldens
# Luego: git add test/golden/ && git commit
```

## Cuándo Arreglará CI

Los golden tests necesitan:
1. ✅ Tipografías correctas (ya incrustadas)
2. ⚠️ Renderizado consistente entre CI y local (problema aún sin resolver)
3. ⚠️ Resolución/DPI controlada en CI (issue de infraestructura)

**Próximas acciones:**
- Documentar las diferencias exactas encontradas
- Revisar si es un issue de Flutter/SkiaGold o de nuestro setup
- Considerar usar mock images en lugar de golden si es necesario

## Referencias

- Documentación Flutter: https://flutter.dev/docs/testing/visual-testing
- Issue tracking: Ver tareas pendientes en GitHub
