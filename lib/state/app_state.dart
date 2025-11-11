import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class AppState extends ChangeNotifier {
  AppState({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null {
    _beginConnectivityProbe();
  }

  final http.Client _httpClient;
  final bool _ownsHttpClient;

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

  @override
  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
    super.dispose();
  }
}