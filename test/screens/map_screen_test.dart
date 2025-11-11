import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:navimap/screens/map_screen.dart';
import 'package:navimap/state/app_state.dart';

void main() {
  testWidgets('shows offline placeholder when tile server is unreachable',
      (tester) async {
    final mockClient = MockClient((request) async {
      return http.Response('error', 500);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppState>(
          create: (_) => AppState(httpClient: mockClient),
          child: const MapScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Offline Mode'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('retry button attempts to reload tiles after failure',
      (tester) async {
    var requestCount = 0;
    final mockClient = MockClient((request) async {
      requestCount++;
      if (requestCount == 1) {
        return http.Response('error', 500);
      }
      return http.Response('', 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppState>(
          create: (_) => AppState(httpClient: mockClient),
          child: const MapScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Offline Mode'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FlutterMap), findsOneWidget);
  });
}