import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/destination.dart';
import '../models/route.dart';
import '../models/user_location.dart';
import '../state/error_state.dart';

class RoutingException implements Exception {
  RoutingException(
    this.message, {
    this.code = RoutingIssueCode.unknown,
    this.cause,
  });

  final String message;
  final RoutingIssueCode code;
  final Object? cause;

  @override
  String toString() {
    final codeLabel = code.name;
    if (cause == null) {
      return 'RoutingException($codeLabel, $message)';
    }
    return 'RoutingException($codeLabel, $message, cause: $cause)';
  }
}

class _FetchAttemptResult {
  const _FetchAttemptResult.success(this.route) : error = null;

  const _FetchAttemptResult.failure(this.error) : route = null;

  final Route? route;
  final RoutingException? error;

  bool get isSuccess => route != null;
}

class RoutingService {
  RoutingService({
    http.Client? httpClient,
    String? graphhopperApiKey,
    Duration requestTimeout = const Duration(seconds: 5),
    Duration networkProbeTimeout = const Duration(milliseconds: 900),
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _graphhopperApiKey =
            graphhopperApiKey ?? Platform.environment[_graphhopperApiKeyEnvKey],
        _requestTimeout = requestTimeout,
        _networkProbeTimeout = networkProbeTimeout;

  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  static const String _graphhopperBaseUrl = 'https://graphhopper.com/api/1';
  static const String _graphhopperApiKeyEnvKey = 'GRAPHHOPPER_API_KEY';
  static const List<Duration> _primaryRetryBackoff = [
    Duration(milliseconds: 150),
  ];
  static const List<Duration> _fallbackRetryBackoff = [
    Duration(milliseconds: 200),
  ];

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration _requestTimeout;
  final Duration _networkProbeTimeout;
  final String? _graphhopperApiKey;

  Future<Route> calculateRoute(
      UserLocation start, Destination destination) async {
    await _ensureConnectivity();

    final timeBudget = _splitTimeoutBudget(_requestTimeout);

    final primaryResult = await _attemptWithRetries(
      label: 'OSRM',
      budget: timeBudget.primary,
      retryBackoff: _primaryRetryBackoff,
      fetch: (timeout) => _fetchRouteFromOSRM(start, destination, timeout),
    );

    if (primaryResult.isSuccess) {
      return primaryResult.route!;
    }
    final primaryError = primaryResult.error ??
        RoutingException(
          'OSRM request failed without detailed error',
          code: RoutingIssueCode.unknown,
        );

    if (timeBudget.fallback <= Duration.zero) {
      throw RoutingException(
        'Route calculation failed after OSRM error: ${primaryError.message}',
        code: primaryError.code,
        cause: primaryError,
      );
    }

    final fallbackResult = await _attemptWithRetries(
      label: 'GraphHopper',
      budget: timeBudget.fallback,
      retryBackoff: _fallbackRetryBackoff,
      fetch: (timeout) =>
          _fetchRouteFromGraphHopper(start, destination, timeout),
    );

    if (fallbackResult.isSuccess) {
      return fallbackResult.route!;
    }

    final fallbackError = fallbackResult.error ??
        RoutingException(
          'GraphHopper request failed without detailed error',
          code: RoutingIssueCode.unknown,
        );

    throw RoutingException(
      'Route calculation failed after OSRM (${primaryError.message}) '
      'and GraphHopper (${fallbackError.message}) errors',
      code: fallbackError.code,
      cause: fallbackError,
    );
  }

  Future<_FetchAttemptResult> _attemptWithRetries({
    required String label,
    required Duration budget,
    required List<Duration> retryBackoff,
    required Future<Route> Function(Duration timeout) fetch,
  }) async {
    if (budget <= Duration.zero) {
      return _FetchAttemptResult.failure(
        RoutingException(
          '$label request aborted: no time remaining',
          code: RoutingIssueCode.timeout,
        ),
      );
    }

    final totalAttempts = math.max(1, retryBackoff.length + 1);
    var remaining = budget;
    RoutingException? lastError;

    for (var attempt = 0; attempt < totalAttempts; attempt++) {
      final attemptsLeft = totalAttempts - attempt;
      final timeout = _allocateAttemptTimeout(remaining, attemptsLeft);
      if (timeout <= Duration.zero) {
        break;
      }

      try {
        final route = await fetch(timeout);
        return _FetchAttemptResult.success(route);
      } on RoutingException catch (error) {
        lastError = error;
        _logFailure('$label attempt ${attempt + 1}', error);
        remaining -= timeout;
        if (remaining <= Duration.zero) {
          break;
        }
        final shouldRetry =
            attempt < retryBackoff.length && _isRetryable(error);
        if (!shouldRetry) {
          break;
        }
        final delay = retryBackoff[attempt];
        final delayBudget = delay <= remaining ? delay : remaining;
        if (delayBudget > Duration.zero) {
          await Future<void>.delayed(delayBudget);
          remaining -= delayBudget;
        }
      } catch (error) {
        final wrapped = RoutingException(
          '$label request failed with unexpected error',
          code: RoutingIssueCode.unknown,
          cause: error,
        );
        _logFailure('$label attempt ${attempt + 1}', wrapped);
        return _FetchAttemptResult.failure(wrapped);
      }
    }

    return _FetchAttemptResult.failure(
      lastError ??
          RoutingException(
            '$label request failed',
            code: RoutingIssueCode.unknown,
          ),
    );
  }

  bool _isRetryable(RoutingException error) {
    switch (error.code) {
      case RoutingIssueCode.networkUnavailable:
      case RoutingIssueCode.timeout:
      case RoutingIssueCode.rateLimited:
      case RoutingIssueCode.serverError:
        return true;
      case RoutingIssueCode.configuration:
      case RoutingIssueCode.responseMalformed:
      case RoutingIssueCode.startLocationUnavailable:
      case RoutingIssueCode.unknown:
        return false;
    }
  }

  Duration _allocateAttemptTimeout(Duration remaining, int attemptsLeft) {
    if (remaining <= Duration.zero) {
      return Duration.zero;
    }
    final milliseconds = math.max(
      100,
      remaining.inMilliseconds ~/ attemptsLeft,
    );
    return Duration(milliseconds: milliseconds);
  }

  Future<void> _ensureConnectivity() async {
    try {
      final lookup = await InternetAddress.lookup('router.project-osrm.org')
          .timeout(_networkProbeTimeout);
      if (lookup.isEmpty) {
        throw const SocketException('No address returned');
      }
    } on SocketException catch (error) {
      throw RoutingException(
        'No internet connection detected. Check your connection and try again.',
        code: RoutingIssueCode.networkUnavailable,
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw RoutingException(
        'Network check timed out before routing request could start.',
        code: RoutingIssueCode.timeout,
        cause: error,
      );
    }
  }

  Future<Route> _fetchRouteFromOSRM(
    UserLocation start,
    Destination destination,
    Duration timeout,
  ) async {
    if (timeout <= Duration.zero) {
      throw RoutingException(
        'OSRM request aborted: no time remaining',
        code: RoutingIssueCode.timeout,
      );
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
      throw RoutingException(
        'OSRM request failed: network error',
        code: RoutingIssueCode.networkUnavailable,
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw RoutingException(
        'OSRM request timed out after ${_formatTimeout(timeout)}',
        code: RoutingIssueCode.timeout,
        cause: error,
      );
    } on HttpException catch (error) {
      throw RoutingException(
        'OSRM request failed: HTTP error',
        code: RoutingIssueCode.serverError,
        cause: error,
      );
    }

    if (response.statusCode != HttpStatus.ok) {
      final code = response.statusCode == HttpStatus.tooManyRequests
          ? RoutingIssueCode.rateLimited
          : RoutingIssueCode.serverError;
      throw RoutingException(
        'OSRM request failed with status ${response.statusCode}',
        code: code,
      );
    }

    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw RoutingException(
        'OSRM response was not valid JSON',
        code: RoutingIssueCode.responseMalformed,
        cause: error,
      );
    }

    final code = payload['code'] as String?;
    if (code != 'Ok') {
      throw RoutingException(
        'OSRM returned error code: ${code ?? 'unknown'}',
        code: RoutingIssueCode.serverError,
      );
    }

    final routes = payload['routes'];
    if (routes is! List || routes.isEmpty) {
      throw RoutingException(
        'OSRM response missing routes',
        code: RoutingIssueCode.responseMalformed,
      );
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map<String, dynamic>) {
      throw RoutingException(
        'OSRM route payload is malformed',
        code: RoutingIssueCode.responseMalformed,
      );
    }

    final distance = (firstRoute['distance'] as num?)?.toDouble();
    final duration = (firstRoute['duration'] as num?)?.toDouble();
    if (distance == null || duration == null) {
      throw RoutingException(
        'OSRM route payload missing distance or duration',
        code: RoutingIssueCode.responseMalformed,
      );
    }

    final geometry = firstRoute['geometry'];
    final points = _parseGeometryPoints(geometry);
    if (points.isEmpty) {
      throw RoutingException(
        'OSRM route contains no coordinates',
        code: RoutingIssueCode.responseMalformed,
      );
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
      throw RoutingException(
        'GraphHopper request aborted: no time remaining',
        code: RoutingIssueCode.timeout,
      );
    }

    final apiKey = _graphhopperApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw RoutingException(
        'GraphHopper API key is not configured',
        code: RoutingIssueCode.configuration,
      );
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
      throw RoutingException(
        'GraphHopper request failed: network error',
        code: RoutingIssueCode.networkUnavailable,
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw RoutingException(
        'GraphHopper request timed out after ${_formatTimeout(timeout)}',
        code: RoutingIssueCode.timeout,
        cause: error,
      );
    } on HttpException catch (error) {
      throw RoutingException(
        'GraphHopper request failed: HTTP error',
        code: RoutingIssueCode.serverError,
        cause: error,
      );
    }

    if (response.statusCode != HttpStatus.ok) {
      final code = response.statusCode == HttpStatus.tooManyRequests
          ? RoutingIssueCode.rateLimited
          : RoutingIssueCode.serverError;
      throw RoutingException(
        'GraphHopper request failed with status ${response.statusCode}',
        code: code,
      );
    }

    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw RoutingException(
        'GraphHopper response was not valid JSON',
        code: RoutingIssueCode.responseMalformed,
        cause: error,
      );
    }

    final paths = payload['paths'];
    if (paths is! List || paths.isEmpty) {
      throw RoutingException(
        'GraphHopper response missing paths',
        code: RoutingIssueCode.responseMalformed,
      );
    }

    final firstPath = paths.first;
    if (firstPath is! Map<String, dynamic>) {
      throw RoutingException(
        'GraphHopper path payload is malformed',
        code: RoutingIssueCode.responseMalformed,
      );
    }

    final distance = (firstPath['distance'] as num?)?.toDouble();
    final durationMillis = (firstPath['time'] as num?)?.toDouble();
    if (distance == null || durationMillis == null) {
      throw RoutingException(
        'GraphHopper path missing distance or duration fields',
        code: RoutingIssueCode.responseMalformed,
      );
    }

    final geometry = firstPath['points'];
    final points = _parseGeometryPoints(geometry);
    if (points.isEmpty) {
      throw RoutingException(
        'GraphHopper path contains no coordinates',
        code: RoutingIssueCode.responseMalformed,
      );
    }

    final geometryString = _normalizeGeometryString(geometry);

    return Route(
      points: points,
      distanceMeters: distance,
      durationSeconds: durationMillis / 1000,
      geometry: geometryString,
    );
  }

  void _logFailure(String stage, RoutingException error) {
    developer.log(
      '$stage failed (${error.code.name}): ${error.message}',
      name: 'RoutingService',
      error: error.cause,
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
        fallback: Duration.zero,
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
