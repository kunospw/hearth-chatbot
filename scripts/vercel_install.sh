#!/usr/bin/env bash
# Vercel's install step (see vercel.json). Vercel has no Flutter, so this
# fetches the version the app is built with (.metadata) into .flutter/ and gets
# the packages. On your own machine you don't need it: use your Flutter.
set -euo pipefail

FLUTTER_VERSION=3.47.1

if [ ! -x .flutter/bin/flutter ]; then
  git clone --quiet --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git .flutter
fi
export PATH="$PWD/.flutter/bin:$PATH"

flutter config --no-analytics > /dev/null
flutter --version
flutter pub get
