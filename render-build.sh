#!/usr/bin/env bash
# Render build: installs Flutter, builds the web app, installs the Node server.
set -euo pipefail

FLUTTER_DIR="${HOME}/.cache/flutter-sdk"
if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "==> Installing Flutter (stable)"
  rm -rf "${FLUTTER_DIR}"
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
flutter precache --web
flutter pub get

echo "==> Building Flutter web"
flutter build web --release

echo "==> Installing server dependencies"
(cd server && npm ci --omit=dev || npm install --omit=dev)
