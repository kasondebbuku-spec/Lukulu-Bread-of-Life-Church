import 'phone_login.dart';

/// Ministries people commonly serve in, offered as suggestions. Anything else can
/// be typed.
const suggestedMinistries = <String>[
  'Choir',
  'Praise and Worship',
  'Women of Integrity',
  "Men's Fellowship",
  'Youth',
  "Children's Ministry",
  'Sunday School',
  'Ushers',
  'Intercessors',
  'Evangelism',
  'Media',
  'Welfare',
];

const ministryTextMaxLength = 60;

/// A short, stable key for a ministry's name (`Women of Integrity` ->
/// `women-of-integrity`). Used to match a person's position to the reports they
/// send.
String ministryKey(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// A place someone holds in a ministry, such as Leader of the Choir.
class MinistryPosition {
  const MinistryPosition({required this.ministry, required this.title});

  final String ministry;

  /// What they are called there, e.g. `Leader`, `Secretary`, `Treasurer`.
  final String title;

  String get key => ministryKey(ministry);

  /// e.g. `Choir · Leader`.
  String get label => '$ministry · $title';

  Map<String, dynamic> toMap() => {'ministry': ministry, 'title': title};

  @override
  bool operator ==(Object other) =>
      other is MinistryPosition && other.ministry == ministry && other.title == title;

  @override
  int get hashCode => Object.hash(ministry, title);

  /// Reads `{ministry, title}`, or null when it is not usable.
  static MinistryPosition? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final m = raw['ministry'];
    final t = raw['title'];
    if (m is! String || t is! String) return null;
    final ministry = m.trim();
    final title = t.trim();
    if (ministry.isEmpty || title.isEmpty || ministryKey(ministry).isEmpty) return null;
    return MinistryPosition(ministry: ministry, title: title);
  }
}

/// The positions held, keyed by [ministryKey]: `{choir: {ministry, title}}`.
/// One position per ministry.
Map<String, MinistryPosition> parsePositions(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, MinistryPosition>{};
  raw.forEach((k, v) {
    final p = MinistryPosition.fromMap(v);
    if (k is String && p != null) out[k] = p;
  });
  return out;
}

/// What a ministry's name or a position's title must look like.
String? validateMinistryText(String? v, {required String what}) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Enter $what';
  if (t.length > ministryTextMaxLength) return 'Keep $what under $ministryTextMaxLength letters';
  if (what == 'the ministry' && ministryKey(t).isEmpty) return 'Use letters or numbers';
  return null;
}

/// How a person appears in the leaders directory and the contact they gave.
class LeaderContact {
  const LeaderContact({this.email, this.phone});

  final String? email;

  /// Digits with the country code.
  final String? phone;

  bool get isEmpty => (email ?? '').isEmpty && (phone ?? '').isEmpty;
  String? get phoneText => phone == null || phone!.isEmpty ? null : formatPhone(phone!);
}
