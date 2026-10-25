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
flutter build web --release \
  --dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY:-}" \
  --dart-define=FIREBASE_APP_ID="${FIREBASE_APP_ID:-}" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-}" \
  --dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}" \
  --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define=FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-}"

echo "==> Installing server dependencies"
(cd server && npm ci --omit=dev || npm install --omit=dev)
