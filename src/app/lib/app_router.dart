import 'package:app/presentation/forced_update/forced_update_page.dart';
import 'package:app/presentation/kill_switch/kill_switch_page.dart';
import 'package:app/presentation/map/map_page.dart';
import 'package:app/shell.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

const String home = '/';
const String forcedUpdatePagePath = '/forcedUpdate';
const String killSwitchPagePath = '/killswitch';
String? currentPath;

final router = GoRouter(
  initialLocation: home,
  observers: [GoRouterObserver(GetIt.I.get<Logger>())],
  navigatorKey: rootNavigatorKey,
  routes: [
    ShellRoute(
      builder: (context, state, child) => Shell(child: child),
      observers: [GoRouterObserver(GetIt.I.get<Logger>())],
      routes: [
        GoRoute(path: home, builder: (context, state) => const MapPage()),
        GoRoute(
          path: forcedUpdatePagePath,
          builder: (context, state) => ForcedUpdatePage(),
        ),
        GoRoute(
          path: killSwitchPagePath,
          builder: (context, state) => const KillSwitchPage(),
        ),
      ],
    ),
  ],
);

class GoRouterObserver extends NavigatorObserver {
  final Logger _logger;

  GoRouterObserver(this._logger);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != null) {
      currentPath = route.settings.name;

      _logger.i('Pushing ${route.settings.name}.');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != null) {
      currentPath = route.settings.name;

      _logger.i('Popped ${route.settings.name}.');
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != null) {
      currentPath = route.settings.name;

      _logger.i('Removed ${route.settings.name}.');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute?.settings.name != null) {
      currentPath = newRoute?.settings.name;

      _logger.i(
        'Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}.',
      );
    }
  }
}
