import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/destination.dart';
import '../models/route.dart';
import '../models/user_location.dart';

class RoutingException implements Exception {
  RoutingException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause == null ? message : '$message (cause: $cause)';
}

class RoutingService {
  RoutingService({
    http.Client? httpClient,
    String? graphhopperApiKey,
    Duration requestTimeout = const Duration(seconds: 5),
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _graphhopperApiKey =
            graphhopperApiKey ?? Platform.environment[_graphhopperApiKeyEnvKey],
        _requestTimeout = requestTimeout;

  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  static const String _graphhopperBaseUrl = 'https://graphhopper.com/api/1';
  static const String _graphhopperApiKeyEnvKey = 'GRAPHHOPPER_API_KEY';

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _requestTimeout;
  final String? _graphhopperApiKey;

  Future<Route> calculateRoute(
      UserLocation start, Destination destination) async {
    final timeBudget = _splitTimeoutBudget(_requestTimeout);
    late RoutingException primaryError;

    try {
      return await _fetchRouteFromOSRM(
        start,
        destination,
        timeBudget.primary,
      );
    } on RoutingException catch (error) {
      primaryError = error;
    } catch (error) {
      throw RoutingException('Route calculation failed', cause: error);
    }

    if (timeBudget.fallback <= Duration.zero) {
      throw RoutingException(
        'Route calculation failed after OSRM error: ${primaryError.message}',
        cause: primaryError,
      );
    }

    try {
      return await _fetchRouteFromGraphHopper(
        start,
        destination,
        timeBudget.fallback,
      );
    } on RoutingException catch (graphhopperError) {
      throw RoutingException(
        'Route calculation failed after OSRM (${primaryError.message}) '
        'and GraphHopper (${graphhopperError.message}) errors',
        cause: graphhopperError,
      );
    }
  }

  Future<Route> _fetchRouteFromOSRM(
    UserLocation start,
    Destination destination,
    Duration timeout,
  ) async {
    if (timeout <= Duration.zero) {
      throw RoutingException('OSRM request aborted: no time remaining');
    }

    final uri = Uri.parse(
      '$_osrmBaseUrl/route/v1/driving/'
      '${_formatLonLat(start.longitude, start.latitude)};'
      '${_formatLonLat(destination.longitude, destination.latitude)}',
    ).replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'alternatives': 'false',
        'steps': 'false',
      },
    );

    late http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(timeout);
    } on SocketException catch (error) {
      throw RoutingException('OSRM request failed: network error',
          cause: error);
    } on TimeoutException catch (error) {
      throw RoutingException(
        'OSRM request timed out after ${_formatTimeout(timeout)}',
        cause: error,
      );
    } on HttpException catch (error) {
      throw RoutingException('OSRM request failed: HTTP error', cause: error);
    }

