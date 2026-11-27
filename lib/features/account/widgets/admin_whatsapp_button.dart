import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/admin_contact_providers.dart';
import '../../../models/admin_help.dart';
import '../../../models/phone_login.dart';

/// "Message the Admin on WhatsApp", for someone who has forgotten a password.
/// It only helps them ask: it does not reset anything. Hidden until the Admin's
/// number is set.
class AdminWhatsAppButton extends ConsumerStatefulWidget {
  const AdminWhatsAppButton({super.key, this.typed = ''});

  /// What the person entered as their phone number or email.
  final String typed;

  @override
  ConsumerState<AdminWhatsAppButton> createState() =>
      _AdminWhatsAppButtonState();
}

class _AdminWhatsAppButtonState extends ConsumerState<AdminWhatsAppButton> {
  bool _failed = false;

  Future<void> _open(String number) async {
    bool opened;
    try {
      opened = await ref.read(externalLinkProvider)(
          adminWhatsAppLink(number, typed: widget.typed));
    } catch (_) {
      opened = false;
    }
    if (mounted) setState(() => _failed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final number = ref.watch(adminWhatsAppProvider);
    if (number == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            key: const Key('whatsapp-admin'),
            onPressed: () => _open(number),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Message the Admin on WhatsApp'),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                  'WhatsApp did not open. Message the Admin on ${prettyPhone(number)}.',
                  key: const Key('whatsapp-failed')),
            ),
        ],
      ),
    );
  }
}
