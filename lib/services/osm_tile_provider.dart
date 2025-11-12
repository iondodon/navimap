import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import '../state/error_state.dart';

class TileFetchException implements Exception {
  TileFetchException(
    this.code,
    this.message, {
    this.cause,
    this.statusCode,
    this.networkCode,
  });

  final TileIssueCode code;
  final String message;
  final Object? cause;
  final int? statusCode;
  final NetworkErrorCode? networkCode;

  bool get retryable {
    switch (code) {
      case TileIssueCode.cacheHit:
      case TileIssueCode.unknown:
        return false;
      case TileIssueCode.network:
      case TileIssueCode.timeout:
      case TileIssueCode.serverError:
      case TileIssueCode.rateLimited:
        return true;
    }
  }

  @override
  String toString() =>
      'TileFetchException(${code.name}, $message${cause != null ? ', cause: $cause' : ''})';
}

class OsmTileProvider extends TileProvider {
  OsmTileProvider({
    http.Client? httpClient,
    this.userAgent = 'NaviMap/1.0 (+https://navimap.app)',
    this.maxConcurrentRequests = 4,
    this.requestTimeout = const Duration(seconds: 3),
    this.cacheTtl = const Duration(hours: 6),
    this.onError,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;
  final String userAgent;
  final int maxConcurrentRequests;
  final Duration requestTimeout;
  final Duration cacheTtl;
  final void Function(TileFetchException error)? onError;

  final Map<String, _CachedTile> _cache = <String, _CachedTile>{};
  final Queue<_TileJob> _queue = Queue<_TileJob>();
  int _inFlight = 0;

  static const List<Duration> _retryBackoff = <Duration>[
    Duration(milliseconds: 120),
    Duration(milliseconds: 260),
  ];

  @override
  ImageProvider<Object> getImage(
      TileCoordinates coordinates, TileLayer options) {
    final url = Uri.parse(getTileUrl(coordinates, options));
    final cacheKey = url.toString();
    return _OsmTileImage(
      provider: this,
      url: url,
      cacheKey: cacheKey,
      options: options,
    );
  }

  Future<Uint8List> resolveTile(String cacheKey, Uri url) async {
    final now = DateTime.now();
    final cached = _cache[cacheKey];
    if (cached != null && now.difference(cached.timestamp) <= cacheTtl) {
      return cached.bytes;
    }

    final job = _TileJob(url, cacheKey);
    _queue.add(job);
    _pumpQueue();

    try {
      final bytes = await job.completer.future;
      _cache[cacheKey] = _CachedTile(bytes, now);
      return bytes;
    } on TileFetchException catch (error) {
      final fallback = _cache[cacheKey];
      if (fallback != null) {
        onError?.call(TileFetchException(
          TileIssueCode.cacheHit,
          error.message,
          cause: error,
          networkCode: error.networkCode,
          statusCode: error.statusCode,
        ));
        return fallback.bytes;
      }
      onError?.call(error);
      rethrow;
    }
  }

  void clearCache() => _cache.clear();

  @override
  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }

  void _pumpQueue() {
    while (_inFlight < maxConcurrentRequests && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _startJob(job);
    }
  }

  void _startJob(_TileJob job) {
    _inFlight++;
    unawaited(_executeJob(job));
  }

  Future<void> _executeJob(_TileJob job) async {
    try {
      final bytes = await _fetchWithRetries(job.url);
      job.completer.complete(bytes);
    } on TileFetchException catch (error) {
      job.completer.completeError(error);
    } catch (error, stackTrace) {
      debugPrint('Tile fetch unexpected error: $error\n$stackTrace');
      job.completer.completeError(
        TileFetchException(
          TileIssueCode.unknown,
          'Unexpected tile loading failure',
          cause: error,
        ),
      );
    } finally {
      _inFlight--;
      _pumpQueue();
    }
  }

  Future<Uint8List> _fetchWithRetries(Uri url) async {
    TileFetchException? lastError;
    for (var attempt = 0; attempt <= _retryBackoff.length; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_retryBackoff[attempt - 1]);
      }
      try {
        return await _fetchTile(url);
      } on TileFetchException catch (error) {
        lastError = error;
        if (!error.retryable || attempt == _retryBackoff.length) {
          break;
        }
      }
    }
    throw lastError ??
        TileFetchException(
          TileIssueCode.unknown,
          'Unknown tile error',
        );
  }

  Future<Uint8List> _fetchTile(Uri url) async {
    late http.Response response;
    try {
      response = await _httpClient
          .get(url, headers: {'User-Agent': userAgent}).timeout(requestTimeout);
    } on SocketException catch (error) {
      throw TileFetchException(
        TileIssueCode.network,
        'Network error while loading map tiles.',
        cause: error,
        networkCode: NetworkErrorCode.offline,
      );
    } on TimeoutException catch (error) {
      throw TileFetchException(
        TileIssueCode.timeout,
        'Tile request timed out.',
        cause: error,
        networkCode: NetworkErrorCode.timeout,
      );
    } on http.ClientException catch (error) {
      throw TileFetchException(
        TileIssueCode.network,
        'Client error while loading map tiles.',
        cause: error,
        networkCode: NetworkErrorCode.unknown,
      );
    }

    if (response.statusCode == HttpStatus.ok) {
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw TileFetchException(
          TileIssueCode.serverError,
          'Tile server returned an empty payload.',
          statusCode: response.statusCode,
        );
      }
      return bytes;
    }

    final tileCode = response.statusCode == HttpStatus.tooManyRequests
        ? TileIssueCode.rateLimited
        : TileIssueCode.serverError;
    final networkCode = response.statusCode == HttpStatus.tooManyRequests
        ? NetworkErrorCode.rateLimited
        : NetworkErrorCode.serverError;

    throw TileFetchException(
      tileCode,
      response.statusCode == HttpStatus.tooManyRequests
          ? 'OpenStreetMap rate limit reached.'
          : 'Tile server error (${response.statusCode}).',
      statusCode: response.statusCode,
      networkCode: networkCode,
    );
  }
}

class _OsmTileImage extends ImageProvider<_OsmTileImage> {
  const _OsmTileImage({
    required this.provider,
    required this.url,
    required this.cacheKey,
    required this.options,
  });

  final OsmTileProvider provider;
  final Uri url;
  final String cacheKey;
  final TileLayer options;

  @override
  Future<_OsmTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_OsmTileImage>(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _OsmTileImage && other.cacheKey == cacheKey;
  }

  @override
  int get hashCode => cacheKey.hashCode;

  @override
  ImageStreamCompleter loadImage(
      _OsmTileImage key, ImageDecoderCallback decode) {
    final future = _loadAsync(key, decode);
    return MultiFrameImageStreamCompleter(
      codec: future,
      scale: 1,
      debugLabel: url.toString(),
    );
  }

  Future<ui.Codec> _loadAsync(
      _OsmTileImage key, ImageDecoderCallback decode) async {
    final bytes = await provider.resolveTile(cacheKey, url);
    if (bytes.isEmpty) {
      throw TileFetchException(
        TileIssueCode.serverError,
        'Tile payload empty',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }
}

class _TileJob {
  _TileJob(this.url, this.cacheKey) : completer = Completer<Uint8List>();

  final Uri url;
  final String cacheKey;
  final Completer<Uint8List> completer;
}

class _CachedTile {
  _CachedTile(this.bytes, this.timestamp);

  final Uint8List bytes;
  final DateTime timestamp;
}
