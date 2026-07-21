# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Fud AI, please report it **privately** so it can be addressed before public disclosure.

**Preferred:** Use GitHub's [private vulnerability reporting](https://github.com/apoorvdarshan/fud-ai/security/advisories/new) — it's end-to-end private and routes directly to the maintainer.

**Alternative:** Email either of:

- **apoorv@fud-ai.app**
- **ad13dtu@gmail.com**

Please include:

- A description of the vulnerability
- Steps to reproduce (a minimal PoC is ideal)
- Affected platform + version (iOS — check **Settings → About**, or `MARKETING_VERSION` in `ios/calorietracker.xcodeproj/project.pbxproj`; Android — check About screen, or `versionName` in `android/app/build.gradle.kts`)
- Any potential impact — data exposure, API-key leakage, code execution, etc.
- Your name / handle if you want credit in the release notes (optional)

You can expect an initial acknowledgement within **7 days**, and a more detailed response (triage + estimated fix timeline) within **14 days**. Please do not disclose the issue publicly until a fix has shipped to the App Store and Play Store.

## Supported Versions

Only the latest released version on each store (App Store for iOS, Play Store for Android) is supported with security updates. The repository's `main` branch tracks the next release for both clients.

## Scope

**In scope (iOS):**

- The iOS app source in `ios/` (SwiftUI app, Share extension, widgets, Watch app, and test targets)
- API-key handling and iOS Keychain storage (`KeychainHelper`, `AIProviderSettings`, `SpeechSettings`)
- Network requests to AI and speech-to-text providers (`GeminiService`, `ChatService`, `SpeechService`), including multi-image food analysis and expanded nutrient payloads
- Siri/App Intent logging (`AppIntents`, `SiriLoggingService`), including automatic food/weight logging and HealthKit writes triggered from Siri
- Barcode lookup behavior against Open Food Facts, including the "missing product / missing nutrition" fallback path
- HealthKit read/write paths (`HealthKitManager`) and UUID-tagged nutrition, body-measurement, and calculated-workout-burn samples
- Widget App Group container (`group.com.apoorvdarshan.calorietracker`) and the calorie, nutrient, and optional water snapshot written into it
- Local persistence layer (`UserDefaults`, Keychain) including Coach history and food/weight/body-fat/water/workout logs
- User-initiated diary exports and shared-meal URL payload handling in the app and `web/add-meal.html`

**In scope (Android):**

- The Android app source in `android/` (Kotlin + Compose codebase, Glance widget, repositories, services)
- API-key handling via `EncryptedSharedPreferences` (AES-256, AndroidKeystore-backed) in `data/KeyStore.kt` — including the AEAD recovery path that wipes a corrupted master-key alias on reinstall
- Network requests to AI and speech-to-text providers (`services/ai/*`, `services/speech/*`), including multi-image food analysis, Coach image attachments, and expanded nutrient payloads
- Barcode lookup behavior against Open Food Facts, including the "missing product / missing nutrition" fallback path
- Health Connect read/write (`services/health/HealthConnectManager.kt`) and the `fudai_<uuid>` `clientRecordId` convention used for dedup + safe deletion, including calculated workout calories
- Glance widget snapshot (`models/WidgetSnapshot.kt`) shared via the app's DataStore for Calorie, Protein, Today, and Water widgets, plus `ImageProvider(bitmap)` rendering and local thumbnail caching
- Local persistence (DataStore Preferences for food, body, water, workout, Coach, and settings data; EncryptedSharedPreferences for keys; no Room/cloud)
- User-initiated diary exports and shared-meal URL payload handling
- Release signing material handling — `keystore.properties` and `*.jks` are gitignored; ProGuard/R8 keep rules in `app/proguard-rules.pro` (relevant if a missing keep introduces a release-only crash that has security implications)

**In scope (web):**

- The marketing site source in `web/` (static HTML/CSS, no JS framework, no backend)
- Privacy policy + terms pages (`web/privacy.html`, `web/terms.html`) — accuracy of disclosures

**Out of scope:**

- Vulnerabilities in third-party AI providers (report to them directly — OpenAI, Anthropic, Google, xAI, etc.)
- Vulnerabilities in third-party speech-to-text providers (report to them — Deepgram, AssemblyAI, etc.)
- Incorrect or incomplete Open Food Facts product data. Fud AI can only show the nutrition available from that public database; missing products are product-data issues, not security issues
- Vulnerabilities in OS-level components (iOS HealthKit, Android Health Connect, Glance, WorkManager, Compose) — report to Apple / Google
- Issues requiring physical device access with the device unlocked
- Social-engineering attacks against users' own API keys
- Denial-of-service against the user's own AI provider via API quota exhaustion (that's a user-controlled cost, not a security boundary)

## Safe Harbor

If you make a good-faith effort to comply with this policy during security research, we will not pursue or support any legal action related to your research. Please don't access or modify user data, avoid service disruption, and give us reasonable time to fix issues before disclosure.

## Credit

Researchers who responsibly disclose valid vulnerabilities will be credited in the release notes and in the commit message that ships the fix (unless they request to remain anonymous).
