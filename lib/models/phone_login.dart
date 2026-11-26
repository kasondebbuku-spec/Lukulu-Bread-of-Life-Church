/// Signing in with a phone number instead of an email.
///
/// Firebase signs people in with an email and a password. For someone with no
/// email, their phone number is turned into a private, made-up address that
/// they never see (`260971234567@phone.lukulu-bread-of-life.app`) and used with
/// the password they choose. No text message is sent, so the number is not
/// proven to be theirs, and a reset-password email cannot reach it.
const phoneLoginDomain = 'phone.lukulu-bread-of-life.app';

final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\d');
final _notDigit = RegExp(r'[^0-9]');

/// A typed phone number as digits with the country code (Zambia, 260, when none
/// is given), or null when it cannot be a phone number.
///
/// `0971 234 567`, `+260 97 1234567`, `+260 0971234567`, `260971234567` and
/// `971234567` are all `260971234567`. Only the digits (and a leading `+`)
/// matter: spaces of any kind, dashes, brackets, dots, slashes, and the invisible
/// marks that come along when a number is copied from contacts or WhatsApp are
/// layout and are ignored. Letters or `@` mean it is not a phone number.
String? normalizePhone(String raw) {
  if (raw.contains('@') || _letter.hasMatch(raw)) return null;
  final kept = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  final plus = kept.startsWith('+');
  var d = kept.replaceAll('+', '');
  if (d.startsWith('00')) d = d.substring(2);
  if (d.isEmpty) return null;
  if (!plus && d.startsWith('0')) {
    d = '260${d.substring(1)}';
  } else if (!plus && d.length == 9) {
    d = '260$d';
  }
  // `+260 097...`: the local leading zero left in after the country code.
  if (d.startsWith('2600') && d.length == 13) d = '260${d.substring(4)}';
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

/// Whether someone is in the middle of typing a phone number: digits and layout
/// only, no letters and no `@`.
bool isPhoneAttempt(String input) =>
    !input.contains('@') && !_letter.hasMatch(input) && _digit.hasMatch(input);

/// Whether what was typed is meant as a phone number rather than an email.
bool looksLikePhone(String input) =>
    isPhoneAttempt(input) && _digit.allMatches(input).length >= 7;

/// A number set out the way people read it, e.g. `+260 97 123 4567`.
String prettyPhone(String digits) => digits.startsWith('260') && digits.length == 12
    ? '+260 ${digits.substring(3, 5)} ${digits.substring(5, 8)} ${digits.substring(8)}'
    : '+$digits';

/// Plain words about a number that is not right yet, saying what is wrong.
String phoneProblem(String input) {
  final d = input.replaceAll(_notDigit, '');
  String count(int wanted, String like) => d.length < wanted
      ? 'Too short: a number like $like has $wanted digits (this has ${d.length})'
      : 'Too long: a number like $like has $wanted digits (this has ${d.length})';
  if (!input.contains('+') && d.startsWith('0') && !d.startsWith('00')) {
    return count(10, '0971234567');
  }
  if (d.startsWith('260')) return count(12, '260971234567');
  return 'Enter a number like 0971234567 or +260971234567';
}

/// Splits [digits] into groups of the given sizes, with a space between.
String _grouped(String digits, List<int> sizes) {
  final parts = <String>[];
  var at = 0;
  for (final size in sizes) {
    if (at >= digits.length) break;
    final end = at + size > digits.length ? digits.length : at + size;
    parts.add(digits.substring(at, end));
    at = end;
  }
  return parts.join(' ');
}

/// What the sign-in box should show for what was typed or pasted: a Zambian
/// number is spaced as `097 123 4567` or `+260 97 123 4567`, anything else that
/// is a phone number is left alone, and an email never keeps spaces.
String formatSignInEntry(String typed) {
  if (!isPhoneAttempt(typed)) {
    // An email (or the start of one). Spaces are never part of it.
    return _letter.hasMatch(typed) || typed.contains('@')
        ? typed.replaceAll(RegExp(r'\s'), '')
        : typed;
  }
  var kept = typed.replaceAll(RegExp(r'[^0-9+]'), '');
  final plus = kept.startsWith('+');
  var d = kept.replaceAll('+', '');
  if (plus && d.startsWith('260')) {
    if (d.startsWith('2600') && d.length >= 13) d = '260${d.substring(4)}';
    return d.length <= 12 ? '+${_grouped(d, const [3, 2, 3, 4])}' : '+$d';
  }
  if (!plus && d.startsWith('0') && !d.startsWith('00') && d.length <= 10) {
    return _grouped(d, const [3, 3, 4]);
  }
  return plus ? '+$d' : d;
}
