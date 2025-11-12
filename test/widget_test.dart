// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:navimap/main.dart';
import 'package:navimap/state/app_state.dart';

void main() {
  testWidgets('NaviMap app smoke test', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response('', 200);
    });

    await tester.pumpWidget(
      NaviMapApp(
        createAppState: () => AppState(httpClient: mockClient),
        tileProvider: _StubTileProvider(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Offline Mode'), findsNothing);
  });
}

class _StubTileProvider extends TileProvider {
  _StubTileProvider();

  static const List<int> _transparentPixel = <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x60,
    0x00,
    0x02,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ];

  static final Uint8List _transparentBytes =
      Uint8List.fromList(_transparentPixel);

  @override
  ImageProvider<Object> getImage(
      TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_transparentBytes);
  }
}
