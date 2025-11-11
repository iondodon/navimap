# Deployment

## Build Configuration

**Android:**

- **Min SDK:** 24 (Android 7.0)
- **Target SDK:** 34 (Android 14)
- **Build Command:** `flutter build apk --release` or `flutter build appbundle --release`
- **Signing:** Required for Play Store (create keystore, update `android/key.properties`)
- **Permissions:** Location (fine/coarse), Internet

**iOS:**

- **Min Deployment Target:** 12.0
- **Build Command:** `flutter build ios --release`
- **Signing:** Requires Apple Developer account, provisioning profile, certificate
- **Permissions:** Location When In Use (Info.plist)

## Store Deployment

**Google Play Store:**

1. Create developer account ($25 one-time fee)
2. Build app bundle: `flutter build appbundle --release`
3. Upload to Play Console internal testing track
4. Complete store listing (screenshots, description, privacy policy)
5. Submit for review (typically 1-3 days)

**Apple App Store:**

1. Apple Developer account required ($99/year)
2. Build iOS app: `flutter build ipa --release`
3. Upload via Xcode or Application Loader
4. Complete App Store Connect listing
5. Submit for review (typically 1-2 days)

## CI/CD with GitHub Actions

**`.github/workflows/build.yml`:**

```yaml
name: Build and Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.24.0"
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test

  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build apk --release

  build-ios:
    needs: test
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter build ios --release --no-codesign
```

## Environment Configuration

**No environment variables needed for MVP** - all APIs are public/free. However, for production:

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String osrmBaseUrl = 'https://router.project-osrm.org';
  static const String graphHopperBaseUrl = 'https://graphhopper.com/api/1';
  static const String graphHopperApiKey = String.fromEnvironment(
    'GRAPHHOPPER_API_KEY',
    defaultValue: '', // Empty for free tier
  );
}
```

**Build with API key:**

```bash
flutter build apk --dart-define=GRAPHHOPPER_API_KEY=your_key_here
```
