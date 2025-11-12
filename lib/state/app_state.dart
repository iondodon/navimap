import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/destination.dart';
import '../models/route.dart';
import '../models/user_location.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/osm_tile_provider.dart';
import 'error_state.dart';

class AppState extends ChangeNotifier {
  AppState({
    http.Client? httpClient,
    LocationService? locationService,
    RoutingService? routingService,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _locationService = locationService ?? LocationService(),
        _routingService = routingService ??
            RoutingService(httpClient: httpClient ?? http.Client()),
        _ownsRoutingService = routingService == null {
    _beginConnectivityProbe();
  }

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final LocationService _locationService;
  final RoutingService _routingService;
  final bool _ownsRoutingService;
  StreamSubscription<UserLocation>? _locationSubscription;

  static const LatLng defaultCenter = LatLng(37.7749, -122.4194);
  static const double defaultZoom = 15;
  static const double minZoomLevel = 5;
  static const double maxZoomLevel = 18;

  LatLng _center = defaultCenter;
  double _zoom = defaultZoom;
  bool _mapReady = false;
  ErrorState? _tileError;
  ErrorState? _networkError;
  bool? _hasConnectivity;
  bool _isCheckingConnectivity = false;
  Future<void>? _connectivityFuture;
  int _retryToken = 0;
  UserLocation? _currentLocation;
  bool _hasLocationPermission = false;
  bool _permissionDeniedForever = false;
  bool _isRequestingPermission = false;
  bool _isLocationLoading = false;
  bool _isLocationServiceEnabled = true;
  ErrorState? _locationError;
  bool _shouldCenterOnUser = false;
  bool _hasCenteredOnUser = false;
  Destination? _currentDestination;
  bool _isDestinationUpdating = false;
  String? _destinationError;
  Route? _currentRoute;
  bool _isCalculatingRoute = false;
  ErrorState? _routingError;
  int _routeRequestId = 0;

  LatLng get center => _center;
  double get zoom => _zoom;
  double get minZoom => minZoomLevel;
  double get maxZoom => maxZoomLevel;
  bool get isMapReady => _mapReady;
  bool get hasTileError => _tileError != null;
  ErrorState? get tileError => _tileError;
  ErrorState? get networkError => _networkError;
  bool? get connectivityStatus => _hasConnectivity;
  bool get hasConnectivity => _hasConnectivity ?? false;
  bool get isConnectivityKnown => _hasConnectivity != null;
  bool get isCheckingConnectivity => _isCheckingConnectivity;
  int get retryToken => _retryToken;
  UserLocation? get currentLocation => _currentLocation;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get permissionDeniedForever => _permissionDeniedForever;
  bool get isRequestingPermission => _isRequestingPermission;
  bool get isLocationLoading => _isLocationLoading;
  bool get isLocationServiceEnabled => _isLocationServiceEnabled;
  ErrorState? get locationError => _locationError;
  bool get shouldCenterOnUser => _shouldCenterOnUser;
  Destination? get currentDestination => _currentDestination;
  bool get hasDestination => _currentDestination != null;
  bool get isDestinationUpdating => _isDestinationUpdating;
  String? get destinationError => _destinationError;
  Route? get currentRoute => _currentRoute;
  bool get hasRoute => _currentRoute != null;
  bool get isCalculatingRoute => _isCalculatingRoute;
  ErrorState? get routingError => _routingError;

  Future<void> retryConnectivityCheck() {
    _retryToken++;
    _hasConnectivity = null;
    _tileError = null;
    _networkError = null;
    _mapReady = false;
    _isCheckingConnectivity = true;
    notifyListeners();
    _connectivityFuture = _probeConnectivity();
    return _connectivityFuture!;
  }

  void _beginConnectivityProbe() {
    _isCheckingConnectivity = true;
    _connectivityFuture = _probeConnectivity();
  }

  Future<void> _probeConnectivity() async {
    try {
      final response = await _httpClient
          .head(Uri.parse('https://tile.openstreetmap.org/0/0/0.png'))
          .timeout(const Duration(seconds: 3));
      _hasConnectivity = response.statusCode == 200;
      if (_hasConnectivity == true) {
        _tileError = null;
        _networkError = null;
      } else {
        final isRateLimited = response.statusCode == HttpStatus.tooManyRequests;
        final serverMessage = isRateLimited
            ? 'We have hit the OpenStreetMap rate limit. Please try again shortly.'
            : 'Tile server responded with status ${response.statusCode}.';
        _tileError = ErrorState.tiles(
          isRateLimited ? TileIssueCode.rateLimited : TileIssueCode.serverError,
          serverMessage,
        );
        _networkError = ErrorState.network(
          isRateLimited
              ? NetworkErrorCode.rateLimited
              : NetworkErrorCode.serverError,
          serverMessage,
        );
      }
    } on TimeoutException catch (error) {
      _hasConnectivity = false;
      final details = error.message ?? 'request exceeded 3 seconds';
      _tileError = ErrorState.tiles(
        TileIssueCode.timeout,
        'Tile server timeout: $details',
      );
      _networkError = ErrorState.network(
        NetworkErrorCode.timeout,
        'OpenStreetMap tiles timed out. Retry in a moment.',
      );
    } catch (error) {
      _hasConnectivity = false;
      _tileError = ErrorState.tiles(
        TileIssueCode.network,
        'Tile load failed: $error',
      );
      _networkError = ErrorState.network(
        NetworkErrorCode.offline,
        'No internet connection detected. Showing cached tiles when available.',
      );
    } finally {
      _isCheckingConnectivity = false;
      notifyListeners();
    }
  }

  Future<void> initializeLocation() async {
    final status = await _locationService.checkPermission();
    _applyPermissionStatus(status);
    await _refreshServiceStatus();
    if (_hasLocationPermission && _isLocationServiceEnabled) {
      await _startLocationTracking();
    } else {
      notifyListeners();
    }
  }

  Future<LocationPermissionStatus> requestLocationAccess() async {
    if (_isRequestingPermission) {
      return _hasLocationPermission
          ? LocationPermissionStatus.granted
          : _permissionDeniedForever
              ? LocationPermissionStatus.deniedForever
              : LocationPermissionStatus.denied;
    }

    _isRequestingPermission = true;
    notifyListeners();
    try {
      final status = await _locationService.requestPermission();
      _applyPermissionStatus(status);
      await _refreshServiceStatus();
      if (_hasLocationPermission && _isLocationServiceEnabled) {
        await _startLocationTracking();
      }
      if (!_hasLocationPermission) {
        _locationError = _permissionDeniedForever
            ? ErrorState.location(
                LocationIssueCode.permissionDeniedForever,
                'Location permission permanently denied. Enable permissions from Settings.',
                canRetry: false,
              )
            : ErrorState.location(
                LocationIssueCode.permissionDenied,
                'Location permission denied. We cannot display your position.',
              );
      }
      return status;
    } finally {
      _isRequestingPermission = false;
      notifyListeners();
    }
  }

  Future<void> fetchCurrentLocation() async {
    if (!_hasLocationPermission || !_isLocationServiceEnabled) {
      return;
    }
    _isLocationLoading = true;
    notifyListeners();
    try {
      final location = await _locationService.getCurrentLocation();
      _handleLocationUpdate(location, shouldCenter: true);
    } on LocationServiceException catch (error) {
      _applyLocationError(error);
    } finally {
      _isLocationLoading = false;
      notifyListeners();
    }
  }

  void updateLocation(UserLocation location) {
    _handleLocationUpdate(location);
  }

  void acknowledgeUserCentered() {
    if (!_shouldCenterOnUser) {
      return;
    }
    _shouldCenterOnUser = false;
    _hasCenteredOnUser = true;
    notifyListeners();
  }

  void clearLocationError() {
    if (_locationError == null) {
      return;
    }
    _locationError = null;
    notifyListeners();
  }

  void setMapReady() {
    if (_mapReady) {
      return;
    }
    _mapReady = true;
    notifyListeners();
  }

  void updateCamera(LatLng center, double zoom) {
    _center = center;
    _zoom = zoom;
  }

  void reportTileError(Object error) {
    if (error is TileFetchException) {
      if (error.code == TileIssueCode.cacheHit) {
        if (error.networkCode != null) {
          _networkError = ErrorState.network(
            error.networkCode!,
            error.message,
            canRetry: error.retryable,
          );
          notifyListeners();
        }
        return;
      }
      _tileError = ErrorState.tiles(
        error.code,
        error.message,
        canRetry: error.retryable,
      );
      if (error.networkCode != null) {
        _networkError = ErrorState.network(
          error.networkCode!,
          error.message,
          canRetry: error.retryable,
        );
      }
    } else {
      _tileError = ErrorState.tiles(
        TileIssueCode.unknown,
        'Tile load failed: $error',
      );
    }
    notifyListeners();
  }

  void clearTileError() {
    if (_tileError == null) {
      return;
    }
    _tileError = null;
    notifyListeners();
  }

  void clearNetworkError() {
    if (_networkError == null) {
      return;
    }
    _networkError = null;
    notifyListeners();
  }

  void setDestination(Destination destination) {
    _startDestinationUpdate();
    _currentDestination = destination;
    _finalizeDestinationUpdate();
    _calculateRouteForDestination(clearExistingRoute: true);
  }

  void clearDestination() {
    if (_currentDestination == null && _destinationError == null) {
      return;
    }
    _startDestinationUpdate();
    _currentDestination = null;
    _finalizeDestinationUpdate();
    clearRoute();
  }

  void setDestinationError(String message) {
    _destinationError = message;
    notifyListeners();
  }

  void clearDestinationError() {
    if (_destinationError == null) {
      return;
    }
    _destinationError = null;
    notifyListeners();
  }

  void setRoute(Route route) {
    _currentRoute = route;
    _routingError = null;
    _isCalculatingRoute = false;
    notifyListeners();
  }

  void clearRoute({bool notify = true}) {
    final hadState =
        _currentRoute != null || _routingError != null || _isCalculatingRoute;
    _currentRoute = null;
    _routingError = null;
    _isCalculatingRoute = false;
    _routeRequestId++;
    if (notify && hadState) {
      notifyListeners();
    }
  }

  void setRoutingError(ErrorState error) {
    _currentRoute = null;
    _routingError = error;
    _isCalculatingRoute = false;
    notifyListeners();
  }

  void clearRoutingError() {
    if (_routingError == null) {
      return;
    }
    _routingError = null;
    notifyListeners();
  }

  void retryRouteCalculation() {
    if (_currentDestination == null) {
      return;
    }
    _calculateRouteForDestination(clearExistingRoute: true);
  }

  @override
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    if (_ownsRoutingService) {
      _routingService.dispose();
    }
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshServiceStatus() async {
    final enabled = await _locationService.isLocationServiceEnabled();
    _isLocationServiceEnabled = enabled;
    if (!enabled) {
      _locationError = ErrorState.location(
        LocationIssueCode.serviceDisabled,
        'Location services are disabled. Enable GPS to view your position.',
      );
    } else if (_locationError?.locationCode ==
        LocationIssueCode.serviceDisabled) {
      _locationError = null;
    }
  }

  Future<void> _startLocationTracking() async {
    if (_locationSubscription != null) {
      await _locationSubscription!.cancel();
      _locationSubscription = null;
    }
    _isLocationLoading = true;
    _locationError = null;
    notifyListeners();
    try {
      final initial = await _locationService.getCurrentLocation();
      _handleLocationUpdate(initial, shouldCenter: true, notify: false);
    } on LocationServiceException catch (error) {
      _applyLocationError(error);
    } finally {
      _isLocationLoading = false;
      notifyListeners();
    }

    _locationSubscription = _locationService.getLocationStream().listen(
      (location) {
        _handleLocationUpdate(location);
        notifyListeners();
      },
      onError: (error) {
        if (error is LocationServiceException) {
          _applyLocationError(error, notify: true);
        } else {
          _locationError = ErrorState.location(
            LocationIssueCode.unknown,
            'Unexpected location error: $error',
          );
          notifyListeners();
        }
      },
    );
  }

  void _handleLocationUpdate(UserLocation location,
      {bool shouldCenter = false, bool notify = true}) {
    final isFirstUpdate = _currentLocation == null;
    _currentLocation = location;
    _locationError = null;
    _isLocationServiceEnabled = true;
    if ((shouldCenter || isFirstUpdate) && !_hasCenteredOnUser) {
      _shouldCenterOnUser = true;
      _center = location.toLatLng();
    }
    if (notify) {
      notifyListeners();
    }
    if (_currentDestination != null && !_isCalculatingRoute && !hasRoute) {
      _calculateRouteForDestination();
    }
  }

  void _applyPermissionStatus(LocationPermissionStatus status) {
    _hasLocationPermission = status == LocationPermissionStatus.granted;
    _permissionDeniedForever = status == LocationPermissionStatus.deniedForever;
  }

  void _applyLocationError(LocationServiceException error,
      {bool notify = false}) {
    switch (error.code) {
      case LocationServiceErrorCode.permissionDenied:
        _hasLocationPermission = false;
        _locationError = ErrorState.location(
          LocationIssueCode.permissionDenied,
          'Location permission denied. Enable access to see your position.',
        );
        break;
      case LocationServiceErrorCode.permissionPermanentlyDenied:
        _permissionDeniedForever = true;
        _locationError = ErrorState.location(
          LocationIssueCode.permissionDeniedForever,
          'Location permissions permanently denied. Update settings to continue.',
          canRetry: false,
        );
        break;
      case LocationServiceErrorCode.serviceDisabled:
        _isLocationServiceEnabled = false;
        _locationError = ErrorState.location(
          LocationIssueCode.serviceDisabled,
          'Location services are disabled. Turn on GPS and try again.',
        );
        break;
      case LocationServiceErrorCode.timeout:
        _locationError = ErrorState.location(
          LocationIssueCode.timeout,
          'Fetching your location is taking longer than expected. Please try again.',
        );
        break;
      case LocationServiceErrorCode.unknown:
        _locationError = ErrorState.location(
          LocationIssueCode.unknown,
          'We ran into a problem retrieving your location. Retry in a moment.',
        );
        break;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void _startDestinationUpdate() {
    _isDestinationUpdating = true;
    _destinationError = null;
    notifyListeners();
  }

  void _finalizeDestinationUpdate() {
    _isDestinationUpdating = false;
    notifyListeners();
  }

  void _calculateRouteForDestination({bool clearExistingRoute = false}) {
    final destination = _currentDestination;
    if (destination == null) {
      return;
    }

    final requestId =
        _prepareRouteRequest(clearExistingRoute: clearExistingRoute);
    final location = _currentLocation;

    if (location == null) {
      setRoutingError(
        ErrorState.routing(
          RoutingIssueCode.startLocationUnavailable,
          'Current location unavailable. Enable location services and try again.',
          canRetry: true,
        ),
      );
      return;
    }

    _isCalculatingRoute = true;
    notifyListeners();

    _routingService.calculateRoute(location, destination).then((route) {
      if (_routeRequestId != requestId) {
        return;
      }
      setRoute(route);
    }).catchError((error) {
      if (_routeRequestId != requestId) {
        return;
      }
      final routingError = error is RoutingException
          ? _mapRoutingException(error)
          : ErrorState.routing(
              RoutingIssueCode.unknown,
              'Route calculation failed. Please try again.',
            );
      setRoutingError(routingError);
    });
  }

  int _prepareRouteRequest({required bool clearExistingRoute}) {
    if (clearExistingRoute) {
      final hadState =
          _currentRoute != null || _routingError != null || _isCalculatingRoute;
      _currentRoute = null;
      _routingError = null;
      _isCalculatingRoute = false;
      _routeRequestId++;
      if (hadState) {
        notifyListeners();
      }
      return _routeRequestId;
    }

    _routingError = null;
    _isCalculatingRoute = false;
    _routeRequestId++;
    return _routeRequestId;
  }

  ErrorState _mapRoutingException(RoutingException error) {
    switch (error.code) {
      case RoutingIssueCode.networkUnavailable:
        return ErrorState.routing(
          RoutingIssueCode.networkUnavailable,
          'No internet connection detected. Check your connection and try again.',
        );
      case RoutingIssueCode.timeout:
        return ErrorState.routing(
          RoutingIssueCode.timeout,
          'Route calculation timed out. Please try again.',
        );
      case RoutingIssueCode.rateLimited:
        return ErrorState.routing(
          RoutingIssueCode.rateLimited,
          'Routing service is rate limited right now. Retry in a few moments.',
        );
      case RoutingIssueCode.serverError:
        return ErrorState.routing(
          RoutingIssueCode.serverError,
          'Routing service returned an error. Please try again shortly.',
        );
      case RoutingIssueCode.configuration:
        return ErrorState.routing(
          RoutingIssueCode.configuration,
          'Routing configuration is missing. Contact support to resolve this issue.',
          canRetry: false,
        );
      case RoutingIssueCode.responseMalformed:
        return ErrorState.routing(
          RoutingIssueCode.responseMalformed,
          'Received an unexpected response from the routing service. Retry shortly.',
        );
      case RoutingIssueCode.startLocationUnavailable:
        return ErrorState.routing(
          RoutingIssueCode.startLocationUnavailable,
          'Current location unavailable. Enable location services and try again.',
        );
      case RoutingIssueCode.unknown:
        return ErrorState.routing(
          RoutingIssueCode.unknown,
          error.message,
        );
    }
  }
}
