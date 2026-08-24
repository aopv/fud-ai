# Fud AI shared presentation

This Flutter module is embedded in the existing native apps without moving
durable data or platform capabilities out of Swift/Kotlin. Android uses the
shared neo-brutalist shell for Home, Progress, Coach, Settings, Workouts, and
the themed right-side navigation rail. iOS currently uses the shared Progress renderer
inside its native SwiftUI shell.

Flutter receives serializable display snapshots over
`com.apoorvdarshan.fudai/app` and `com.apoorvdarshan.fudai/progress`. Actions
return to the existing Swift/Kotlin repositories and narrowly targeted native
capability screens for camera, voice, health permissions, file import/export,
and other OS-owned flows. The module never writes preferences, files, health
data, or backend state itself.

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
DataStore, repositories, Health Connect, camera/media integrations, and all
existing user data. Native capability sheets use the same v7 visual tokens.

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
