import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_user_provider.dart';
import '../../../core/providers/push_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/push_service.dart';

/// At the top of Notifications: turn alerts on (or off) for the phone or browser
/// in your hand. Hidden until the notification key is set up.
class PushOptInCard extends ConsumerStatefulWidget {
  const PushOptInCard({super.key});

  @override
  ConsumerState<PushOptInCard> createState() => _PushOptInCardState();
}

class _PushOptInCardState extends ConsumerState<PushOptInCard> {
  PushState? _state;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    try {
      final s = await ref.read(pushServiceProvider).state(uid);
      if (mounted) setState(() => _state = s);
    } catch (_) {
      // If we cannot tell, show nothing rather than something wrong.
      if (mounted) setState(() => _state = null);
    }
  }

  Future<void> _turnOn() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await ref.read(pushServiceProvider).enable(uid);
      if (mounted) setState(() => _state = s);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not turn alerts on. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOff() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(pushServiceProvider).disable();
      if (mounted) setState(() => _state = PushState.off);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not turn alerts off. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null || state == PushState.notConfigured) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    final (icon, title, body, action) = switch (state) {
      PushState.on => (
          Icons.notifications_active,
          'Alerts are on for this phone',
          'You will be told about new announcements, events and anything that '
              'needs you, even when the app is closed.',
          TextButton(
            key: const Key('push-off'),
            onPressed: _busy ? null : _turnOff,
            child: const Text('Turn off'),
          ),
        ),
      PushState.off => (
          Icons.notifications_none,
          'Get alerts on this phone',
          'Be told about new announcements, events and anything that needs you, '
              'even when the app is closed.',
          FilledButton.icon(
            key: const Key('push-on'),
            onPressed: _busy ? null : _turnOn,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(_busy ? 'Turning on...' : 'Turn on alerts'),
          ),
        ),
      PushState.blocked => (
          Icons.notifications_off_outlined,
          'Alerts are blocked',
          'Notifications are blocked for this app in your browser. Allow them in '
              'the browser or phone settings for this site, then come back.',
          null,
        ),
      _ => (
          Icons.notifications_off_outlined,
          'Alerts are not available here',
          'This browser cannot show phone notifications. On an iPhone, add the app '
              'to your Home Screen first (Share, then Add to Home Screen) and open '
              'it from there.',
          null,
        ),
    };

    return Card(
      key: const Key('push-card'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(body, style: theme.textTheme.bodyMedium),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_error!,
                          key: const Key('push-error'),
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (action != null) ...[
                    const SizedBox(height: 8),
                    action,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
