# Fud AI shared presentation

This Flutter module is embedded in the existing native apps one screen at a
time. SwiftUI and Compose remain the production shells: they own native
navigation, health integrations, widgets, camera flows, and every persisted
store.

The first migrated surface is **Progress**. Flutter receives a serializable
display snapshot over `com.apoorvdarshan.fudai/progress`. Log, history, and
delete actions return to the existing SwiftUI or Compose sheets and repository
methods. The module never writes preferences, files, health data, or backend
state itself.

## Prepare the iOS package

The generated Swift package is a build artifact and is not committed. Before
opening or building the iOS project from a clean checkout, run:

```sh
FUD_AI_FLUTTER_BIN=/absolute/path/to/flutter \
  ./ios/scripts/prepare_flutter_package.sh
```

The Xcode scheme selects the matching Debug/Profile/Release artifacts and the
app target's `Assemble Flutter` phase embeds and signs them. Xcode Cloud runs
the same preparation automatically from `ci_scripts/ci_post_clone.sh`.

## Prepare the Android AAR

The Android AAR repository is also generated and ignored. Before building the
native Android app from a clean checkout, run:

```sh
FUD_AI_FLUTTER_BIN=/absolute/path/to/flutter \
  ./android/scripts/prepare_flutter_aar.sh
```

The Android app resolves the generated Debug or Release AAR while retaining
its Compose shell, native bottom navigation, DataStore, repositories, and
Health Connect behavior.

## Verify

```sh
cd flutter_shared
flutter analyze
flutter test
```

For a native-only comparison build, launch iOS with `--native-progress` or
Android with the `native_progress` intent extra. This keeps the previous native
Progress implementation as a rollback/parity reference while migration
continues.
