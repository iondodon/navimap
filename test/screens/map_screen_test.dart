import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimap/models/destination.dart';
import 'package:navimap/models/user_location.dart';
import 'package:navimap/screens/map_screen.dart';
import 'package:navimap/services/location_service.dart';
import 'package:navimap/state/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  group('Destination taps', () {
    late _StubLocationService locationService;
    late _TestAppState appState;

    setUp(() async {
      locationService = _StubLocationService();
      appState = _TestAppState(
        httpClient: MockClient((_) async => http.Response('', 200)),
        locationService: locationService,
      );
      await _waitForConnectivity(appState);
    });

    tearDown(() async {
      await _waitForConnectivity(appState);
      appState.dispose();
    });

    testWidgets('tap on map sets destination and renders marker',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(body: MapScreen()),
          ),
        ),
      );

      await _pumpUntilConnectivity(tester, appState);

      expect(find.byType(FlutterMap), findsOneWidget);

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.onTap, isNotNull);

      appState.setDestination(
        Destination(latitude: 37.7749, longitude: -122.4194),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(appState.currentDestination, isNotNull);

      final markerLayers =
          tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).toList();
      expect(markerLayers, hasLength(1));
      expect(markerLayers.first.markers, hasLength(1));
    });

    testWidgets('map onTap callback updates and replaces destination markers',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(body: MapScreen()),
          ),
        ),
      );

      await _pumpUntilConnectivity(tester, appState);

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final onTap = flutterMap.options.onTap;
      expect(onTap, isNotNull);

      const firstPoint = LatLng(37.7749, -122.4194);
      const secondPoint = LatLng(51.5074, -0.1278);

      onTap!(
        const TapPosition(Offset(100, 100), Offset(0.5, 0.5)),
        firstPoint,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(appState.currentDestination, isNotNull);
      expect(appState.currentDestination!.latitude,
          closeTo(firstPoint.latitude, 1e-6));
      expect(appState.currentDestination!.longitude,
          closeTo(firstPoint.longitude, 1e-6));

      var markerLayers =
          tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).toList();
      expect(markerLayers, hasLength(1));
      expect(markerLayers.first.markers, hasLength(1));
      expect(markerLayers.first.markers.single.alignment, Alignment.topCenter);
      expect(markerLayers.first.markers.single.point.latitude,
          closeTo(firstPoint.latitude, 1e-6));
      expect(markerLayers.first.markers.single.point.longitude,
          closeTo(firstPoint.longitude, 1e-6));

      onTap(
        const TapPosition(Offset(200, 180), Offset(0.6, 0.4)),
        secondPoint,
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 260));

      expect(appState.currentDestination, isNotNull);
      expect(appState.currentDestination!.latitude,
          closeTo(secondPoint.latitude, 1e-6));
      expect(appState.currentDestination!.longitude,
          closeTo(secondPoint.longitude, 1e-6));

      markerLayers =
          tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).toList();
      expect(markerLayers, hasLength(1));
      expect(markerLayers.first.markers, hasLength(1));
      expect(markerLayers.first.markers.single.alignment, Alignment.topCenter);
      expect(markerLayers.first.markers.single.point.latitude,
          closeTo(secondPoint.latitude, 1e-6));
      expect(markerLayers.first.markers.single.point.longitude,
          closeTo(secondPoint.longitude, 1e-6));
    });

    testWidgets('clearing destination removes marker', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(body: MapScreen()),
          ),
        ),
      );

      await _pumpUntilConnectivity(tester, appState);

      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.onTap, isNotNull);

      appState.setDestination(Destination(latitude: 51.5, longitude: -0.09));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(
          tester
              .widgetList<MarkerLayer>(find.byType(MarkerLayer))
              .single
              .markers,
          hasLength(1));

      appState.clearDestination();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byType(MarkerLayer), findsNothing);
    });
  });

  group('Location marker rendering', () {
    late _StubLocationService locationService;
    late _TestAppState appState;

    setUp(() async {
      locationService = _StubLocationService();
      appState = _TestAppState(
        httpClient: MockClient((_) async => http.Response('', 200)),
        locationService: locationService,
      );
      await _waitForConnectivity(appState);
    });

    tearDown(() async {
      await _waitForConnectivity(appState);
      appState.dispose();
    });

    testWidgets('renders blue marker and accuracy ring when location provided',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(body: MapScreen()),
          ),
        ),
      );

      await _pumpUntilConnectivity(tester, appState);

      final location = UserLocation(
        latitude: 40.7128,
        longitude: -74.0060,
        accuracy: 25,
        timestamp: DateTime(2025, 1, 1, 12),
      );

      appState.updateLocation(location);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final circleLayers =
          tester.widgetList<CircleLayer>(find.byType(CircleLayer)).toList();
      expect(circleLayers, hasLength(1));
      final circle = circleLayers.single.circles.single;
      expect(circle.point.latitude, closeTo(location.latitude, 1e-6));
      expect(circle.point.longitude, closeTo(location.longitude, 1e-6));

      final markerLayers =
          tester.widgetList<MarkerLayer>(find.byType(MarkerLayer)).toList();
      expect(markerLayers, hasLength(1));
      final marker = markerLayers.single.markers.single;
      expect(marker.point.latitude, closeTo(location.latitude, 1e-6));
      expect(marker.point.longitude, closeTo(location.longitude, 1e-6));
    });
  });

  group('Connectivity and permissions', () {
    late _StubLocationService locationService;

    setUp(() {
      locationService = _StubLocationService();
    });

    testWidgets('shows offline placeholder when tile server is unreachable',
        (tester) async {
      final mockClient = MockClient((_) async => http.Response('error', 500));
      final state =
          AppState(httpClient: mockClient, locationService: locationService);
      addTearDown(() async {
        await _waitForConnectivity(state);
        state.dispose();
      });

      await _pumpMap(tester, state);

      expect(find.text('Offline Mode'), findsOneWidget);
      expect(state.connectivityStatus, isFalse);
    });

    testWidgets('retry button triggers another connectivity probe',
        (tester) async {
      var requestCount = 0;
      final mockClient = MockClient((_) async {
        requestCount++;
        return http.Response('error', 500);
      });
      final state =
          AppState(httpClient: mockClient, locationService: locationService);
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

      await state.retryConnectivityCheck();
      await _waitForConnectivity(state);

      expect(state.retryToken, greaterThan(0));
      expect(requestCount, greaterThan(1));
    });

    testWidgets('shows permission banner when location permission denied',
        (tester) async {
      final mockClient = MockClient((_) async => http.Response('error', 500));
      final state =
          AppState(httpClient: mockClient, locationService: locationService);
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
  });
}

Future<void> _pumpUntilConnectivity(
    WidgetTester tester, AppState appState) async {
  // Add a timeout to prevent infinite loop if connectivity never resolves.
  final start = DateTime.now();
  const timeout = Duration(seconds: 3);
  while (appState.isCheckingConnectivity) {
    if (DateTime.now().difference(start) > timeout) {
      throw TimeoutException(
          'AppState.isCheckingConnectivity did not resolve in time');
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pump();
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

class _TestAppState extends AppState {
  _TestAppState({
    required http.Client httpClient,
    required LocationService locationService,
  }) : super(httpClient: httpClient, locationService: locationService);

  @override
  Future<void> initializeLocation() async {
    // Skip location initialization for deterministic tap tests.
  }
}

class _StubLocationService extends LocationService {
  _StubLocationService()
      : super(
          geolocator: _NoopGeolocator(),
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.lowest),
          currentLocationSettings:
              const LocationSettings(accuracy: LocationAccuracy.lowest),
        );

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
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;

  @override
  Future<bool> isLocationServiceEnabled() async => false;

  @override
  Stream<ServiceStatus> getServiceStatusStream() =>
      const Stream<ServiceStatus>.empty();

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Future<Position>.error('unused');

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      const Stream<Position>.empty();

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      Future<Position?>.value(null);

  @override
  Future<bool> openAppSettings() => Future<bool>.value(false);

  @override
  Future<bool> openLocationSettings() => Future<bool>.value(false);

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) =>
      0;

  @override
  double bearingBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) =>
      0;

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.reduced;
}
