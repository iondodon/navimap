import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static final LatLngBounds _worldBounds = LatLngBounds(
    const LatLng(-85.0, -180.0),
    const LatLng(85.0, 180.0),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final connectivity = appState.connectivityStatus;
          final showMap = connectivity == true;
          final showOffline = connectivity == false;

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
              if (appState.isCheckingConnectivity || (showMap && !appState.isMapReady))
                const _MapLoadingOverlay(),
              if (appState.hasTileError && showMap)
                _TileErrorBanner(
                  message: appState.tileErrorMessage ?? 'Tile loading issue detected.',
                  onRetry: () {
                    appState.clearTileError();
                    appState.retryConnectivityCheck();
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(BuildContext context, AppState appState) {
    return FlutterMap(
      key: ValueKey('flutter-map-${appState.retryToken}'),
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
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.navimap.app',
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
      ],
    );
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
                appState.retryConnectivityCheck();
              },
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
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

class _TileErrorBanner extends StatelessWidget {
  const _TileErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

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
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}