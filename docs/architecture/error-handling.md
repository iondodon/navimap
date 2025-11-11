# Error Handling

## Error Categories and Handling

### 1. Location Permission Errors

**Scenario:** User denies location permission or revokes it

**Handling:**

```dart
// In LocationService
Future<bool> requestPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw LocationException('Location permission denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw LocationException(
      'Location permission permanently denied. '
      'Please enable in system settings.'
    );
  }

  return true;
}
```

**UI Response:** Display modal dialog with explanation and link to system settings

---

### 2. GPS/Location Service Disabled

**Scenario:** Device GPS is turned off

**Handling:**

```dart
Future<void> checkLocationService() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw LocationException(
      'Location services are disabled. '
      'Please enable GPS in device settings.'
    );
  }
}
```

**UI Response:** Show persistent banner with "Enable GPS" message

---

### 3. Network Connectivity Errors

**Scenario:** No internet connection when calculating route

**Handling:**

```dart
// In RoutingService
Future<Route> calculateRoute(UserLocation start, Destination end) async {
  try {
    return await _fetchRouteFromOSRM(start, end);
  } on SocketException {
    throw RoutingException(
      'No internet connection. Please check your network.'
    );
  } on TimeoutException {
    // Try fallback...
  }
}
```

**UI Response:** Show snackbar with error message, keep previous route visible if exists

---

### 4. Routing API Failures

**Scenario:** Both OSRM and GraphHopper fail

**Handling:**

```dart
Future<Route> calculateRoute(UserLocation start, Destination end) async {
  try {
    return await _fetchRouteFromOSRM(start, end)
      .timeout(Duration(seconds: 5));
  } catch (e) {
    try {
      return await _fetchRouteFromGraphHopper(start, end)
        .timeout(Duration(seconds: 5));
    } catch (e2) {
      throw RoutingException(
        'Unable to calculate route. Please try again later.'
      );
    }
  }
}
```

**UI Response:** Show error snackbar, remove loading indicator, keep destination pin visible

---

### 5. Invalid Route Scenarios

**Scenario:** No route exists between points (e.g., ocean to ocean)

**Handling:**

```dart
Route _parseOSRMResponse(Map<String, dynamic> json) {
  if (json['code'] != 'Ok') {
    throw RoutingException(
      'No route found between these locations'
    );
  }
  // Parse route...
}
```

**UI Response:** Show snackbar explaining no route available

---

### 6. Map Tile Loading Errors

**Scenario:** OSM tile server unreachable or slow

**Handling:**

```dart
// In MapScreen FlutterMap configuration
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  tileProvider: NetworkTileProvider(),
  errorTileCallback: (tile, error) {
    print('Failed to load tile: $error');
  },
  // Built-in retry logic in flutter_map
),
```

**UI Response:** flutter_map handles gracefully with empty tile placeholders

---

## Error Message Guidelines

**All error messages should be:**

- User-friendly (avoid technical jargon)
- Actionable (tell user what to do)
- Concise (single sentence when possible)
- Non-blocking (use snackbars, not modal dialogs unless critical)

**Error Display Pattern:**

```dart
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Dismiss',
        onPressed: () {},
      ),
    ),
  );
}
```
