import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import 'screens/map_screen.dart';
import 'state/app_state.dart';

void main() {
  runApp(const NaviMapApp());
}

class NaviMapApp extends StatelessWidget {
  const NaviMapApp({super.key, this.createAppState, this.tileProvider});

  final AppState Function()? createAppState;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>(
      create: (_) => (createAppState ?? AppState.new)(),
      child: MaterialApp(
        title: 'NaviMap',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        home: MapScreen(tileProvider: tileProvider),
      ),
    );
  }
}
