import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:navimap/models/user_location.dart';
import 'package:navimap/services/location_service.dart';

void main() {
  late _TestGeolocatorPlatform geolocator;
  late LocationService service;

  setUp(() {
    geolocator = _TestGeolocatorPlatform();
    service = LocationService(geolocator: geolocator);
  });

  group('requestPermission', () {
    test('returns granted when current permission already granted', () async {
      geolocator.permission = LocationPermission.whileInUse;

      final status = await service.requestPermission();

      expect(status, LocationPermissionStatus.granted);
      expect(geolocator.requestPermissionCalls, 0);
    });

    test('returns granted when permission request succeeds', () async {
      geolocator.permission = LocationPermission.denied;
      geolocator.requestPermissionResult = LocationPermission.always;

      final status = await service.requestPermission();

      expect(status, LocationPermissionStatus.granted);
      expect(geolocator.requestPermissionCalls, 1);
    });

    test('returns deniedForever when system reports deniedForever', () async {
      geolocator.permission = LocationPermission.deniedForever;

      final status = await service.requestPermission();

      expect(status, LocationPermissionStatus.deniedForever);
      expect(geolocator.requestPermissionCalls, 0);
    });

    test('returns denied when permission request returns denied', () async {
      geolocator.permission = LocationPermission.denied;
      geolocator.requestPermissionResult = LocationPermission.denied;

      final status = await service.requestPermission();

      expect(status, LocationPermissionStatus.denied);
      expect(geolocator.requestPermissionCalls, 1);
    });
  });

  group('getLocationStream', () {
    test('maps Position updates to UserLocation', () async {
      final position = _position(
        latitude: 37.0,
        longitude: -122.0,
        accuracy: 5,
        timestamp: DateTime(2025, 1, 1, 12),
      );
      geolocator.positionStream = Stream.value(position);

      final result = await service.getLocationStream().first;

      expect(result, isA<UserLocation>());
      expect(result.latitude, closeTo(37.0, 1e-9));
      expect(result.longitude, closeTo(-122.0, 1e-9));
      expect(result.accuracy, 5);
      expect(result.timestamp, position.timestamp);
    });

    test('wraps permission denied errors', () async {
      geolocator.positionStreamError =
          const PermissionDeniedException('denied');

      expect(
        () => service.getLocationStream().first,
        throwsA(isA<LocationServiceException>().having(
          (e) => e.code,
          'code',
          LocationServiceErrorCode.permissionDenied,
        )),
      );
    });

    test('wraps generic errors', () async {
      geolocator.positionStreamError = Exception('boom');

      expect(
        () => service.getLocationStream().first,
        throwsA(isA<LocationServiceException>().having(
          (e) => e.code,
          'code',
          LocationServiceErrorCode.unknown,
        )),
      );
    });
  });

  group('getCurrentLocation', () {
    test('returns mapped UserLocation on success', () async {
      final position = _position(
        latitude: 51.5,
        longitude: -0.12,
        accuracy: 4,
        timestamp: DateTime(2025, 1, 2, 10),
      );
      geolocator.currentPosition = position;

      final result = await service.getCurrentLocation();

      expect(result.latitude, 51.5);
      expect(result.longitude, -0.12);
      expect(result.accuracy, 4);
      expect(result.timestamp, position.timestamp);
    });

    test('wraps permission denied exception', () async {
      geolocator.currentPositionError =
          const PermissionDeniedException('denied');

      expect(
        () => service.getCurrentLocation(),
        throwsA(isA<LocationServiceException>().having(
          (e) => e.code,
          'code',
          LocationServiceErrorCode.permissionDenied,
        )),
      );
    });

    test('wraps generic exception', () async {
      geolocator.currentPositionError = Exception('crash');

      expect(
        () => service.getCurrentLocation(),
        throwsA(isA<LocationServiceException>().having(
          (e) => e.code,
          'code',
          LocationServiceErrorCode.unknown,
        )),
      );
    });
  });
}

Position _position({
  required double latitude,
  required double longitude,
  required double accuracy,
  required DateTime timestamp,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
    timestamp: timestamp,
    isMocked: false,
  );
}

class _TestGeolocatorPlatform extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestPermissionResult = LocationPermission.denied;
  bool serviceEnabled = true;
  int requestPermissionCalls = 0;
  Stream<Position> positionStream = const Stream.empty();
  Object? positionStreamError;
  Position? currentPosition;
  Object? currentPositionError;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    permission = requestPermissionResult;
    return requestPermissionResult;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    if (positionStreamError != null) {
      return Stream.error(positionStreamError!);
    }
    return positionStream;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    if (currentPositionError != null) {
      final error = currentPositionError!;
      if (error is Exception) {
        throw error;
      }
      throw Exception(error.toString());
    }

    final position = currentPosition;
    if (position == null) {
      throw StateError('No position configured');
    }

    return position;
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() => const Stream.empty();

  // Remaining methods are not used by the tests and simply throw.
  @override
  Future<bool> openAppSettings() => _unsupported();

  @override
  Future<bool> openLocationSettings() => _unsupported();

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      _unsupported();

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() => _unsupported();

  Future<bool> isBackgroundModeEnabled() => _unsupported();

  Future<void> setBackgroundMode({required bool enable}) => _unsupported();

  Future<void> updateSettings({
    LocationAccuracy? accuracy,
    int? distanceFilter,
    bool? forceLocationManager,
    Duration? timeLimit,
  }) =>
      _unsupported();

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) =>
      throw UnimplementedError();

  @override
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) =>
      throw UnimplementedError();

  Future<void> startListening({
    LocationAccuracy? accuracy,
    int? distanceFilter,
    Duration? timeLimit,
    Duration? intervalDuration,
    bool? forceLocationManager,
    bool? useHighAccuracy,
  }) =>
      _unsupported();

  Future<void> stopListening() => _unsupported();

  Future<T> _unsupported<T>() => Future<T>.error(UnimplementedError());
}
