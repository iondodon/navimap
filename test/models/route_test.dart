import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:navimap/models/route.dart';

void main() {
  group('Route', () {
    test('calculates distance in kilometers with one decimal precision', () {
      final route = Route(
        points: const [LatLng(0, 0), LatLng(1, 1)],
        distanceMeters: 1534,
        durationSeconds: 120,
      );

      expect(route.distanceKm, 1.5);
    });

    test('calculates duration in minutes rounded to nearest whole number', () {
      final route = Route(
        points: const [LatLng(0, 0), LatLng(1, 1)],
        distanceMeters: 500,
        durationSeconds: 389,
      );

      expect(route.durationMin, 6);
    });

    test('copyWith overrides provided values and preserves others', () {
      final original = Route(
        points: const [LatLng(0, 0)],
        distanceMeters: 1000,
        durationSeconds: 60,
        geometry: 'encoded',
      );

      final updated = original.copyWith(
        points: const [LatLng(1, 1)],
        durationSeconds: 120,
      );

      expect(updated.points, const [LatLng(1, 1)]);
      expect(updated.distanceMeters, 1000);
      expect(updated.durationSeconds, 120);
      expect(updated.geometry, 'encoded');
    });
  });
}
