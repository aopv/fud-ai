#!/bin/sh

set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIRECTORY/../.." && pwd)
FLUTTER_PROJECT="$REPOSITORY_ROOT/flutter_shared"

if [ -n "${FUD_AI_FLUTTER_BIN:-}" ]; then
    FLUTTER_EXECUTABLE="$FUD_AI_FLUTTER_BIN"
else
    FLUTTER_EXECUTABLE=$(command -v flutter || true)
fi

if [ -z "$FLUTTER_EXECUTABLE" ] || [ ! -x "$FLUTTER_EXECUTABLE" ]; then
    echo "error: Flutter 3.47.1 was not found. Set FUD_AI_FLUTTER_BIN to its executable." >&2
    exit 1
fi

cd "$FLUTTER_PROJECT"
"$FLUTTER_EXECUTABLE" pub get
"$FLUTTER_EXECUTABLE" build swift-package --platform ios --no-codesign
