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

## 6. Verify

```bash
flutter analyze                 # clean
flutter test                    # all green
flutter build apk --debug --dart-define=GEMINI_API_KEY=<key>
flutter run --dart-define=GEMINI_API_KEY=<key>
```

## Still deferred to v3

Health logs (meals / workouts / sleep / steps / pantry / suggestion history)
remain in local SQLite. Only the user profile + goals sync to Firestore.
Full cloud sync of the logs is a v3 decision.
