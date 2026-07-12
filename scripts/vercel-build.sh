#!/usr/bin/env bash
set -euo pipefail

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"

FLUTTER_VERSION="3.44.6"
FLUTTER_HOME="${TMPDIR:-/tmp}/flutter-${FLUTTER_VERSION}"

if [[ ! -x "${FLUTTER_HOME}/bin/flutter" ]]; then
  archive="${TMPDIR:-/tmp}/flutter.tar.xz"
  curl --fail --silent --show-error --location \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    --output "${archive}"
  mkdir -p "${FLUTTER_HOME}"
  tar --extract --xz --file "${archive}" --directory "${FLUTTER_HOME}" --strip-components=1
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"
flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}" \
  --dart-define="STRIPE_PUBLISHABLE_KEY=${STRIPE_PUBLISHABLE_KEY:-}" \
  --dart-define="SENTRY_DSN=${SENTRY_DSN:-}" \
  --dart-define="APP_ENV=${APP_ENV:-preview}" \
  --dart-define="PUSH_ENABLED=${PUSH_ENABLED:-false}"
