import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/destination.dart';
import '../models/route.dart' as nav;
import '../services/location_service.dart';
import '../services/osm_tile_provider.dart';
import '../state/app_state.dart';
import '../state/error_state.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.tileProvider});

  final TileProvider? tileProvider;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static final LatLngBounds _worldBounds = LatLngBounds(
    const LatLng(-85.0, -180.0),
    const LatLng(85.0, 180.0),
  );

  final MapController _mapController = MapController();
  OsmTileProvider? _managedTileProvider;
  bool _initialized = false;
  bool _hasPromptedPermission = false;
  bool _isPermissionDialogOpen = false;
  _TapFeedbackData? _tapFeedback;
  Timer? _tapFeedbackTimer;
  int _destinationMarkerVersion = 0;

  @override
  void initState() {
    super.initState();
    if (widget.tileProvider == null) {
      _managedTileProvider = OsmTileProvider(
        onError: (error) {
          if (!mounted) {
            return;
          }
          context.read<AppState>().reportTileError(error);
        },
      );
    }
  }

  @override
  void dispose() {
    _tapFeedbackTimer?.cancel();
    _managedTileProvider?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tileProvider != widget.tileProvider) {
      if (widget.tileProvider == null) {
        _managedTileProvider ??= OsmTileProvider(
          onError: (error) {
            if (!mounted) {
              return;
            }
            context.read<AppState>().reportTileError(error);
          },
        );
      } else {
        _managedTileProvider?.dispose();
        _managedTileProvider = null;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().initializeLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          _handleSideEffects(appState);

          final bool? connectivity = appState.connectivityStatus;
          final bool showMap = connectivity == true;
          final bool showOffline = connectivity == false;
          final ErrorState? tileError = appState.tileError;
          final ErrorState? networkError = appState.networkError;
          final ErrorState? locationError = appState.locationError;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (showMap)
                _buildMap(context, appState)
              else
                _buildStatusPlaceholder(
                  context,
                  appState,
                  showOffline: showOffline,
                ),
              if (showMap) _buildTapFeedbackOverlay(),
              if (showMap) _buildOsmAttribution(),
              if (appState.isCheckingConnectivity ||
                  (showMap && !appState.isMapReady))
                const _MapLoadingOverlay(),
              if (showMap && networkError != null)
                _NetworkStatusBanner(
                  message: networkError.message,
                  canRetry: networkError.canRetry,
                  onRetry: networkError.canRetry
                      ? () {
                          appState.clearNetworkError();
                          appState.retryConnectivityCheck();
                        }
                      : null,
                ),
              if (tileError != null && showMap)
                _TileErrorBanner(
                  message: tileError.message,
                  onRetry: tileError.canRetry
                      ? () {
                          appState.clearTileError();
                          appState.retryConnectivityCheck();
                        }
                      : null,
                ),
              if (appState.isLocationLoading)
                const _InlineStatusBanner(
                  message: 'Acquiring your location…',
                  icon: Icons.gps_fixed,
                ),
              if (locationError != null)
                _LocationErrorBanner(
                  message: locationError.message,
                  onRetry: locationError.canRetry &&
                          appState.hasLocationPermission &&
                          appState.isLocationServiceEnabled
                      ? () {
                          appState.fetchCurrentLocation();
                        }
                      : null,
                  onSettings: appState.permissionDeniedForever ||
                          !appState.isLocationServiceEnabled
                      ? _openSystemSettings
                      : null,
                ),
              if (!appState.hasLocationPermission)
                _PermissionHintBanner(
                  permissionDeniedForever: appState.permissionDeniedForever,
                  onGrant: () {
                    _showPermissionDialog(appState);
                  },
                  onOpenSettings: _openSystemSettings,
                ),
              if (showMap) ..._buildRouteStatusOverlays(appState),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(BuildContext context, AppState appState) {
    final locationLayers = _buildLocationLayers(appState);
    final routeLayer = _buildRouteLayer(appState);
    final destinationLayer = _buildDestinationLayer(appState);
    final tileProvider =
        widget.tileProvider ?? _managedTileProvider ?? NetworkTileProvider();

    return FlutterMap(
      key: ValueKey('flutter-map-${appState.retryToken}'),
      mapController: _mapController,
      options: MapOptions(
        initialCenter: appState.center,
        initialZoom: appState.zoom,
        minZoom: appState.minZoom,
        maxZoom: appState.maxZoom,
        cameraConstraint: CameraConstraint.contain(bounds: _worldBounds),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.flingAnimation,
        ),
        onMapReady: appState.setMapReady,
        onPositionChanged: (position, hasGesture) {
          if (!hasGesture) {
            return;
          }
          appState.updateCamera(position.center, position.zoom);
        },
        onTap: (tapPosition, latLng) {
          _onMapTap(appState, tapPosition, latLng);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.navimap.app',
          tileProvider: tileProvider,
          tileBuilder: (context, tileWidget, tile) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: tileWidget,
            );
          },
          errorTileCallback: (tile, error, stackTrace) {
            appState.reportTileError(error);
          },
        ),
        ...locationLayers,
        if (routeLayer != null) routeLayer,
        if (destinationLayer != null) destinationLayer,
      ],
    );
  }

  List<Widget> _buildLocationLayers(AppState appState) {
    final location = appState.currentLocation;
    if (location == null) {
      return const <Widget>[];
    }

    final accuracy = location.accuracy;
    final widgets = <Widget>[];

    if (accuracy != null && accuracy > 0) {
      widgets.add(
        CircleLayer(
          circles: [
            CircleMarker(
              point: location.toLatLng(),
              color: Colors.blue.withOpacity(0.18),
              borderColor: Colors.blue.withOpacity(0.32),
              borderStrokeWidth: 2,
              useRadiusInMeter: true,
              radius: accuracy.clamp(10, 100.0).toDouble(),
            ),
          ],
        ),
      );
    }

    widgets.add(
      MarkerLayer(
        markers: [
          Marker(
            point: location.toLatLng(),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: const _BlueDotMarker(),
          ),
        ],
      ),
    );

    return widgets;
  }

  Widget _buildStatusPlaceholder(
    BuildContext context,
    AppState appState, {
    required bool showOffline,
  }) {
    final title = showOffline ? 'Offline Mode' : 'Loading Map';
    final description = showOffline
        ? 'We could not reach the map tiles. We will show saved routes once they are available offline.'
        : 'Attempting to reach OpenStreetMap servers. This should only take a moment.';
    final icon = showOffline ? Icons.wifi_off : Icons.map_outlined;

    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.black54),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
          ),
          if (showOffline) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                appState.clearTileError();
                appState.clearNetworkError();
                appState.retryConnectivityCheck();
              },
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOsmAttribution() {
    return const Positioned(
      right: 12,
      bottom: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.fromRGBO(0, 0, 0, 0.6),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildDestinationLayer(AppState appState) {
    final destination = appState.currentDestination;
    if (destination == null) {
      return null;
    }

    final markerKey = ValueKey(
        'destination-$_destinationMarkerVersion-${destination.latitude}-${destination.longitude}');

    return MarkerLayer(
      markers: [
        Marker(
          point: destination.toLatLng(),
          width: 52,
          height: 52,
          alignment: Alignment.topCenter,
          child: _DestinationMarker(markerKey: markerKey),
        ),
      ],
    );
  }

  Widget? _buildRouteLayer(AppState appState) {
    final route = appState.currentRoute;
    if (route == null || route.points.length < 2) {
      return null;
    }

    return PolylineLayer(
      polylines: [
        Polyline(
          points: route.points,
          strokeWidth: 4,
          color: Colors.blueAccent,
          borderStrokeWidth: 1.5,
          borderColor: Colors.white.withOpacity(0.6),
        ),
      ],
    );
  }

  List<Widget> _buildRouteStatusOverlays(AppState appState) {
    final overlays = <Widget>[];
    final routingError = appState.routingError;
    if (routingError != null) {
      final retryAction = routingError.canRetry
          ? () {
              appState.clearRoutingError();
              appState.retryRouteCalculation();
            }
          : null;
      overlays.add(
        Positioned(
          left: 16,
          right: 16,
          top: 72,
          child: _RouteStatusBanner.error(
            message: routingError.message,
            onDismiss: appState.clearRoutingError,
            onRetry: retryAction,
          ),
        ),
      );
    } else if (appState.isCalculatingRoute) {
      overlays.add(
        const Positioned(
          left: 16,
          right: 16,
          top: 72,
          child: _RouteStatusBanner.loading(),
        ),
      );
    }

    final route = appState.currentRoute;
    if (route != null && routingError == null) {
      overlays.add(
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: _RouteInfoCard(
              route: route, isLoading: appState.isCalculatingRoute),
        ),
      );
    }

    return overlays;
  }

  void _handleSideEffects(AppState appState) {
    if (appState.shouldCenterOnUser && appState.isMapReady) {
      final location = appState.currentLocation;
      if (location != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(location.toLatLng(), appState.zoom);
          appState.acknowledgeUserCentered();
        });
      }
    }

    if (_shouldShowPermissionDialog(appState)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPermissionDialog(appState);
      });
    }
  }

  bool _shouldShowPermissionDialog(AppState appState) {
    if (appState.hasLocationPermission ||
        appState.permissionDeniedForever ||
        _isPermissionDialogOpen) {
      return false;
    }
    return !_hasPromptedPermission;
  }

  Future<void> _showPermissionDialog(AppState appState) async {
    if (_isPermissionDialogOpen || appState.hasLocationPermission) {
      return;
    }
    _isPermissionDialogOpen = true;
    _hasPromptedPermission = true;

    await showDialog<LocationPermissionStatus?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable Location Access'),
          content: const Text(
            'NaviMap needs your location to show routes and keep you oriented on the map. We use GPS only when you have the app open.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(LocationPermissionStatus.denied);
              },
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final status = await appState.requestLocationAccess();
                if (!mounted) {
                  return;
                }
                navigator.pop(status);
              },
              child: const Text('Allow'),
            ),
          ],
        );
      },
    );

    _isPermissionDialogOpen = false;
  }

  static Future<void> _openSystemSettings() async {
    await Geolocator.openAppSettings();
    await Geolocator.openLocationSettings();
  }

  void _onMapTap(AppState appState, TapPosition tapPosition, LatLng latLng) {
    final destination =
        Destination(latitude: latLng.latitude, longitude: latLng.longitude);
    final relative = tapPosition.relative;
    if (relative != null) {
      _registerTapFeedback(relative);
    } else {
      setState(() {
        _destinationMarkerVersion++;
      });
    }
    appState.setDestination(destination);
  }

  void _registerTapFeedback(Offset position) {
    _tapFeedbackTimer?.cancel();
    final timestamp = DateTime.now();
    setState(() {
      _destinationMarkerVersion++;
      _tapFeedback = _TapFeedbackData(position: position, timestamp: timestamp);
    });
    _tapFeedbackTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _tapFeedback = null;
      });
    });
  }

  Widget _buildTapFeedbackOverlay() {
    final data = _tapFeedback;
    if (data == null) {
      return const SizedBox.shrink();
    }

    const double diameter = 48;
    final offset = data.position;

    return Positioned(
      left: offset.dx - (diameter / 2),
      top: offset.dy - (diameter / 2),
      child: IgnorePointer(
        child: _TapRipple(key: ValueKey<DateTime>(data.timestamp)),
      ),
    );
  }
}

