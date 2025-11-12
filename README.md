# NaviMap

A simple open-source navigation app using OpenStreetMap and Flutter.

This project uses [BMad-Method](https://github.com/bmad-code-org/BMAD-METHOD)

## Overview

NaviMap is a cross-platform mobile navigation application built with Flutter, using OpenStreetMap for map data and OSRM/GraphHopper for routing services.

## Requirements

### Flutter SDK

- **Flutter Version**: 3.24+
- **Dart Version**: 3.5+

### Platform Requirements

- **Android**: Minimum SDK 24 (Android 7.0)
- **iOS**: iOS 12.0+

## Setup Instructions

### 1. Install Flutter

Follow the official Flutter installation guide for your platform:

- [Flutter Installation](https://docs.flutter.dev/get-started/install)

Verify installation:

```bash
flutter --version
flutter doctor
```

### 2. Clone and Setup Project

```bash
cd navimap
flutter pub get
```

### 3. Run the Application

#### Android

```bash
flutter run -d android
```

Or build APK:

```bash
flutter build apk --debug
```

#### Android Emulator (Command-Line Only)

If you prefer not to install Android Studio, you can provision an emulator with the Android SDK command-line tools.

1. **Install command-line tools**

   ```bash
   mkdir -p "$HOME/Android/Sdk/cmdline-tools"
   cd "$HOME/Android/Sdk/cmdline-tools"
   wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
   unzip -q commandlinetools-linux-11076708_latest.zip -d latest
   mv latest/cmdline-tools/* latest/
   rmdir latest/cmdline-tools
   ```

2. **Expose SDK binaries**

   ```bash
   export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
   export ANDROID_HOME="$ANDROID_SDK_ROOT"
   export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"
   ```

   Add these exports to your shell profile to persist them.

3. **Accept licenses and install components**

   ```bash
   yes | sdkmanager --licenses
   sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" "system-images;android-34;google_apis;x86_64"
   ```

4. **Create an emulator**

   ```bash
   echo no | avdmanager create avd \
     --name Pixel_6_API_34 \
     --package "system-images;android-34;google_apis;x86_64" \
     --device "pixel_6"
   ```

5. **Launch the emulator**

   ```bash
   emulator -avd Pixel_6_API_34 -no-snapshot -gpu swiftshader_indirect -noaudio -no-boot-anim
   # or
   flutter emulators --launch Pixel_6_API_34
   ```

6. **Deploy NaviMap**

   ```bash
   flutter build apk --debug
   flutter install -d emulator-5554 --debug
   adb -s emulator-5554 shell am start -n com.example.navimap/.MainActivity
   ```

7. **Stop the emulator**
   ```bash
   adb -s emulator-5554 emu kill
   ```

Once the emulator is created, repeat steps 5–7 for future sessions.

#### iOS (macOS only)

```bash
flutter run -d ios
```

Or build iOS app:

```bash
flutter build ios --debug
```

### 4. Run Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run analyzer
flutter analyze
```

## Location Permissions

### Android

The app requires the following permissions (automatically handled in AndroidManifest.xml):

- `ACCESS_FINE_LOCATION` - For precise location tracking
- `ACCESS_COARSE_LOCATION` - For approximate location
- `INTERNET` - For map tiles and routing API access

### iOS

The app requires location usage descriptions (already configured in Info.plist):

- `NSLocationWhenInUseUsageDescription` - Shown when requesting location access
- `NSLocationAlwaysUsageDescription` - For background location (if needed)

Users will be prompted to grant location permissions when the app first requests access.

## Dependencies

### Production Dependencies

- `flutter_map: ^7.0.0` - Interactive map display with OpenStreetMap
- `latlong2: ^0.9.0` - Latitude/longitude calculations
- `geolocator: ^12.0.0` - GPS and location services
- `http: ^1.2.0` - HTTP client for API requests
- `provider: ^6.1.0` - State management

### Development Dependencies

- `flutter_test` - Testing framework (built-in)
- `flutter_lints: ^4.0.0` - Code quality and linting rules
- `mockito: ^5.4.0` - Mocking for unit tests

## Project Structure

```
navimap/
├── lib/                    # Application source code
│   └── main.dart          # App entry point
├── test/                   # Unit and widget tests
│   └── widget_test.dart   # Basic widget tests
├── android/               # Android platform code
├── ios/                   # iOS platform code
├── pubspec.yaml           # Dependencies and metadata
└── analysis_options.yaml  # Linting configuration
```

## Troubleshooting

### Common Issues

#### Flutter command not found

Make sure Flutter is in your PATH:

```bash
export PATH="$HOME/flutter/bin:$PATH"
```

Add to your shell profile (~/.zshrc, ~/.bashrc) to make permanent.

#### Android SDK not found

Install Android Studio and run:

```bash
flutter doctor --android-licenses
```

#### iOS build fails

Ensure you have Xcode installed (macOS only):

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

#### Dependencies fail to resolve

Clear cache and reinstall:

```bash
flutter clean
flutter pub get
```

#### Gradle build errors (Android)

The project uses Gradle 8.3 which requires Java 17-20. Configure Java version:

```bash
flutter config --jdk-dir=<JDK_DIRECTORY>
```

If you encounter `Could not get unknown property 'flutter' for extension 'android'`, ensure `android/build.gradle` defines:

```gradle
ext.flutter = [
	compileSdkVersion: 34,
	targetSdkVersion : 34,
	minSdkVersion    : 24,
]
```

### Getting Help

- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter GitHub Issues](https://github.com/flutter/flutter/issues)
- [OpenStreetMap Documentation](https://wiki.openstreetmap.org/)

## License

MIT License - See LICENSE file for details.

## Contributing

This is an open-source project. Contributions are welcome!
