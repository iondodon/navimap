import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/user_location.dart';

/// Normalized permission states for UI handling.
enum LocationPermissionStatus { granted, denied, deniedForever }

/// Domain specific error classification for location failures.
class LocationServiceException implements Exception {
  LocationServiceException(this.code, this.message, {this.cause});

  final LocationServiceErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() =>
      'LocationServiceException($code, $message${cause != null ? ', cause: $cause' : ''})';
}

/// Categorized error types surfaced to the UI layer.
enum LocationServiceErrorCode {
  permissionDenied,
  permissionPermanentlyDenied,
  serviceDisabled,
  timeout,
  unknown,
}

class LocationService {
  LocationService({
    GeolocatorPlatform? geolocator,
    LocationSettings? locationSettings,
    LocationSettings? currentLocationSettings,
    Duration? getLocationTimeout,
  })  : _geolocator = geolocator ?? GeolocatorPlatform.instance,
        _locationSettings = locationSettings ??
            const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
        _currentLocationSettings = currentLocationSettings ??
            const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
        _getLocationTimeout = getLocationTimeout ?? const Duration(seconds: 10);

  final GeolocatorPlatform _geolocator;
  final LocationSettings _locationSettings;
  final LocationSettings _currentLocationSettings;
  final Duration _getLocationTimeout;

  Future<LocationPermissionStatus> checkPermission() async {
    final result = await _geolocator.checkPermission();
    return _mapPermission(result);
  }

  Future<LocationPermissionStatus> requestPermission() async {
    final current = await _geolocator.checkPermission();
    if (_isGranted(current)) {
      return LocationPermissionStatus.granted;
    }
    if (current == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }

    final requested = await _geolocator.requestPermission();
    return _mapPermission(requested);
  }

  Future<bool> isLocationServiceEnabled() =>
      _geolocator.isLocationServiceEnabled();

  Stream<UserLocation> getLocationStream() {
    return _geolocator
        .getPositionStream(locationSettings: _locationSettings)
        .map(_mapPosition)
        .handleError((error) {
      throw _mapError(error);
    });
  }

  Future<UserLocation> getCurrentLocation() async {
    try {
      final position = await _geolocator
          .getCurrentPosition(locationSettings: _currentLocationSettings)
          .timeout(_getLocationTimeout);
      return _mapPosition(position);
    } on TimeoutException catch (error) {
      throw LocationServiceException(
        LocationServiceErrorCode.timeout,
        'Timed out while retrieving location',
        cause: error,
      );
    } on LocationServiceDisabledException catch (error) {
      throw LocationServiceException(
        LocationServiceErrorCode.serviceDisabled,
        'Location services disabled',
        cause: error,
      );
    } on PermissionDeniedException catch (error) {
      throw LocationServiceException(
        LocationServiceErrorCode.permissionDenied,
        'Location permission denied',
        cause: error,
      );
    } on PermissionDefinitionsNotFoundException catch (error) {
      throw LocationServiceException(
        LocationServiceErrorCode.unknown,
        'Missing platform permission definitions',
        cause: error,
      );
    } catch (error) {
      throw LocationServiceException(
        LocationServiceErrorCode.unknown,
        'Unable to retrieve location',
        cause: error,
      );
    }
  }

  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    if (_isGranted(permission)) {
      return LocationPermissionStatus.granted;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    }
    return LocationPermissionStatus.denied;
  }

  bool _isGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  UserLocation _mapPosition(Position position) {
    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy == 0 ? null : position.accuracy,
      timestamp: position.timestamp,
    );
  }

  LocationServiceException _mapError(Object error) {
    if (error is PermissionDeniedException) {
      return LocationServiceException(
        LocationServiceErrorCode.permissionDenied,
        'Location permission denied',
        cause: error,
      );
    }
    if (error is LocationServiceDisabledException) {
      return LocationServiceException(
        LocationServiceErrorCode.serviceDisabled,
        'Location services disabled',
        cause: error,
      );
    }
    return LocationServiceException(
      LocationServiceErrorCode.unknown,
      'Unexpected location error',
      cause: error,
    );
  }
}
