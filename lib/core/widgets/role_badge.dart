import 'package:flutter/material.dart';
import '../providers/user_role_provider.dart';
import '../theme/app_theme.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});
  final UserAccess role;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: role.roles
            .map((r) => Chip(
                  avatar: const Icon(Icons.verified_user_outlined, size: 16),
                  label: Text(r.label),
                  backgroundColor: AppColors.surface,
                  labelStyle: const TextStyle(
                      color: AppColors.primaryDark, fontSize: 12),
                ))
            .toList(),
      );
}