enum _RouteStatusVariant { loading, error }

class _RouteStatusBanner extends StatelessWidget {
  const _RouteStatusBanner.loading()
      : message = 'Calculating optimal route…',
        variant = _RouteStatusVariant.loading,
        onDismiss = null,
        onRetry = null;

  const _RouteStatusBanner.error({
    required this.message,
    this.onDismiss,
    this.onRetry,
  }) : variant = _RouteStatusVariant.error;

  final String message;
  final _RouteStatusVariant variant;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLoading = variant == _RouteStatusVariant.loading;
    final Color background = isLoading
        ? colorScheme.inverseSurface.withOpacity(0.92)
        : colorScheme.errorContainer;
    final Color foreground =
        isLoading ? colorScheme.onInverseSurface : colorScheme.onErrorContainer;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foreground),
                ),
              )
            else
              Icon(Icons.error_outline, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!isLoading && onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(color: foreground),
                ),
              ),
            if (!isLoading && onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close, color: foreground),
                tooltip: 'Dismiss',
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteInfoCard extends StatelessWidget {
  const _RouteInfoCard({required this.route, required this.isLoading});

  final nav.Route route;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceText = '${route.distanceKm.toStringAsFixed(1)} km';
    final durationText = _formatDuration(route.durationMin);

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.alt_route, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Driving route',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$distanceText • $durationText',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (remaining == 0) {
      return hours == 1 ? '1 hr' : '$hours hrs';
    }
    return '$hours hr $remaining min';
  }
}

