#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
FLUTTER_MODULE="$REPO_ROOT/flutter_shared"
OUTPUT_DIR="$FLUTTER_MODULE/build/android-repository"
EXPECTED_FLUTTER_REVISION="6655482ec06e547f90abf8ae7590466f4415978d"

if [ -n "${FUD_AI_FLUTTER_BIN:-}" ]; then
    FLUTTER_BIN=$FUD_AI_FLUTTER_BIN
elif command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN=$(command -v flutter)
else
    echo "Flutter was not found. Set FUD_AI_FLUTTER_BIN to the pinned Flutter executable." >&2
    exit 1
fi

if [ ! -x "$FLUTTER_BIN" ]; then
    echo "Flutter is not executable: $FLUTTER_BIN" >&2
    exit 1
fi

FLUTTER_VERSION=$("$FLUTTER_BIN" --version --machine)
FLUTTER_REVISION=$(printf '%s\n' "$FLUTTER_VERSION" \
    | sed -n 's/.*"frameworkRevision": *"\([^"]*\)".*/\1/p')
if [ "$FLUTTER_REVISION" != "$EXPECTED_FLUTTER_REVISION" ]; then
    echo "Flutter revision mismatch. Expected $EXPECTED_FLUTTER_REVISION." >&2
    echo "Use the pinned Flutter 3.47.1 toolchain via FUD_AI_FLUTTER_BIN." >&2
    exit 1
fi

if [ -z "${JAVA_HOME:-}" ] && [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
    export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

cd "$FLUTTER_MODULE"
"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build aar --no-profile --output "$OUTPUT_DIR"
