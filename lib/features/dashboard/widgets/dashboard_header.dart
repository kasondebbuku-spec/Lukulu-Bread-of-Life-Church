import 'package:flutter/material.dart';

import '../../../core/providers/user_role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/role_badge.dart';

/// Greeting row at the top of the dashboard with the account menu on the right.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.greeting,
    required this.userName,
    required this.role,
    required this.onLogout,
  });

  final String greeting;
  final String userName;
  final UserAccess role;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Welcome to Bread of Life, Lukulu Branch'),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (v) {
            if (v == 'logout') onLogout();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  RoleBadge(role: role),
                ],
              ),
            ),
            const PopupMenuItem(value: 'logout', child: Text('Logout')),
          ],
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(userName.isEmpty ? '?' : userName[0].toUpperCase(),
                style: const TextStyle(
                    color: AppColors.secondaryLight, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
