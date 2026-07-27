#!/usr/bin/env bash
set -euo pipefail

readonly BASE_URL="https://itc2-reservas.vercel.app"

check_flutter_route() {
  local path="$1"
  local body

  body="$(
    curl \
      --fail \
      --silent \
      --show-error \
      --max-time 20 \
      --proto '=https' \
      "${BASE_URL}${path}"
  )"

  if ! grep --fixed-strings --quiet 'flutter_bootstrap.js' <<<"${body}"; then
    echo "La ruta ${path} no devolvió el arranque web de Flutter." >&2
    return 1
  fi

  echo "OK ${BASE_URL}${path}"
}

check_flutter_route "/"
check_flutter_route "/olvide-contrasena"
check_flutter_route "/privacidad"
