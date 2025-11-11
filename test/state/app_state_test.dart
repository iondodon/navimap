import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navimap/models/user_location.dart';
import 'package:navimap/services/location_service.dart';
import 'package:navimap/state/app_state.dart';

void main() {
  late _StubLocationService locationService;
  late http.Client httpClient;

  setUp(() {
    locationService = _StubLocationService();
    httpClient = MockClient((_) async => http.Response('', 200));
  });

  test('initializeLocation starts tracking when permission granted', () async {
    final controller = StreamController<UserLocation>.broadcast();
    final initial = _location(latitude: 1, longitude: 2);
    final update = _location(latitude: 3, longitude: 4);

    locationService.checkPermissionResult = LocationPermissionStatus.granted;
    locationService.serviceEnabled = true;
    locationService.onGetCurrentLocation = () async => initial;
    locationService.locationStream = controller.stream;

    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
    );

    await state.initializeLocation();

    expect(state.currentLocation, isNotNull);
    expect(state.currentLocation!.latitude, 1);
    expect(state.shouldCenterOnUser, isTrue);

    state.acknowledgeUserCentered();
    expect(state.shouldCenterOnUser, isFalse);

    controller.add(update);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(state.currentLocation!.latitude, 3);

    await _waitForConnectivity(state);
    state.dispose();
    await controller.close();
  });

  test('requestLocationAccess stores error when denied', () async {
    locationService.checkPermissionResult = LocationPermissionStatus.denied;
    locationService.requestPermissionResult = LocationPermissionStatus.denied;
    locationService.serviceEnabled = true;

    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
    );

    await state.initializeLocation();
    final status = await state.requestLocationAccess();

    expect(status, LocationPermissionStatus.denied);
    expect(state.hasLocationPermission, isFalse);
    expect(state.locationError, isNotNull);

    await _waitForConnectivity(state);
    state.dispose();
  });

  test('requestLocationAccess starts stream when granted', () async {
    final controller = StreamController<UserLocation>.broadcast();
    final initial = _location(latitude: 11, longitude: 22);

    locationService.checkPermissionResult = LocationPermissionStatus.denied;
    locationService.requestPermissionResult = LocationPermissionStatus.granted;
    locationService.serviceEnabled = true;
    locationService.onGetCurrentLocation = () async => initial;
    locationService.locationStream = controller.stream;

    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
    );

    await state.initializeLocation();
    final status = await state.requestLocationAccess();

    expect(status, LocationPermissionStatus.granted);
    expect(state.currentLocation, isNotNull);
    expect(state.hasLocationPermission, isTrue);

    await _waitForConnectivity(state);
    state.dispose();
    await controller.close();
  });

  test('handles service disabled error from stream', () async {
    locationService.checkPermissionResult = LocationPermissionStatus.granted;
    locationService.serviceEnabled = true;
    locationService.onGetCurrentLocation = () =>
        Future<UserLocation>.error(
          LocationServiceException(LocationServiceErrorCode.serviceDisabled, 'disabled'),
        );
    locationService.locationStream = Stream<UserLocation>.error(
      LocationServiceException(LocationServiceErrorCode.serviceDisabled, 'disabled'),
    );

    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
    );

    await state.initializeLocation();

    expect(state.locationError, contains('Location services are disabled'));

    await _waitForConnectivity(state);
    state.dispose();
  });
}

UserLocation _location({required double latitude, required double longitude}) {
  return UserLocation(
    latitude: latitude,
    longitude: longitude,
    accuracy: 5,
    timestamp: DateTime(2025, 1, 1),
  );
}

class _StubLocationService extends LocationService {
  _StubLocationService()
      : super(geolocator: _NoopGeolocator());

  LocationPermissionStatus checkPermissionResult = LocationPermissionStatus.denied;
  LocationPermissionStatus requestPermissionResult = LocationPermissionStatus.denied;
  bool serviceEnabled = true;
  Stream<UserLocation> locationStream = Stream<UserLocation>.empty();
  Future<UserLocation> Function()? onGetCurrentLocation;

  @override
  Future<LocationPermissionStatus> checkPermission() async => checkPermissionResult;

  @override
  Future<LocationPermissionStatus> requestPermission() async => requestPermissionResult;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Stream<UserLocation> getLocationStream() => locationStream;

  @override
  Future<UserLocation> getCurrentLocation() {
    final handler = onGetCurrentLocation;
    if (handler == null) {
      return Future<UserLocation>.error(
        LocationServiceException(
          LocationServiceErrorCode.unknown,
          'No current location handler configured',
        ),
      );
    }
    return handler();
  }
}

class _NoopGeolocator extends GeolocatorPlatform {
  @override
  Future<LocationPermission> checkPermission() => throw UnimplementedError();

  @override
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) =>
      throw UnimplementedError();

  @override
  Future<LocationPermission> requestPermission() => throw UnimplementedError();

  @override
  Future<bool> isLocationServiceEnabled() => throw UnimplementedError();

  @override
  Stream<ServiceStatus> getServiceStatusStream() => Stream<ServiceStatus>.empty();

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      Stream<Position>.empty();

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      throw UnimplementedError();

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      throw UnimplementedError();

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) =>
      throw UnimplementedError();

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() => throw UnimplementedError();

  @override
  Future<bool> openAppSettings() => throw UnimplementedError();

  @override
  Future<bool> openLocationSettings() => throw UnimplementedError();

  @override
  Future<void> setBackgroundMode({required bool enable}) => throw UnimplementedError();

  @override
  Future<bool> isBackgroundModeEnabled() => throw UnimplementedError();

  @override
  Future<void> updateSettings({
    LocationAccuracy? accuracy,
    int? distanceFilter,
    bool? forceLocationManager,
    Duration? timeLimit,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> startListening({
    LocationAccuracy? accuracy,
    int? distanceFilter,
    Duration? timeLimit,
    Duration? intervalDuration,
    bool? forceLocationManager,
    bool? useHighAccuracy,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> stopListening() => throw UnimplementedError();
}

Future<void> _waitForConnectivity(AppState state) async {
  while (state.isCheckingConnectivity) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
