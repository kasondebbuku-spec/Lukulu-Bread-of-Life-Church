/// Signing in with a phone number instead of an email.
///
/// Firebase signs people in with an email and a password. For someone with no
/// email, their phone number is turned into a private, made-up address that
/// they never see (`260971234567@phone.lukulu-bread-of-life.app`) and used with
/// the password they choose. No text message is sent, so the number is not
/// proven to be theirs, and a reset-password email cannot reach it.
const phoneLoginDomain = 'phone.lukulu-bread-of-life.app';

/// A typed phone number as digits with the country code (Zambia, 260, when none
/// is given), or null when it cannot be a phone number.
///
/// `0971 234 567`, `+260 97 1234567`, `260971234567` and `971234567` are all
/// `260971234567`.
String? normalizePhone(String raw) {
  var d = raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');
  final plus = d.startsWith('+');
  if (plus) d = d.substring(1);
  if (d.startsWith('00')) d = d.substring(2);
  if (d.isEmpty || !RegExp(r'^\d+$').hasMatch(d)) return null;
  if (!plus && d.startsWith('0')) {
    d = '260${d.substring(1)}';
  } else if (!plus && d.length == 9) {
    d = '260$d';
  }
  if (d.length < 11 || d.length > 15) return null;
  // A Zambian number is 260 followed by nine digits.
  if (d.startsWith('260') && d.length != 12) return null;
  return d;
}

/// How a phone number is shown, e.g. `+260971234567`.
String formatPhone(String digits) => '+$digits';

/// The made-up sign-in address for a normalised phone number.
String phoneLoginEmail(String digits) => '$digits@$phoneLoginDomain';

/// Whether [email] is one of those made-up addresses.
bool isPhoneLoginEmail(String? email) =>
    email != null && email.toLowerCase().endsWith('@$phoneLoginDomain');

/// The phone number inside a made-up address, or null.
String? phoneFromLoginEmail(String? email) =>
    isPhoneLoginEmail(email) ? email!.split('@').first : null;

/// Whether what was typed is meant as a phone number rather than an email.
bool looksLikePhone(String input) {
  final t = input.trim();
  if (t.contains('@')) return false;
  return RegExp(r'\d').allMatches(t).length >= 7;
}
