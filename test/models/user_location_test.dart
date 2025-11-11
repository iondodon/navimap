import 'package:flutter_test/flutter_test.dart';
import 'package:navimap/models/user_location.dart';

void main() {
  group('UserLocation', () {
    test('creates LatLng representation with matching coordinates', () {
      final location = UserLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime.utc(2025, 1, 1),
      );

      final latLng = location.toLatLng();

      expect(latLng.latitude, location.latitude);
      expect(latLng.longitude, location.longitude);
    });

    test('throws when latitude is outside valid range', () {
      expect(
        () => UserLocation(
          latitude: 120.0,
          longitude: 0,
          timestamp: DateTime.utc(2025, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('throws when longitude is outside valid range', () {
      expect(
        () => UserLocation(
          latitude: 0,
          longitude: -181,
          timestamp: DateTime.utc(2025, 1, 1),
        ),
        throwsArgumentError,
      );
    });

    test('copyWith overrides selected fields', () {
      final original = UserLocation(
        latitude: 10,
        longitude: 20,
        accuracy: 15,
        timestamp: DateTime.utc(2025, 1, 1),
      );

      final updated = original.copyWith(latitude: -10, accuracy: 5);

      expect(updated.latitude, -10);
      expect(updated.longitude, 20);
      expect(updated.accuracy, 5);
      expect(updated.timestamp, original.timestamp);
    });
  });
}