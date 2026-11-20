#!/usr/bin/env bash
# Pruebas de base de datos (pgTAP) sobre una base LIMPIA, como hace el CI.
# Las suites cuentan filas (p. ej. academias aprobadas), así que los datos de
# prueba sembrados con scripts/sembrar_prueba.py las alteran. Esto reinicia la
# base local (SOLO la local de Docker, nunca un proyecto alojado), pasa las
# pruebas y avisa de que hay que volver a sembrar.
set -euo pipefail
cd "$(dirname "$0")/.."
npx -y supabase@latest db reset
npx -y supabase@latest test db
echo "Base local limpia. Para volver a los datos ficticios: python3 scripts/sembrar_prueba.py"
