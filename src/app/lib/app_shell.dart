import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The shell of the application (reserved for future navigation tabs).
final class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return navigationShell;
  }
}
