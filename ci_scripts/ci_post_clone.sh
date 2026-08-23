#!/bin/sh

# Xcode Cloud starts from a clean checkout, while the generated Flutter Swift
# package is deliberately gitignored. Recreate it before Xcode resolves local
# package dependencies. The app's Assemble Flutter phase signs the embedded
# frameworks with the active archive identity.
set -eu

REPOSITORY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CI_CACHE_ROOT=${CI_DERIVED_DATA_PATH:-/tmp/fud-ai-xcode-cloud}
FLUTTER_ROOT="$CI_CACHE_ROOT/flutter-3.47.1"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
    git clone --depth 1 --branch 3.47.1 https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
fi

"$FLUTTER_ROOT/bin/flutter" --disable-analytics
"$FLUTTER_ROOT/bin/flutter" precache --ios

FUD_AI_FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter" \
    "$REPOSITORY_ROOT/ios/scripts/prepare_flutter_package.sh"
