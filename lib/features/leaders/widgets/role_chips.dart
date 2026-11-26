import 'package:flutter/material.dart';

import '../../../core/providers/user_role_provider.dart';

/// Church roles as tick-able chips, so a person can choose several.
class RoleChips extends StatelessWidget {
  const RoleChips({
    super.key,
    required this.roles,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final List<UserRole> roles;
  final Set<UserRole> selected;
  final void Function(UserRole role, bool on) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final role in roles)
          FilterChip(
            key: Key('role-chip-${role.name}'),
            label: Text(role.label),
            selected: selected.contains(role),
            onSelected: enabled ? (on) => onChanged(role, on) : null,
          ),
      ],
    );
  }
}
