import 'phone_login.dart';

/// The message that is ready to send when someone asks the Admin for help with a
/// forgotten password. [typed] is what they entered in the box (their phone number
/// or email), so the Admin can find the account. A password is never part of it.
String passwordHelpMessage(String typed) {
  final entry = typed.trim();
  final phone = looksLikePhone(entry) ? normalizePhone(entry) : null;
  final account = phone != null
      ? '\nMy phone number on the app is ${prettyPhone(phone)}.'
      : entry.contains('@')
          ? '\nMy email on the app is $entry.'
          : '';
  return 'Hello, I have forgotten my password for the Lukulu Bread of Life church '
      'app. Please help me.$account\nMy name is: ';
}

/// A link that opens a WhatsApp chat with [adminDigits] (country code first, no
/// `+`) with the help message already typed. Nothing is sent until the person
/// presses send in WhatsApp.
Uri adminWhatsAppLink(String adminDigits, {String typed = ''}) => Uri.https(
    'wa.me', '/$adminDigits', {'text': passwordHelpMessage(typed)});
