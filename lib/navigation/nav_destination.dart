import 'package:flutter/material.dart';

class NavDestination {
  final String label;
  final IconData icon;
  final Widget Function() builder;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.builder,
  });
}
