import 'package:flutter/material.dart';

class NavDestination {
  final String label;
  final IconData icon;
  final Widget Function() builder;

  /// A shorter word for the phone bottom bar, where each of five items only has
  /// about 70px. Falls back to [label] where there is room (sidebar, More list).
  final String? shortLabel;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.builder,
    this.shortLabel,
  });

  String get barLabel => shortLabel ?? label;
}
