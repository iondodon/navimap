# Data Models

## Core Data Models

### UserLocation

**Purpose:** Represents the user's current GPS position with accuracy information.

**Key Attributes:**

- `latitude`: `double` - Geographic latitude in degrees (-90 to 90)
- `longitude`: `double` - Geographic longitude in degrees (-180 to 180)
- `accuracy`: `double?` - Position accuracy in meters (optional)
- `timestamp`: `DateTime` - When the position was captured

**Dart Class:**

```dart
class UserLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);
}
```

**Relationships:** Used by LocationService, consumed by MapScreen and RoutingService

---

### Destination

**Purpose:** Represents the destination point selected by the user via map tap.

**Key Attributes:**

- `latitude`: `double` - Geographic latitude in degrees
- `longitude`: `double` - Geographic longitude in degrees

**Dart Class:**

```dart
class Destination {
  final double latitude;
  final double longitude;

  Destination({
    required this.latitude,
    required this.longitude,
  });

  LatLng toLatLng() => LatLng(latitude, longitude);
}
```

**Relationships:** Created by MapScreen on tap gesture, consumed by RoutingService for route calculation

---

### Route

**Purpose:** Represents a calculated route from current location to destination, including the polyline path and metadata.

**Key Attributes:**

- `points`: `List<LatLng>` - Ordered list of coordinates forming the route polyline
- `distance`: `double` - Total route distance in meters
- `duration`: `double` - Estimated travel time in seconds
- `geometry`: `String?` - Encoded polyline geometry (optional, from API response)

**Dart Class:**

```dart
class Route {
  final List<LatLng> points;
  final double distance;
  final double duration;
  final String? geometry;

  Route({
    required this.points,
    required this.distance,
    required this.duration,
    this.geometry,
  });

  String get distanceKm => '${(distance / 1000).toStringAsFixed(1)} km';
  String get durationMin => '${(duration / 60).round()} min';
}
```

**Relationships:** Created by RoutingService from API response, consumed by MapScreen for polyline rendering

---

### AppState

**Purpose:** Central application state managed by Provider, combines all data models.

**Dart Class:**

```dart
class AppState extends ChangeNotifier {
  UserLocation? _currentLocation;
  Destination? _destination;
  Route? _route;
  bool _isLoadingRoute = false;
  String? _errorMessage;

  // Getters
  UserLocation? get currentLocation => _currentLocation;
  Destination? get destination => _destination;
  Route? get route => _route;
  bool get isLoadingRoute => _isLoadingRoute;
  String? get errorMessage => _errorMessage;

  // Setters that notify listeners
  void updateLocation(UserLocation location) {
    _currentLocation = location;
    notifyListeners();
  }

  void setDestination(Destination dest) {
    _destination = dest;
    notifyListeners();
  }

  void setRoute(Route? route) {
    _route = route;
    _isLoadingRoute = false;
    notifyListeners();
  }

  void setLoadingRoute(bool loading) {
    _isLoadingRoute = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
```
