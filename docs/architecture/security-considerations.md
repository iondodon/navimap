# Security Considerations

## 1. Network Security

**HTTPS Enforcement:**

- All API calls (OSRM, GraphHopper, OSM tiles) use HTTPS
- No HTTP fallback allowed
- Certificate pinning NOT required for MVP (external services)

**Android Configuration (`android/app/src/main/AndroidManifest.xml`):**

```xml
<application
    android:usesCleartextTraffic="false"
    ...>
```

**iOS Configuration:** HTTPS enforced by default (App Transport Security)

---

## 2. Permissions

**Principle of Least Privilege:**

- Request ONLY location permission (no camera, contacts, storage, etc.)
- Request "When In Use" location (not "Always")
- Request permission just-in-time (on app launch when needed)

**Android Permissions:**

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS Permissions:**

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>NaviMap needs your location to show routes from your current position</string>
```

---

## 3. Data Privacy

**Zero Data Collection Policy:**

- No analytics or crash reporting in MVP
- No user accounts or authentication
- No persistent storage of location data
- All state cleared when app closes
- No background location tracking

**Privacy Policy (required for app stores):**

- Must explicitly state no data collection
- Explain location permission usage
- Disclose third-party services (OSM, OSRM, GraphHopper)
- Note: Third-party services may log IP addresses (standard)

---

## 4. API Security

**Rate Limiting Protection:**

```dart
// Simple rate limiter to avoid API abuse
class RateLimiter {
  final Map<String, DateTime> _lastRequests = {};
  final Duration minInterval = Duration(seconds: 1);

  bool canMakeRequest(String key) {
    final lastRequest = _lastRequests[key];
    if (lastRequest == null) return true;

    return DateTime.now().difference(lastRequest) > minInterval;
  }

  void recordRequest(String key) {
    _lastRequests[key] = DateTime.now();
  }
}
```

**API Key Protection (for GraphHopper):**

- Store in environment variables, not hardcoded
- Use `--dart-define` for build-time injection
- Rotate keys if exposed

---

## 5. Code Security

**Dependency Management:**

- Use `pubspec.lock` to pin exact versions
- Run `flutter pub outdated` regularly
- Monitor for security advisories on packages
- Use only well-maintained packages (flutter_map, geolocator, provider, http)

**Static Analysis:**

```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - avoid_print # No sensitive data in logs
    - avoid_web_libraries_in_flutter
    - prefer_const_constructors
```

---

## 6. Input Validation

**Coordinate Validation:**

```dart
class Destination {
  final double latitude;
  final double longitude;

  Destination({required this.latitude, required this.longitude}) {
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError('Invalid latitude: $latitude');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError('Invalid longitude: $longitude');
    }
  }
}
```

**API Response Validation:**

```dart
Route _parseOSRMResponse(Map<String, dynamic> json) {
  // Validate structure before accessing
  if (!json.containsKey('routes') || json['routes'].isEmpty) {
    throw RoutingException('Invalid API response');
  }

  final route = json['routes'][0];
  if (!route.containsKey('geometry') || !route.containsKey('distance')) {
    throw RoutingException('Incomplete route data');
  }

  // Parse with null safety...
}
```