    if (response.statusCode != HttpStatus.ok) {
      throw RoutingException(
          'OSRM request failed with status ${response.statusCode}');
    }

    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw RoutingException('OSRM response was not valid JSON', cause: error);
    }
    final code = payload['code'] as String?;
    if (code != 'Ok') {
      throw RoutingException('OSRM returned error code: ${code ?? 'unknown'}');
    }

    final routes = payload['routes'];
    if (routes is! List || routes.isEmpty) {
      throw RoutingException('OSRM response missing routes');
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map<String, dynamic>) {
      throw RoutingException('OSRM route payload is malformed');
    }

    final distance = (firstRoute['distance'] as num?)?.toDouble();
    final duration = (firstRoute['duration'] as num?)?.toDouble();
    if (distance == null || duration == null) {
      throw RoutingException('OSRM route payload missing distance or duration');
    }

    final geometry = firstRoute['geometry'];
    final points = _parseGeometryPoints(geometry);
    if (points.isEmpty) {
      throw RoutingException('OSRM route contains no coordinates');
    }

    final geometryString = _normalizeGeometryString(geometry);

    return Route(
      points: points,
      distanceMeters: distance,
      durationSeconds: duration,
      geometry: geometryString,
    );
  }

  Future<Route> _fetchRouteFromGraphHopper(
    UserLocation start,
    Destination destination,
    Duration timeout,
  ) async {
    if (timeout <= Duration.zero) {
      throw RoutingException('GraphHopper request aborted: no time remaining');
    }

    final apiKey = _graphhopperApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw RoutingException('GraphHopper API key is not configured');
    }

    final uri = Uri.parse('$_graphhopperBaseUrl/route').replace(
      queryParameters: {
        'point': [
          _formatLatLon(start.latitude, start.longitude),
          _formatLatLon(destination.latitude, destination.longitude),
        ],
        'vehicle': 'car',
        'points_encoded': 'false',
        'calc_points': 'true',
        'instructions': 'false',
        'locale': 'en',
        'key': apiKey,
      },
    );

    late http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(timeout);
    } on SocketException catch (error) {
      throw RoutingException('GraphHopper request failed: network error',
          cause: error);
    } on TimeoutException catch (error) {
      throw RoutingException(
        'GraphHopper request timed out after ${_formatTimeout(timeout)}',
        cause: error,
      );
    } on HttpException catch (error) {
      throw RoutingException('GraphHopper request failed: HTTP error',
          cause: error);
    }

    if (response.statusCode != HttpStatus.ok) {
      throw RoutingException(
          'GraphHopper request failed with status ${response.statusCode}');
    }

    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw RoutingException('GraphHopper response was not valid JSON',
          cause: error);
    }

    final paths = payload['paths'];
    if (paths is! List || paths.isEmpty) {
      throw RoutingException('GraphHopper response missing paths');
    }

    final firstPath = paths.first;
    if (firstPath is! Map<String, dynamic>) {
      throw RoutingException('GraphHopper path payload is malformed');
    }

    final distance = (firstPath['distance'] as num?)?.toDouble();
    final durationMillis = (firstPath['time'] as num?)?.toDouble();
    if (distance == null || durationMillis == null) {
      throw RoutingException(
          'GraphHopper path missing distance or duration fields');
    }

    final geometry = firstPath['points'];
    final points = _parseGeometryPoints(geometry);
    if (points.isEmpty) {
      throw RoutingException('GraphHopper path contains no coordinates');
    }

    final geometryString = _normalizeGeometryString(geometry);

    return Route(
      points: points,
      distanceMeters: distance,
      durationSeconds: durationMillis / 1000,
      geometry: geometryString,
    );
  }

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  static String _formatLonLat(double longitude, double latitude) {
    return '${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}';
  }

  static String _formatLatLon(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
  }

  static List<LatLng> _parseGeometryPoints(Object? geometry) {
    if (geometry is Map<String, dynamic>) {
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) {
        return const <LatLng>[];
      }

      final points = <LatLng>[];
      for (final coordinate in coordinates) {
        if (coordinate is! List || coordinate.length < 2) {
          continue;
        }
        final lon = coordinate[0];
        final lat = coordinate[1];
        if (lon is num && lat is num) {
          points.add(LatLng(lat.toDouble(), lon.toDouble()));
        }
      }
      return points;
    }
    return const <LatLng>[];
  }

  static String? _normalizeGeometryString(Object? geometry) {
    if (geometry == null) {
      return null;
    }
    if (geometry is String) {
      return geometry;
    }
    try {
      return jsonEncode(geometry);
    } catch (_) {
      return null;
    }
  }

  ({Duration primary, Duration fallback}) _splitTimeoutBudget(Duration budget) {
    final totalMillis = math.max(budget.inMilliseconds, 0);
    if (totalMillis == 0) {
      return (primary: Duration.zero, fallback: Duration.zero);
    }

    const primaryShare = 0.6;

    if (totalMillis <= 1) {
      return (
        primary: Duration(milliseconds: totalMillis),
        fallback: Duration.zero
      );
    }

    var primaryMillis = (totalMillis * primaryShare).round();
    primaryMillis = math.max(1, math.min(primaryMillis, totalMillis - 1));
    final fallbackMillis = totalMillis - primaryMillis;

    return (
      primary: Duration(milliseconds: primaryMillis),
      fallback: Duration(milliseconds: fallbackMillis),
    );
  }

  static String _formatTimeout(Duration timeout) {
    if (timeout.inMilliseconds <= 0) {
      return '0.0 seconds';
    }
    if (timeout.inMilliseconds % 1000 == 0) {
      return '${timeout.inSeconds} seconds';
    }
    final seconds = timeout.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)} seconds';
  }
}
