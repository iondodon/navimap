// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

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
      NaviMapApp(createAppState: () => AppState(httpClient: mockClient)),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Offline Mode'), findsNothing);
  });
}
