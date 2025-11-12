enum ErrorCategory { network, routing, location, tiles }

enum NetworkErrorCode { offline, timeout, serverError, rateLimited, unknown }

enum RoutingIssueCode {
  networkUnavailable,
  timeout,
  rateLimited,
  serverError,
  configuration,
  responseMalformed,
  startLocationUnavailable,
  unknown,
}

enum LocationIssueCode {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
  unknown,
}

enum TileIssueCode {
  network,
  timeout,
  serverError,
  rateLimited,
  cacheHit,
  unknown
}

class ErrorState {
  const ErrorState._({
    required this.category,
    required this.code,
    required this.message,
    required this.canRetry,
    this.networkCode,
    this.routingCode,
    this.locationCode,
    this.tileCode,
  });

  factory ErrorState.network(NetworkErrorCode code, String message,
      {bool canRetry = true}) {
    return ErrorState._(
      category: ErrorCategory.network,
      code: 'network.${code.name}',
      message: message,
      canRetry: canRetry,
      networkCode: code,
    );
  }

  factory ErrorState.routing(RoutingIssueCode code, String message,
      {bool canRetry = true}) {
    return ErrorState._(
      category: ErrorCategory.routing,
      code: 'routing.${code.name}',
      message: message,
      canRetry: canRetry,
      routingCode: code,
    );
  }

  factory ErrorState.location(LocationIssueCode code, String message,
      {bool canRetry = true}) {
    return ErrorState._(
      category: ErrorCategory.location,
      code: 'location.${code.name}',
      message: message,
      canRetry: canRetry,
      locationCode: code,
    );
  }

  factory ErrorState.tiles(TileIssueCode code, String message,
      {bool canRetry = true}) {
    return ErrorState._(
      category: ErrorCategory.tiles,
      code: 'tiles.${code.name}',
      message: message,
      canRetry: canRetry,
      tileCode: code,
    );
  }

  final ErrorCategory category;
  final String code;
  final String message;
  final bool canRetry;

  final NetworkErrorCode? networkCode;
  final RoutingIssueCode? routingCode;
  final LocationIssueCode? locationCode;
  final TileIssueCode? tileCode;
}
