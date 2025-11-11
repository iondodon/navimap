import 'package:latlong2/latlong.dart';

/// Domain model representing the device's geographic position.
class UserLocation {
  UserLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  }) {
    _validateCoordinate(latitude, -90, 90, 'latitude');
    _validateCoordinate(longitude, -180, 180, 'longitude');
  }

  /// Latitude in decimal degrees (-90 to 90).
  final double latitude;

  /// Longitude in decimal degrees (-180 to 180).
  final double longitude;

  /// Optional horizontal accuracy in meters.
  final double? accuracy;

  /// Timestamp representing when the reading was captured.
  final DateTime timestamp;

  /// Converts the location to a flutter_map LatLng structure.
  LatLng toLatLng() => LatLng(latitude, longitude);

  /// Creates a copy with overrides for selected fields.
  UserLocation copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
  }) {
    return UserLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  static void _validateCoordinate(double value, double min, double max, String label) {
    if (value.isNaN || value < min || value > max) {
      throw ArgumentError.value(value, label, 'Must be between $min and $max degrees');
    }
  }
}