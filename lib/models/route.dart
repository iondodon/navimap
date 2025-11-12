import 'package:latlong2/latlong.dart';

/// Domain model describing a calculated navigation route.
class Route {
  Route({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.geometry,
  })  : assert(distanceMeters >= 0, 'distanceMeters cannot be negative'),
        assert(durationSeconds >= 0, 'durationSeconds cannot be negative');

  /// Ordered coordinates representing the route polyline.
  final List<LatLng> points;

  /// Total route distance in meters.
  final double distanceMeters;

  /// Total travel duration in seconds.
  final double durationSeconds;

  /// Optional encoded polyline geometry returned by routing APIs.
  final String? geometry;

  /// Distance converted to kilometers with a single decimal precision.
  double get distanceKm => ((distanceMeters / 1000) * 10).roundToDouble() / 10;

  /// Duration converted to minutes, rounded to the nearest whole number.
  int get durationMin => (durationSeconds / 60).round();

  Route copyWith({
    List<LatLng>? points,
    double? distanceMeters,
    double? durationSeconds,
    String? geometry,
  }) {
    return Route(
      points: points ?? this.points,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      geometry: geometry ?? this.geometry,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Route &&
        other.distanceMeters == distanceMeters &&
        other.durationSeconds == durationSeconds &&
        other.geometry == geometry &&
        _listEquals(other.points, points);
  }

  @override
  int get hashCode => Object.hash(
        distanceMeters,
        durationSeconds,
        geometry,
        Object.hashAll(points),
      );

  static bool _listEquals(List<LatLng> a, List<LatLng> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
