# Testing Strategy

## Testing Pyramid

**Unit Tests (70%):**

- All data models (UserLocation, Destination, Route)
- Service logic (LocationService, RoutingService)
- AppState state transitions
- API response parsing
- Fallback logic

**Widget Tests (20%):**

- MapScreen rendering with different AppState configurations
- Marker display logic
- Polyline rendering
- Loading indicators
- Error message display

**Integration Tests (10%):**

- End-to-end user flows (optional for MVP given timeline)
- Full app launch → location → tap → route workflow

## Unit Test Examples

**`test/services/routing_service_test.dart`:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

void main() {
  group('RoutingService', () {
    test('successfully parses OSRM response', () async {
      final mockClient = MockClient();
      when(mockClient.get(any)).thenAnswer((_) async =>
        http.Response(osrmSuccessJson, 200));

      final service = RoutingService(httpClient: mockClient);
      final route = await service.calculateRoute(start, end);

      expect(route.distance, 1234.5);
      expect(route.points.length, greaterThan(2));
    });

    test('falls back to GraphHopper on OSRM failure', () async {
      final mockClient = MockClient();
      when(mockClient.get(argThat(contains('osrm'))))
        .thenThrow(Exception('OSRM down'));
      when(mockClient.get(argThat(contains('graphhopper'))))
        .thenAnswer((_) async => http.Response(graphHopperJson, 200));

      final service = RoutingService(httpClient: mockClient);
      final route = await service.calculateRoute(start, end);

      expect(route, isNotNull); // Successfully fell back
    });
  });
}
```

**`test/state/app_state_test.dart`:**

```dart
void main() {
  group('AppState', () {
    test('notifies listeners when location updates', () {
      final appState = AppState();
      var notified = false;
      appState.addListener(() => notified = true);

      appState.updateLocation(UserLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
      ));

      expect(notified, isTrue);
      expect(appState.currentLocation, isNotNull);
    });
  });
}
```

## Test Coverage Goals

- **Target:** 70%+ code coverage for MVP
- **Critical Path:** 100% coverage for RoutingService fallback logic
- **Run Tests:** `flutter test --coverage`
- **View Coverage:** `genhtml coverage/lcov.info -o coverage/html`

## Manual Testing Checklist

- [ ] App launches on Android 7.0+ device
- [ ] App launches on iOS 12.0+ device
- [ ] Location permission dialog appears on first launch
- [ ] Blue dot appears at current location within 3 seconds
- [ ] Tapping map places red pin at tap location
- [ ] Route polyline renders after pin placement (within 5 seconds)
- [ ] Tapping new location replaces pin and recalculates route
- [ ] App handles airplane mode gracefully with error message
- [ ] App handles GPS disabled gracefully with error message
- [ ] Pan/zoom gestures respond smoothly (<100ms)
- [ ] App closes and reopens without crashes
