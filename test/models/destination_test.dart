import 'package:flutter_test/flutter_test.dart';
import 'package:navimap/models/destination.dart';

void main() {
  test('constructs destination and converts to LatLng', () {
    final destination = Destination(latitude: 37.7749, longitude: -122.4194);

    expect(destination.latitude, 37.7749);
    expect(destination.longitude, -122.4194);
    expect(destination.toLatLng().latitude, 37.7749);
    expect(destination.toLatLng().longitude, -122.4194);
  });

  test('throws ArgumentError when latitude out of range', () {
    expect(
      () => Destination(latitude: 91, longitude: 0),
      throwsArgumentError,
    );
  });

  test('throws ArgumentError when longitude out of range', () {
    expect(
      () => Destination(latitude: 0, longitude: 181),
      throwsArgumentError,
    );
  });

  test('equality compares coordinates', () {
    final a = Destination(latitude: 10, longitude: 20);
    final b = Destination(latitude: 10, longitude: 20);
    final c = Destination(latitude: 10.001, longitude: 20);

    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });
}