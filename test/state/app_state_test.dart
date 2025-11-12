import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navimap/models/destination.dart';
import 'package:navimap/models/route.dart';
import 'package:navimap/models/user_location.dart';
import 'package:navimap/services/location_service.dart';
import 'package:navimap/services/routing_service.dart';
import 'package:navimap/state/app_state.dart';

void main() {
  late _StubLocationService locationService;
  late _StubRoutingService routingService;
  late http.Client httpClient;

  setUp(() {
    locationService = _StubLocationService();
    routingService = _StubRoutingService();
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
      routingService: routingService,
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
      routingService: routingService,
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
      routingService: routingService,
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
    locationService.onGetCurrentLocation = () => Future<UserLocation>.error(
          LocationServiceException(
              LocationServiceErrorCode.serviceDisabled, 'disabled'),
        );
    locationService.locationStream = Stream<UserLocation>.error(
      LocationServiceException(
          LocationServiceErrorCode.serviceDisabled, 'disabled'),
    );

    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
      routingService: routingService,
    );

    await state.initializeLocation();

    expect(state.locationError, contains('Location services are disabled'));

    await _waitForConnectivity(state);
    state.dispose();
  });

  test('setDestination triggers route calculation when location available',
      () async {
    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
      routingService: routingService,
    );

    await _waitForConnectivity(state);

    final destination = Destination(latitude: 37.0, longitude: -122.0);
    final userLocation = _location(latitude: 36.5, longitude: -121.8);
    final updates = <bool>[];
    final listener = () => updates.add(state.isDestinationUpdating);
    state.addListener(listener);

    final completer = Completer<Route>();
    routingService.onCalculate = (start, target) {
      expect(start.latitude, userLocation.latitude);
      expect(start.longitude, userLocation.longitude);
      expect(target, destination);
      return completer.future;
    };

    state.updateLocation(userLocation);
    state.setDestination(destination);

    expect(state.currentDestination, destination);
    expect(state.isCalculatingRoute, isTrue);
    expect(routingService.callCount, 1);

    completer.complete(
      Route(
        points: [userLocation.toLatLng(), destination.toLatLng()],
        distanceMeters: 1500,
        durationSeconds: 420,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(state.currentRoute, isNotNull);
    expect(state.currentRoute!.points.length, 2);
    expect(state.routeError, isNull);
    expect(state.isCalculatingRoute, isFalse);
    expect(updates, containsAllInOrder([true, false]));

    state.removeListener(listener);
    state.dispose();
  });

  test('clearDestination removes destination without error', () async {
    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
    );

    await _waitForConnectivity(state);

    state.setDestination(Destination(latitude: 10, longitude: 20));
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(state.currentDestination, isNotNull);
    expect(state.routeError, contains('location unavailable'));

    state.clearDestination();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(state.currentDestination, isNull);
    expect(state.hasDestination, isFalse);
    expect(state.routeError, isNull);

    state.dispose();
  });

  test(
      'setDestination without location reports route error and skips service call',
      () async {
    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
      routingService: routingService,
    );

    await _waitForConnectivity(state);

    final destination = Destination(latitude: 40, longitude: -73);
    state.setDestination(destination);

    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(state.currentDestination, destination);
    expect(state.routeError, contains('location unavailable'));
    expect(state.isCalculatingRoute, isFalse);
    expect(routingService.callCount, 0);

    state.dispose();
  });

  test('route error is stored when routing service throws', () async {
    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
      routingService: routingService,
    );

    await _waitForConnectivity(state);

    final destination = Destination(latitude: 41, longitude: -74);
    final userLocation = _location(latitude: 40.5, longitude: -73.9);

    routingService.onCalculate =
        (_, __) => Future<Route>.error(RoutingException('OSRM unreachable'));

    state.updateLocation(userLocation);
    state.setDestination(destination);

    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(state.routeError, contains('OSRM unreachable'));
    expect(state.currentRoute, isNull);
    expect(state.isCalculatingRoute, isFalse);
    expect(routingService.callCount, 1);

    state.dispose();
  });

  test('clearDestination cancels in-flight route calculation', () async {
    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
      routingService: routingService,
    );

    await _waitForConnectivity(state);

    final destination = Destination(latitude: 42, longitude: -75);
    final userLocation = _location(latitude: 41.7, longitude: -74.8);
    final completer = Completer<Route>();

    routingService.onCalculate = (_, __) => completer.future;

    state.updateLocation(userLocation);
    state.setDestination(destination);

    expect(state.isCalculatingRoute, isTrue);

    state.clearDestination();
    completer.complete(
      Route(
        points: [userLocation.toLatLng(), destination.toLatLng()],
        distanceMeters: 500,
        durationSeconds: 120,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(state.currentDestination, isNull);
    expect(state.currentRoute, isNull);
    expect(state.isCalculatingRoute, isFalse);
    expect(state.routeError, isNull);

    state.dispose();
  });

  test('route recalculates automatically when location becomes available later',
      () async {
    final state = AppState(
      httpClient: httpClient,
      locationService: locationService,
      routingService: routingService,
    );

    await _waitForConnectivity(state);

    final destination = Destination(latitude: 43, longitude: -76);
    routingService.onCalculate = (start, target) async {
      expect(target, destination);
      return Route(
        points: [start.toLatLng(), destination.toLatLng()],
        distanceMeters: 1000,
        durationSeconds: 300,
      );
    };

    state.setDestination(destination);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(routingService.callCount, 0);
    expect(state.routeError, contains('location unavailable'));

    state.updateLocation(_location(latitude: 42.5, longitude: -75.5));

    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(routingService.callCount, 1);
    expect(state.currentRoute, isNotNull);
    expect(state.routeError, isNull);
    expect(state.isCalculatingRoute, isFalse);

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

class _StubRoutingService extends RoutingService {
  _StubRoutingService()
      : super(httpClient: MockClient((_) async => http.Response('', 200)));

  Future<Route> Function(UserLocation, Destination)? onCalculate;
  int callCount = 0;

  @override
  Future<Route> calculateRoute(UserLocation start, Destination destination) {
    callCount++;
    final handler = onCalculate;
    if (handler != null) {
      return handler(start, destination);
    }
    return Future<Route>.error(
      RoutingException('Routing handler not configured'),
    );
  }

  @override
  void dispose() {}
}

class _StubLocationService extends LocationService {
  _StubLocationService() : super(geolocator: _NoopGeolocator());

  LocationPermissionStatus checkPermissionResult =
      LocationPermissionStatus.denied;
  LocationPermissionStatus requestPermissionResult =
      LocationPermissionStatus.denied;
  bool serviceEnabled = true;
  Stream<UserLocation> locationStream = Stream<UserLocation>.empty();
  Future<UserLocation> Function()? onGetCurrentLocation;

  @override
  Future<LocationPermissionStatus> checkPermission() async =>
      checkPermissionResult;

  @override
  Future<LocationPermissionStatus> requestPermission() async =>
      requestPermissionResult;

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
  Stream<ServiceStatus> getServiceStatusStream() =>
      Stream<ServiceStatus>.empty();

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
  Future<LocationAccuracyStatus> getLocationAccuracy() =>
      throw UnimplementedError();

  @override
  Future<bool> openAppSettings() => throw UnimplementedError();

  @override
  Future<bool> openLocationSettings() => throw UnimplementedError();
}

Future<void> _waitForConnectivity(AppState state) async {
  while (state.isCheckingConnectivity) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
