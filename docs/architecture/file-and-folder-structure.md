# File and Folder Structure

## Project Directory Layout

```
navimap/
├── android/                      # Android native configuration
│   ├── app/
│   │   ├── src/main/
│   │   │   └── AndroidManifest.xml  # Location permissions
│   │   └── build.gradle          # Min SDK 24 (Android 7.0)
│   └── build.gradle
├── ios/                          # iOS native configuration
│   ├── Runner/
│   │   ├── Info.plist            # Location permissions, iOS 12.0+
│   │   └── AppDelegate.swift
│   └── Podfile
├── lib/                          # Main application code
│   ├── main.dart                 # App entry point, Provider setup
│   ├── models/                   # Data models
│   │   ├── user_location.dart    # UserLocation class
│   │   ├── destination.dart      # Destination class
│   │   └── route.dart            # Route class
│   ├── services/                 # Business logic services
│   │   ├── location_service.dart # GPS/positioning logic
│   │   └── routing_service.dart  # API integration, fallback logic
│   ├── state/                    # State management
│   │   └── app_state.dart        # AppState ChangeNotifier
│   ├── screens/                  # UI screens
│   │   └── map_screen.dart       # Main map interface
│   └── widgets/                  # Reusable UI components (if needed)
├── test/                         # Unit and widget tests
│   ├── models/
│   │   ├── user_location_test.dart
│   │   ├── destination_test.dart
│   │   └── route_test.dart
│   ├── services/
│   │   ├── location_service_test.dart
│   │   └── routing_service_test.dart
│   └── state/
│       └── app_state_test.dart
├── integration_test/             # Integration tests (optional for MVP)
│   └── app_test.dart
├── assets/                       # Static assets (if any)
├── pubspec.yaml                  # Dependencies and metadata
├── pubspec.lock                  # Locked dependency versions
├── analysis_options.yaml         # Linting rules
├── README.md                     # Project documentation
├── LICENSE                       # MIT or GPL v3
└── .gitignore                    # Git ignore rules
```

## Key File Purposes

**`lib/main.dart`:**

- App initialization
- Provider setup (ChangeNotifierProvider for AppState)
- MaterialApp configuration
- Routes MapScreen as home

**`lib/models/`:**

- Pure Dart classes with no Flutter dependencies
- Immutable data structures
- Helper methods (toLatLng(), distanceKm, etc.)

**`lib/services/`:**

- LocationService: Wraps geolocator, handles permissions, provides streams
- RoutingService: HTTP clients, API calls, JSON parsing, fallback logic

**`lib/state/app_state.dart`:**

- Extends ChangeNotifier
- Holds all app state (location, destination, route, loading, errors)
- Coordination point between services and UI

**`lib/screens/map_screen.dart`:**

- StatelessWidget consuming AppState via Consumer
- FlutterMap widget with OSM tile layer
- Marker layers for location/destination
- Polyline layer for route
- GestureDetector for tap handling

**`android/app/src/main/AndroidManifest.xml`:**

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

**`ios/Runner/Info.plist`:**

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>NaviMap needs your location to show routes from your current position</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>NaviMap needs your location to show routes from your current position</string>
```
