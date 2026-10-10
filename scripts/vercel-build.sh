#!/usr/bin/env bash
# Builds the Flutter web app on Vercel, whose build image has no Flutter SDK.
# Keep FLUTTER_VERSION in step with the version the app is developed on.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.41.9}"
FLUTTER_DIR="${HOME}/flutter-sdk"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"
# Vercel builds run as root and Flutter checks the SDK is a "safe" git directory.
git config --global --add safe.directory "${FLUTTER_DIR}" || true

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
flutter pub get
flutter build web --release
