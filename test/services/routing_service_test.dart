import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:navimap/models/destination.dart';
import 'package:navimap/models/user_location.dart';
import 'package:navimap/services/routing_service.dart';

void main() {
  group('RoutingService', () {
    final start = UserLocation(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: DateTime.utc(2025, 1, 1),
    );
    final destination = Destination(latitude: 37.7793, longitude: -122.4192);

    test('parses OSRM response into Route model', () async {
      late Uri capturedUri;
      final service = RoutingService(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            '''{
              "code": "Ok",
              "routes": [
                {
                  "distance": 1534.8,
                  "duration": 389.2,
                  "geometry": {
                    "type": "LineString",
                    "coordinates": [
                      [-122.4194, 37.7749],
                      [-122.4192, 37.7793]
                    ]
                  }
                }
              ]
            }''',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final route = await service.calculateRoute(start, destination);

      expect(route.points,
          const [LatLng(37.7749, -122.4194), LatLng(37.7793, -122.4192)]);
      expect(route.distanceMeters, closeTo(1534.8, 0.001));
      expect(route.durationSeconds, closeTo(389.2, 0.001));
      expect(route.geometry, contains('LineString'));

      expect(capturedUri.scheme, 'https');
      expect(capturedUri.host, 'router.project-osrm.org');
      expect(capturedUri.pathSegments.join('/'), contains('route/v1/driving'));
      expect(capturedUri.queryParameters['overview'], 'full');
      expect(capturedUri.queryParameters['geometries'], 'geojson');

      service.dispose();
    });

    test('falls back to GraphHopper when OSRM fails', () async {
      var osrmCalls = 0;
      var graphhopperCalls = 0;

      final service = RoutingService(
        graphhopperApiKey: 'test-key',
        httpClient: MockClient((request) async {
          if (request.url.host == 'router.project-osrm.org') {
            osrmCalls++;
            return http.Response('Server error', 500);
          }
          if (request.url.host == 'graphhopper.com') {
            graphhopperCalls++;
            return http.Response(
              '''{
                "paths": [
                  {
                    "distance": 2450.0,
                    "time": 600000,
                    "points": {
                      "type": "LineString",
                      "coordinates": [
                        [-122.4194, 37.7749],
                        [-122.4192, 37.7793]
                      ]
                    }
                  }
                ]
              }''',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          fail('Unexpected host ${request.url.host}');
        }),
      );

      final route = await service.calculateRoute(start, destination);

      expect(route.points.length, 2);
      expect(route.distanceMeters, 2450.0);
      expect(route.durationSeconds, 600);
      expect(osrmCalls, 1);
      expect(graphhopperCalls, 1);

      service.dispose();
    });

    test('reserves fallback time when OSRM exceeds its budget', () async {
      var osrmCalls = 0;
      var graphhopperCalls = 0;

      final service = RoutingService(
        graphhopperApiKey: 'test-key',
        requestTimeout: const Duration(seconds: 1),
        httpClient: MockClient((request) async {
          if (request.url.host == 'router.project-osrm.org') {
            osrmCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 700));
            return http.Response('''{
              "code": "Ok",
              "routes": []
            }''', 200);
          }
          if (request.url.host == 'graphhopper.com') {
            graphhopperCalls++;
            return http.Response(
              '''{
                "paths": [
                  {
                    "distance": 1800.0,
                    "time": 420000,
                    "points": {
                      "type": "LineString",
                      "coordinates": [
                        [-122.4194, 37.7749],
                        [-122.4192, 37.7793]
                      ]
                    }
                  }
                ]
              }''',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          fail('Unexpected host ${request.url.host}');
        }),
      );

      final route = await service.calculateRoute(start, destination);

      expect(route.distanceMeters, 1800.0);
      expect(route.durationSeconds, 420);
      expect(osrmCalls, 1);
      expect(graphhopperCalls, 1);

      service.dispose();
    });

    test('throws when GraphHopper API key is missing during fallback',
        () async {
      final service = RoutingService(
        httpClient: MockClient(
          (request) async => http.Response('Server error', 500),
        ),
      );

      expect(
        () => service.calculateRoute(start, destination),
        throwsA(isA<RoutingException>().having((e) => e.message, 'message',
            contains('GraphHopper API key is not configured'))),
      );

      service.dispose();
    });

    test('throws RoutingException when OSRM returns non-200', () async {
      final service = RoutingService(
        graphhopperApiKey: 'test-key',
        httpClient: MockClient(
            (request) async => http.Response('Internal Server Error', 500)),
      );

      expect(
        () => service.calculateRoute(start, destination),
        throwsA(isA<RoutingException>()
            .having((e) => e.message, 'message', contains('status 500'))),
      );

      service.dispose();
    });

    test('throws RoutingException when OSRM returns error payload', () async {
      final service = RoutingService(
        graphhopperApiKey: 'test-key',
        httpClient: MockClient(
          (request) async =>
              http.Response('''{"code": "InvalidQuery", "routes": []}''', 200),
        ),
      );

      expect(
        () => service.calculateRoute(start, destination),
        throwsA(isA<RoutingException>()
            .having((e) => e.message, 'message', contains('error code'))),
      );

      service.dispose();
    });

    test('wraps timeout exceptions from HTTP client', () async {
      final service = RoutingService(
        graphhopperApiKey: 'test-key',
        httpClient: MockClient(
          (request) => Future<http.Response>.error(
              TimeoutException('Request timed out')),
        ),
      );

      expect(
        () => service.calculateRoute(start, destination),
        throwsA(isA<RoutingException>()
            .having((e) => e.message, 'message', contains('timed out'))),
      );

      service.dispose();
    });

    test('wraps socket exceptions from HTTP client', () async {
      final service = RoutingService(
        graphhopperApiKey: 'test-key',
        httpClient: MockClient(
          (request) => Future<http.Response>.error(
              const SocketException('Network down')),
        ),
      );

      expect(
        () => service.calculateRoute(start, destination),
        throwsA(isA<RoutingException>()
            .having((e) => e.message, 'message', contains('network error'))),
      );

      service.dispose();
    });
  });
}
