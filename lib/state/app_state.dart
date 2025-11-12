import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/destination.dart';
import '../models/user_location.dart';
import '../services/location_service.dart';

class AppState extends ChangeNotifier {
  AppState({http.Client? httpClient, LocationService? locationService})
      : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _locationService = locationService ?? LocationService() {
    _beginConnectivityProbe();
  }

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final LocationService _locationService;
  StreamSubscription<UserLocation>? _locationSubscription;

  static const LatLng defaultCenter = LatLng(37.7749, -122.4194);
  static const double defaultZoom = 15;
  static const double minZoomLevel = 5;
  static const double maxZoomLevel = 18;

  LatLng _center = defaultCenter;
  double _zoom = defaultZoom;
  bool _mapReady = false;
  bool _hasTileError = false;
  String? _tileErrorMessage;
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
  String? _locationError;
  bool _shouldCenterOnUser = false;
  bool _hasCenteredOnUser = false;
  Destination? _currentDestination;
  bool _isDestinationUpdating = false;
  String? _destinationError;

  LatLng get center => _center;
  double get zoom => _zoom;
  double get minZoom => minZoomLevel;
  double get maxZoom => maxZoomLevel;
  bool get isMapReady => _mapReady;
  bool get hasTileError => _hasTileError;
  String? get tileErrorMessage => _tileErrorMessage;
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
  String? get locationError => _locationError;
  bool get shouldCenterOnUser => _shouldCenterOnUser;
  Destination? get currentDestination => _currentDestination;
  bool get hasDestination => _currentDestination != null;
  bool get isDestinationUpdating => _isDestinationUpdating;
  String? get destinationError => _destinationError;

  Future<void> retryConnectivityCheck() {
    _retryToken++;
    _hasConnectivity = null;
    _hasTileError = false;
    _tileErrorMessage = null;
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
        _hasTileError = false;
        _tileErrorMessage = null;
      } else {
        _hasTileError = true;
        _tileErrorMessage =
            'Tile server responded with status ${response.statusCode}.';
      }
    } on TimeoutException catch (error) {
      _hasConnectivity = false;
      _hasTileError = true;
      _tileErrorMessage =
          'Tile server timeout: ${error.message ?? 'request exceeded 3 seconds'}';
    } catch (error) {
      _hasConnectivity = false;
      _hasTileError = true;
      _tileErrorMessage = 'Network error: $error';
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
            ? 'Location permission permanently denied. Enable permissions from Settings.'
            : 'Location permission denied. We cannot display your position.';
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
    _hasTileError = true;
    _tileErrorMessage = 'Tile load failed: $error';
    notifyListeners();
  }

  void clearTileError() {
    if (!_hasTileError) {
      return;
    }
    _hasTileError = false;
    _tileErrorMessage = null;
    notifyListeners();
  }

  void setDestination(Destination destination) {
    _startDestinationUpdate();
    _currentDestination = destination;
    _finalizeDestinationUpdate();
  }

  void clearDestination() {
    if (_currentDestination == null && _destinationError == null) {
      return;
    }
    _startDestinationUpdate();
    _currentDestination = null;
    _finalizeDestinationUpdate();
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

  @override
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshServiceStatus() async {
    final enabled = await _locationService.isLocationServiceEnabled();
    _isLocationServiceEnabled = enabled;
    if (!enabled) {
      _locationError = 'Location services are disabled. Enable GPS to view your position.';
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
          _locationError = 'Unexpected location error: $error';
          notifyListeners();
        }
      },
    );
  }

  void _handleLocationUpdate(UserLocation location, {bool shouldCenter = false, bool notify = true}) {
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
  }

  void _applyPermissionStatus(LocationPermissionStatus status) {
    _hasLocationPermission = status == LocationPermissionStatus.granted;
    _permissionDeniedForever = status == LocationPermissionStatus.deniedForever;
  }

  void _applyLocationError(LocationServiceException error, {bool notify = false}) {
    switch (error.code) {
      case LocationServiceErrorCode.permissionDenied:
        _hasLocationPermission = false;
        _locationError = 'Location permission denied. Enable access to see your position.';
        break;
      case LocationServiceErrorCode.permissionPermanentlyDenied:
        _permissionDeniedForever = true;
        _locationError = 'Location permissions permanently denied. Update settings to continue.';
        break;
      case LocationServiceErrorCode.serviceDisabled:
        _locationError = 'Location services are disabled. Turn on GPS and try again.';
        _isLocationServiceEnabled = false;
        break;
      case LocationServiceErrorCode.timeout:
        _locationError = 'Fetching your location is taking longer than expected. Please try again.';
        break;
      case LocationServiceErrorCode.unknown:
        _locationError = 'We ran into a problem retrieving your location. Retry in a moment.';
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
}