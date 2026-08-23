# Fud AI shared presentation

This Flutter module is embedded in the existing native apps one screen at a
time. iOS remains the production shell: SwiftUI owns the iOS 26 Liquid Glass
navigation, HealthKit, widgets, Watch integration, App Intents, camera flows,
and every persisted store.

The first migrated surface is **Progress**. Flutter receives a serializable
display snapshot over `com.apoorvdarshan.fudai/progress`. Log, history, and
delete actions return to the existing SwiftUI sheets and store methods. The
module never writes `UserDefaults`, files, HealthKit, or backend state itself.

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

## Verify

```sh
cd flutter_shared
flutter analyze
flutter test
```

For a native-only comparison build, launch the iOS app with
`--native-progress`. This keeps the previous SwiftUI Progress implementation as
a rollback/parity reference while migration continues.
