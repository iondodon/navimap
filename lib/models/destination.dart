import 'package:latlong2/latlong.dart';

/// Domain model representing a user-selected destination point on the map.
class Destination {
  Destination({
    required this.latitude,
    required this.longitude,
  }) {
    _validateCoordinate(latitude, -90, 90, 'latitude');
    _validateCoordinate(longitude, -180, 180, 'longitude');
  }

  /// Latitude in decimal degrees (-90 to 90).
  final double latitude;

  /// Longitude in decimal degrees (-180 to 180).
  final double longitude;

  /// Converts the destination to a flutter_map LatLng value.
  LatLng toLatLng() => LatLng(latitude, longitude);

  /// Returns a copy with optional coordinate updates.
  Destination copyWith({double? latitude, double? longitude}) {
    return Destination(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Destination &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);

  static void _validateCoordinate(double value, double min, double max, String label) {
    if (value.isNaN || value < min || value > max) {
      throw ArgumentError.value(value, label, 'Must be between $min and $max degrees');
    }
  }
}