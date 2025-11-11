# Performance Optimization

## Meeting Non-Functional Requirements

### NFR1: Map loads within 3 seconds

**Optimizations:**

- Use flutter_map with efficient tile caching (built-in)
- Preload center tiles on initial location acquisition
- Set reasonable initial zoom level (14-16) to limit tile count
- Use compressed PNG tiles from OSM (standard)

```dart
// In MapScreen
FlutterMap(
  options: MapOptions(
    center: initialLocation,
    zoom: 15.0,  // Balance detail vs tile count
    maxZoom: 18.0,
    minZoom: 10.0,
  ),
  // ...
)
```

---

### NFR2: UI responds within 100ms

**Optimizations:**

- Use `StatelessWidget` for MapScreen (rebuilds via Provider)
- Avoid heavy computations on UI thread
- Offload route parsing to isolate if needed (likely unnecessary for MVP)
- Minimize widget tree depth
- Use `const` constructors where possible

```dart
// Efficient marker layer
MarkerLayer(
  markers: [
    if (appState.currentLocation != null)
      Marker(
        point: appState.currentLocation!.toLatLng(),
        builder: (ctx) => const Icon(
          Icons.my_location,
          color: Colors.blue,
          size: 24.0,
        ),
      ),
    if (appState.destination != null)
      Marker(
        point: appState.destination!.toLatLng(),
        builder: (ctx) => const Icon(
          Icons.location_pin,
          color: Colors.red,
          size: 32.0,
        ),
      ),
  ],
)
```

---

### NFR3: Route calculation within 5 seconds

**Optimizations:**

- Set HTTP client timeout to 5 seconds
- Fallback immediately on timeout (don't retry primary)
- Use persistent HTTP connections (enabled by default in `http` package)
- Request compressed responses (Accept-Encoding: gzip)

```dart
final client = http.Client();

Future<http.Response> _makeRequest(Uri uri) async {
  return await client.get(
    uri,
    headers: {
      'User-Agent': 'NaviMap/1.0',
      'Accept-Encoding': 'gzip',
    },
  ).timeout(Duration(seconds: 5));
}
```

---

### NFR8: Package size under 50MB

**Optimizations:**

- Avoid including unnecessary assets
- Use ProGuard/R8 for Android (enabled by default in release)
- Strip debug symbols from iOS build
- No large font files or images in assets folder

**Build Configuration:**

```bash
# Android: App bundle (smaller download)
flutter build appbundle --release --shrink

# iOS: Optimized build
flutter build ios --release --split-debug-info=./debug-info
```

**Expected Sizes:**

- Android APK: ~15-25MB
- iOS IPA: ~20-30MB
- Well within 50MB limit

---

## Location Update Throttling

**Optimization:** Prevent excessive UI rebuilds from rapid GPS updates

```dart
// In LocationService
Stream<UserLocation> getLocationStream() {
  return Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,  // Update only if moved 10+ meters
    ),
  ).map((position) => UserLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
    timestamp: position.timestamp ?? DateTime.now(),
  ));
}
```

---

## Memory Management

**Best Practices:**

- Dispose StreamSubscriptions in LocationService
- Cancel HTTP requests on widget disposal (if user leaves app)
- flutter_map handles tile cache eviction automatically
- No need for image caching (no local images)

```dart
// In LocationService
class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  void dispose() {
    _positionSubscription?.cancel();
  }
}
```
