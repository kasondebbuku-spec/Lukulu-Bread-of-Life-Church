import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/phone_login.dart';
import '../constants/admin_contact.dart';

/// The Admin's WhatsApp number as digits with the country code, or null when none
/// (or not a real number) has been set.
final adminWhatsAppProvider =
    Provider<String?>((ref) => normalizePhone(adminWhatsAppNumber));

/// Opens a link outside the app. Returns false if nothing could open it.
final externalLinkProvider = Provider<Future<bool> Function(Uri)>(
    (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
