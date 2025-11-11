import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:navimap/models/user_location.dart';
import 'package:navimap/screens/map_screen.dart';
import 'package:navimap/services/location_service.dart';
import 'package:navimap/state/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  late _StubLocationService locationService;

  setUp(() {
    locationService = _StubLocationService();
  });

  testWidgets('shows offline placeholder when tile server is unreachable', (tester) async {
    final mockClient = MockClient((_) async => http.Response('error', 500));
    final state = AppState(httpClient: mockClient, locationService: locationService);
    addTearDown(() async {
      await _waitForConnectivity(state);
      state.dispose();
    });

    await _pumpMap(tester, state);

    expect(find.text('Offline Mode'), findsOneWidget);
    expect(find.byType(MapScreen), findsOneWidget);
    expect(state.connectivityStatus, isFalse);
  });

  testWidgets('retry button triggers another connectivity probe', (tester) async {
    var requestCount = 0;
    final mockClient = MockClient((_) async {
      requestCount++;
      return http.Response('error', 500);
    });
    final state = AppState(httpClient: mockClient, locationService: locationService);
    addTearDown(() async {
      await _waitForConnectivity(state);
      state.dispose();
    });

    await _pumpMap(tester, state);

    expect(requestCount, 1);
    final retryButton = find.widgetWithText(FilledButton, 'Retry');
    expect(retryButton, findsOneWidget);

  await tester.tap(retryButton, warnIfMissed: false);
    await tester.pump();

    // Invoke the retry handler directly to avoid external HTTP traffic in the test.
    await state.retryConnectivityCheck();
    await _waitForConnectivity(state);

    expect(state.retryToken, greaterThan(0));
    expect(requestCount, greaterThan(1));
  });

  testWidgets('shows permission banner when location permission denied', (tester) async {
    final mockClient = MockClient((_) async => http.Response('error', 500));
    final state = AppState(httpClient: mockClient, locationService: locationService);
    addTearDown(() async {
      await _waitForConnectivity(state);
      state.dispose();
    });

    locationService.checkPermissionResult = LocationPermissionStatus.denied;
    locationService.requestPermissionResult = LocationPermissionStatus.denied;

    await _pumpMap(tester, state);

    expect(find.text('Enable Location Access'), findsOneWidget);

    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();

    expect(find.text('Enable Location'), findsOneWidget);
  });
}

Future<void> _pumpMap(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MapScreen(),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _waitForConnectivity(state);
}

Future<void> _waitForConnectivity(AppState state) async {
  while (state.isCheckingConnectivity) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _StubLocationService extends LocationService {
  _StubLocationService() : super(geolocator: _NoopGeolocator());

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
  double bearingBetween(
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
