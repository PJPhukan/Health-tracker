# Stock Plate — v2 manual setup

The app **builds and runs today with no setup** — with no Firebase config it
starts in *local-only mode* (no accounts, profile + goals stored only on the
device) and every v1 feature works. Do the steps below to turn on accounts,
cloud-synced goals, and auto step tracking.

---

## 1. Firebase project

1. **Create the project** at <https://console.firebase.google.com> → *Add
   project* (suggested id: `stock-plate`).
2. **Register the apps**
   - Android package name: `com.example.health_tracker`
   - iOS bundle id: `com.example.healthTracker` (whatever `PRODUCT_BUNDLE_IDENTIFIER`
     resolves to in Xcode — check `ios/Runner.xcodeproj`)
3. **Run FlutterFire** from the project root:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=stock-plate
   ```
   This **overwrites `lib/firebase_options.dart`** with real values and drops:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

   Once `firebase_options.dart` no longer contains `REPLACE_ME`, the app leaves
   local-only mode automatically.
4. Commit `firebase_options.dart`. Decide per your team whether to commit
   `google-services.json` / `GoogleService-Info.plist` (they are not secrets but
   some teams keep them out of the repo).

## 2. Enable Auth providers

Firebase console → **Authentication → Sign-in method**, enable:

- [ ] **Email/Password**
- [ ] **Google**
  - Set a support email.
  - **Android:** add your signing SHA-1 **and** SHA-256 (console → Project
    settings → your Android app → *Add fingerprint*).
    - Debug: `cd android && ./gradlew signingReport` → copy the `debug` SHA-1/256.
    - Release: the SHA of your upload/play-signing key.
  - Re-download `google-services.json` after adding fingerprints.
  - **iOS:** add the reversed client id from `GoogleService-Info.plist`
    (`REVERSED_CLIENT_ID`) as a URL scheme in Xcode → Runner → Info → URL Types.

## 3. Firestore

- Firebase console → **Firestore Database → Create database** (production mode,
  pick a region).
- **Rules** — the app only reads/writes the signed-in user's own document:
  ```
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      match /users/{uid} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
  ```
- Data shape: `users/{uid}` holds the profile fields plus a nested `goals` map.
  No indexes needed.

## 4. Health / step tracking

### Android — Health Connect
- `minSdk` is already 26 (`android/app/build.gradle.kts`).
- Manifest is already wired (`READ_STEPS`, `ACTIVITY_RECOGNITION`, the
  `ACTION_SHOW_PERMISSIONS_RATIONALE` intent-filter, the
  `ViewPermissionUsageActivity` alias, and the `<queries>` block).
- `MainActivity` already extends `FlutterFragmentActivity` (required by the
  `health` plugin).
- On the device/emulator: install **Health Connect** from the Play Store
  (pre-installed on Android 14+). The app deep-links to it if missing.
- Emulator: Health Connect has no data unless another app writes steps — test
  step auto-sync on a real device, or add data via the Health Connect app's
  developer options. Manual entry is always available as the fallback.
- For a Play Store release you must complete Google's **Health Connect
  declaration form** and privacy-policy review.

### iOS — HealthKit
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the **Runner** target → **Signing & Capabilities → + Capability →
   HealthKit**. This makes Xcode adopt `ios/Runner/Runner.entitlements`
   (already created) and enable HealthKit for your provisioning profile.
3. `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` are
   already in `Info.plist`.
4. HealthKit is not available on the iOS Simulator — test on a device.

## 5. Web / desktop notes

- `web/sqflite_sw.js` + `web/sqlite3.wasm` are committed (regenerate with
  `dart run sqflite_common_ffi_web:setup` if needed).
- The `health` plugin is Android/iOS only — on web the Steps form shows only
  the manual field. Firebase Auth/Firestore work on web once configured.

## 5b. Cloud sync (v3)

All health logs now sync to Firestore under `users/{uid}/<collection>`
(meals, workouts, sleep, weight, steps, pantry_items, meal_favorites,
suggestion_history). SQLite stays the local cache.

- **Redeploy the security rules** — v3 widened them to cover the
  subcollections:
  ```bash
  firebase deploy --only firestore:rules --project stock-plate
  ```
- No indexes are required (each query is a single-collection `get()`).
- The one-time "lift existing local data up" migration runs automatically on
  first v3 launch per signed-in account (guarded by a SharedPreferences flag).

## 6. AdMob (v3, free tier)

Free users see a banner on Home + the Suggestion screen; Premium users see
none. **Everything currently uses Google's SAMPLE / test ids** — the app will
serve test ads as-is. Before release:

1. Create an app at <https://apps.admob.com> for Android and one for iOS.
2. Create a **Banner** ad unit for each.
3. Replace the ids:
   | Where | File | Sample value to replace |
   |---|---|---|
   | Android app id | `android/app/src/main/AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`) | `ca-app-pub-3940256099942544~3347511713` |
   | iOS app id | `ios/Runner/Info.plist` (`GADApplicationIdentifier`) | `ca-app-pub-3940256099942544~1458002511` |
   | Banner unit id | `lib/services/ad_service.dart` (`bannerUnitId`) | `ca-app-pub-3940256099942544/6300978111` |
4. **iOS ATT**: `NSUserTrackingUsageDescription` is already in `Info.plist`.
   For a real release, call the ATT prompt (`app_tracking_transparency`
   package) before requesting ads on iOS 14+, and fill out the AdMob
   privacy/ATT settings + the App Store privacy questionnaire. The
   `SKAdNetworkItems` list in `Info.plist` currently has only Google's id —
   add the full list AdMob publishes.
5. Google Play: complete the Data safety form (ads collect device
   identifiers).

## 7. RevenueCat subscription (v3)

`SubscriptionService` ships with **placeholder API keys**
(`appl_placeholder`, `goog_placeholder` in `lib/services/subscription_service.dart`).
Until they're real, `available` stays false: no purchases, ads keep showing,
and the paywall shows an "unavailable" note. To enable Premium:

1. Create a project at <https://app.revenuecat.com>.
2. Add the **Apple App Store** and **Google Play Store** apps; paste in the
   App Store Connect shared secret / Play service-account JSON.
3. Create a **monthly** subscription product in App Store Connect and Play
   Console, then add it to RevenueCat.
4. Create an entitlement with the exact identifier **`premium`** and attach
   the product to it.
5. Create an **Offering** (the code reads `offerings.current.monthly`) and
   make it current.
6. Replace `_iosApiKey` / `_androidApiKey` in
   `lib/services/subscription_service.dart` with the platform API keys from
   RevenueCat → Project settings → API keys (`appl_…` / `goog_…`).
7. The price shown in-app comes straight from the store product — no code
   change needed.

## 9. Voice meal logging (v4)

Voice logging (`lib/widgets/voice_mic_button.dart`, `speech_to_text`) needs the
microphone — and, on iOS, on-device speech recognition — permission.

- **Android**: `RECORD_AUDIO` is declared in `AndroidManifest.xml`. The plugin
  requests it at runtime on first tap; our own rationale dialog ("Stock Plate
  uses your microphone to let you log meals by voice") shows once beforehand.
- **iOS**: `Info.plist` carries both `NSMicrophoneUsageDescription` *and*
  `NSSpeechRecognitionUsageDescription` — speech_to_text needs both on iOS, or
  the OS silently denies the request without ever showing a system prompt.
  Test on a real device; the Simulator's speech recognizer is unreliable.
- A denied/unavailable recognizer just hides the mic button — manual typing
  always still works, nothing to configure for that fallback.

## 10. Daily reminders (v4)

`lib/services/notification_service.dart` (`flutter_local_notifications`).

- **Android 13+ (API 33+)**: `POST_NOTIFICATIONS` is a runtime permission,
  requested on first app launch (`MainShell` calls
  `NotificationService.requestPermission()` — safe to call repeatedly, it's a
  no-op once the user has answered). Below API 33 no runtime prompt is needed.
- **Android**: core library desugaring is enabled in
  `android/app/build.gradle.kts` (`isCoreLibraryDesugaringEnabled = true` +
  the `desugar_jdk_libs` dependency) — required by this plugin; the debug
  build fails at `checkDebugAarMetadata` without it.
- **iOS**: `DarwinInitializationSettings` requests alert/badge/sound
  permission the same way — no extra Info.plist keys needed beyond what the
  plugin's own setup already covers.
- Reminders use `AndroidScheduleMode.inexactAllowWhileIdle`, so **no**
  `SCHEDULE_EXACT_ALARM` permission is needed — times can drift by a few
  minutes, which is fine for a daily nudge.
- Known scope limit: rescheduling happens on app start, on resume, and once
  at local midnight *while the app is open*. Going several days without
  opening the app means the last-scheduled slate is what fires — true
  indefinite background rescheduling would need `workmanager` or a native
  `AlarmManager` repeat, which is out of scope for v4.

## 11. Verify

```bash
flutter analyze                 # clean
flutter test                    # all green
flutter build apk --debug --dart-define=GEMINI_API_KEY=<key>
flutter run --dart-define=GEMINI_API_KEY=<key>
```

## Placeholder values to replace before going live

| Value | Location | Current (placeholder / test) |
|---|---|---|
| Gemini API key | `--dart-define=GEMINI_API_KEY=…` at build/run | none baked in |
| AdMob Android app id | `android/app/src/main/AndroidManifest.xml` | `ca-app-pub-3940256099942544~3347511713` |
| AdMob iOS app id | `ios/Runner/Info.plist` → `GADApplicationIdentifier` | `ca-app-pub-3940256099942544~1458002511` |
| AdMob banner unit id | `lib/services/ad_service.dart` → `bannerUnitId` | `ca-app-pub-3940256099942544/6300978111` |
| RevenueCat iOS key | `lib/services/subscription_service.dart` → `_iosApiKey` | `appl_placeholder` |
| RevenueCat Android key | `lib/services/subscription_service.dart` → `_androidApiKey` | `goog_placeholder` |
| RevenueCat entitlement id | `lib/services/subscription_service.dart` → `entitlementId` | `premium` (create this in RevenueCat) |
| `SKAdNetworkItems` | `ios/Runner/Info.plist` | only Google's id — add AdMob's full list |
| Firebase config | `lib/firebase_options.dart` + native files | real `stock-plate` values ✓ (already set) |

No new placeholder *values* came out of v4 — voice logging and reminders use
on-device APIs only (no API keys), and the pantry/template features are pure
local+Firestore data.

Also still pending from v1/v2:
- iOS **HealthKit** capability in Xcode (Runner target → Signing & Capabilities).
- AdMob/RevenueCat need real developer + store accounts before either works
  beyond test mode.
- **v4 addition**: Firestore rules already cover `meal_templates` (it's just
  another subcollection under the existing `users/{uid}/{document=**}`
  match) — no rule redeploy needed for this release.

## 12. Splash pre-load + loading skeletons (v4)

The splash screen (`lib/screens/splash_screen.dart`) pre-loads auth
resolution, the local profile bind, and today's health data in parallel with
its ~2.3s logo animation, so `AuthGate`/`MainShell` render with real data on
their very first frame instead of a spinner. It never blocks longer than 5s
total — past that it navigates anyway and lets the destination screen show
its own loading state.

For the rare case something still isn't ready by navigation time, per-widget
skeleton placeholders (`lib/widgets/skeletons.dart`, via the `shimmer`
package) stand in instead of a full-screen spinner: Home's summary tiles +
suggestion preview, Progress's chart cards, and History's day-card list.
No setup needed — `flutter pub get` picks up the new `shimmer` dependency
in `pubspec.yaml`.
