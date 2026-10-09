import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../models/church_event.dart';

/// Large gradient banner at the top of the dashboard. Features the next
/// upcoming event when there is one, otherwise a welcome message.
class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.nextEvent,
    required this.onViewEvents,
    required this.onJoinWhatsApp,
    this.onWatchLive,
  });

  final ChurchEvent? nextEvent;
  final VoidCallback onViewEvents;
  final VoidCallback onJoinWhatsApp;
  final VoidCallback? onWatchLive;

  @override
  Widget build(BuildContext context) {
    final event = nextEvent;
    final title = event?.title ?? 'Welcome to Bread of Life';
    final subtitle = event == null
        ? 'Growing in faith. Serving together.'
        : [formatDate(event.date), if (event.location.isNotEmpty) event.location]
            .join('  •  ');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 200),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.blueDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Soft gold "sunrise" glow behind the logo.
          Positioned(
            right: -60,
            bottom: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.secondary.withValues(alpha: 0.55),
                  AppColors.secondary.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
          Positioned(
            right: 28,
            top: 20,
            bottom: 20,
            child: Opacity(
              opacity: 0.95,
              child: Image.asset('assets/images/bol_logo.png', fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 140, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(event == null ? 'BREAD OF LIFE • LUKULU' : 'NEXT UP',
                      style: const TextStyle(
                          color: AppColors.secondaryLight,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 1.4)),
                ),
                const SizedBox(height: 14),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (onWatchLive != null)
                      FilledButton.icon(
                        onPressed: onWatchLive,
                        icon: const Icon(Icons.play_circle_fill, size: 20),
                        label: const Text('Watch Live'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.primaryDark),
                      ),
                    OutlinedButton(
                      onPressed: onViewEvents,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54)),
                      child: const Text('View Events'),
                    ),
                    OutlinedButton(
                      onPressed: onJoinWhatsApp,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54)),
                      child: const Text('Join WhatsApp'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