class _MapLoadingOverlay extends StatelessWidget {
  const _MapLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.12),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker({
    required this.markerKey,
  });

  final Key markerKey;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: Column(
        key: markerKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            key: const ValueKey('destination-pin-icon'),
            color: Colors.red.shade600,
            size: 42,
            shadows: const [
              Shadow(
                  color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _TapRipple extends StatelessWidget {
  const _TapRipple({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      builder: (context, value, child) {
        final opacity = (1 - value).clamp(0.0, 1.0);
        final scale = 0.6 + (value * 0.6);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(0.16),
          border: Border.all(color: Colors.red.withOpacity(0.6), width: 2),
        ),
      ),
    );
  }
}

class _TapFeedbackData {
  _TapFeedbackData({required this.position, required this.timestamp});

  final Offset position;
  final DateTime timestamp;
}

class _TileErrorBanner extends StatelessWidget {
  const _TileErrorBanner({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry',
                        style: TextStyle(color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkStatusBanner extends StatelessWidget {
  const _NetworkStatusBanner({
    required this.message,
    required this.canRetry,
    this.onRetry,
  });

  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Material(
          color: Colors.black.withOpacity(0.82),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (canRetry && onRetry != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlueDotMarker extends StatelessWidget {
  const _BlueDotMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.shade500,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

class _InlineStatusBanner extends StatelessWidget {
  const _InlineStatusBanner({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withOpacity(0.75),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationErrorBanner extends StatelessWidget {
  const _LocationErrorBanner({
    required this.message,
    this.onRetry,
    this.onSettings,
  });

  final String message;
  final VoidCallback? onRetry;
  final Future<void> Function()? onSettings;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(12),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_off, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                if (onRetry != null || onSettings != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onRetry != null)
                        FilledButton(
                          onPressed: onRetry,
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.white),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      if (onRetry != null && onSettings != null)
                        const SizedBox(width: 12),
                      if (onSettings != null)
                        OutlinedButton(
                          onPressed: () {
                            onSettings?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white70),
                          ),
                          child: const Text(
                            'Open Settings',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionHintBanner extends StatelessWidget {
  const _PermissionHintBanner({
    required this.permissionDeniedForever,
    required this.onGrant,
    required this.onOpenSettings,
  });

  final bool permissionDeniedForever;
  final VoidCallback onGrant;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final message = permissionDeniedForever
        ? 'Location permissions are turned off. Enable them from Settings to see your position.'
        : 'Allow location access so we can show where you are on the map.';

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.blueGrey.shade900.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (!permissionDeniedForever)
                      FilledButton(
                        onPressed: onGrant,
                        child: const Text('Enable Location'),
                      ),
                    if (permissionDeniedForever)
                      FilledButton(
                        onPressed: () {
                          onOpenSettings();
                        },
                        child: const Text('Open Settings'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
