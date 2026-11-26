import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'giving_record.dart';

/// The church's "Sunday Service Summary Report" (the secretariat's two-page
/// paper form), filled in once for each service.
///
/// It is a record of the service. It does **not** create giving or attendance
/// records: those come from the Sunday Income Form, so nothing is counted twice.
enum ServiceType { routine, special }

extension ServiceTypeName on ServiceType {
  String get label => this == ServiceType.routine ? 'Routine' : 'Special';
}

/// The collections, in the order they are printed on the paper form.
const serviceCollectionOrder = <GivingCategory>[
  GivingCategory.pledge,
  GivingCategory.thanksgiving,
  GivingCategory.seed,
  GivingCategory.offering,
  GivingCategory.tithe,
];

/// How the paper form names each collection.
String serviceCollectionLabel(GivingCategory c) => switch (c) {
      GivingCategory.pledge => 'Pledges',
      GivingCategory.thanksgiving => 'Thanks Giving',
      GivingCategory.seed => 'Seed',
      GivingCategory.offering => 'Offering',
      GivingCategory.tithe => 'Tithe',
    };

const serviceShortMaxLength = 120;
const serviceSummaryMaxLength = 6000;
const serviceMaxRows = 30;
const serviceMaxPeople = 100000;
const serviceMaxAmount = 10000000.0;

/// A testimony: who gave it and what it was, in summary.
class Testimony {
  const Testimony({this.name = '', this.summary = ''});

  final String name;
  final String summary;

  bool get isEmpty => name.trim().isEmpty && summary.trim().isEmpty;

  Map<String, dynamic> toMap() => {'name': name, 'summary': summary};

  static Testimony fromMap(Object? raw) => raw is Map
      ? Testimony(
          name: raw['name'] as String? ?? '', summary: raw['summary'] as String? ?? '')
      : const Testimony();
}

/// A visitor and where they come from.
class Visitor {
  const Visitor({this.name = '', this.origin = ''});

  final String name;
  final String origin;

  bool get isEmpty => name.trim().isEmpty && origin.trim().isEmpty;

  Map<String, dynamic> toMap() => {'name': name, 'origin': origin};

  static Visitor fromMap(Object? raw) => raw is Map
      ? Visitor(name: raw['name'] as String? ?? '', origin: raw['origin'] as String? ?? '')
      : const Visitor();
}

class ServiceReport {
  const ServiceReport({
    this.id = '',
    required this.date,
    this.serviceType = ServiceType.routine,
    this.openingPrayerBy = '',
    this.intercessionBy = '',
    this.praisesBy = '',
    this.worshipBy = '',
    this.leadersOnDuty = const [],
    this.announcementsBy = '',
    this.exhortationBy = '',
    this.exhortationTitle = '',
    this.exhortationReading = '',
    this.preacher = '',
    this.wordTitle = '',
    this.wordReading = '',
    this.wordSummary = '',
    this.testimonies = const [],
    this.closingPrayerBy = '',
    this.men = 0,
    this.women = 0,
    this.children = 0,
    this.collections = const {},
    this.noticesBy = '',
    this.visitors = const [],
    this.notices = const [],
    this.specialOffering = const [],
    this.nextWeekLeaders = const [],
    this.secretaryName = '',
    this.treasurerName = '',
    this.elderName = '',
    this.secretarySignature,
    this.treasurerSignature,
    this.elderSignature,
    this.enteredBy = '',
    this.enteredByUid = '',
    this.createdAt,
  });

  final String id;
  final DateTime date;
  final ServiceType serviceType;

  // Page 1: the programme.
  final String openingPrayerBy;
  final String intercessionBy;
  final String praisesBy;
  final String worshipBy;
  final List<String> leadersOnDuty;
  final String announcementsBy;
  final String exhortationBy;
  final String exhortationTitle;
  final String exhortationReading;
  final String preacher;
  final String wordTitle;
  final String wordReading;
  final String wordSummary;
  final List<Testimony> testimonies;
  final String closingPrayerBy;
  final int men;
  final int women;
  final int children;

  /// Kwacha collected, by kind.
  final Map<GivingCategory, double> collections;

  // Page 2: announcements.
  final String noticesBy;
  final List<Visitor> visitors;

  /// Special announcements: absent with apology, patients, new babies and so on.
  final List<String> notices;

  /// Tithers, honoured pledges, offering in absentia, calls for pledges...
  final List<String> specialOffering;
  final List<String> nextWeekLeaders;

  final String secretaryName;
  final String treasurerName;
  final String elderName;
  final Uint8List? secretarySignature;
  final Uint8List? treasurerSignature;
  final Uint8List? elderSignature;

  final String enteredBy;
  final String enteredByUid;
  final DateTime? createdAt;

  int get attendanceTotal => men + women + children;

  double get collectionsTotal =>
      collections.values.fold(0.0, (total, v) => total + v);

  static Uint8List? _bytes(Object? raw) =>
      raw is String && raw.isNotEmpty ? base64Decode(raw) : null;

  static List<String> _strings(Object? raw) => [
        for (final x in (raw as List?) ?? const [])
          if (x is String) x,
      ];

  factory ServiceReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ServiceReport.fromMap(doc.id, doc.data() ?? const {});

  factory ServiceReport.fromMap(String id, Map<String, dynamic> d) {
    String s(String k) => d[k] as String? ?? '';
    int n(String k) => d[k] is num ? (d[k] as num).toInt() : 0;
    final rawDate = d['date'];
    final when = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
    final money = d['collections'] is Map ? d['collections'] as Map : const {};
    return ServiceReport(
      id: id,
      date: DateTime(when.year, when.month, when.day),
      serviceType: d['serviceType'] == 'special' ? ServiceType.special : ServiceType.routine,
      openingPrayerBy: s('openingPrayerBy'),
      intercessionBy: s('intercessionBy'),
      praisesBy: s('praisesBy'),
      worshipBy: s('worshipBy'),
      leadersOnDuty: _strings(d['leadersOnDuty']),
      announcementsBy: s('announcementsBy'),
      exhortationBy: s('exhortationBy'),
      exhortationTitle: s('exhortationTitle'),
      exhortationReading: s('exhortationReading'),
      preacher: s('preacher'),
      wordTitle: s('wordTitle'),
      wordReading: s('wordReading'),
      wordSummary: s('wordSummary'),
      testimonies: [
        for (final t in (d['testimonies'] as List?) ?? const []) Testimony.fromMap(t),
      ],
      closingPrayerBy: s('closingPrayerBy'),
      men: n('men'),
      women: n('women'),
      children: n('children'),
      collections: {
        for (final c in serviceCollectionOrder)
          if (money[c.name] is num) c: (money[c.name] as num).toDouble(),
      },
      noticesBy: s('noticesBy'),
      visitors: [
        for (final v in (d['visitors'] as List?) ?? const []) Visitor.fromMap(v),
      ],
      notices: _strings(d['notices']),
      specialOffering: _strings(d['specialOffering']),
      nextWeekLeaders: _strings(d['nextWeekLeaders']),
      secretaryName: s('secretaryName'),
      treasurerName: s('treasurerName'),
      elderName: s('elderName'),
      secretarySignature: _bytes(d['secretarySignature']),
      treasurerSignature: _bytes(d['treasurerSignature']),
      elderSignature: _bytes(d['elderSignature']),
      enteredBy: s('enteredBy'),
      enteredByUid: s('enteredByUid'),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Everything the person can change (not who first entered it, or when).
  Map<String, dynamic> toContentMap() => {
        'date': Timestamp.fromDate(date),
        'serviceType': serviceType.name,
        'openingPrayerBy': openingPrayerBy,
        'intercessionBy': intercessionBy,
        'praisesBy': praisesBy,
        'worshipBy': worshipBy,
        'leadersOnDuty': leadersOnDuty,
        'announcementsBy': announcementsBy,
        'exhortationBy': exhortationBy,
        'exhortationTitle': exhortationTitle,
        'exhortationReading': exhortationReading,
        'preacher': preacher,
        'wordTitle': wordTitle,
        'wordReading': wordReading,
        'wordSummary': wordSummary,
        'testimonies': [for (final t in testimonies) t.toMap()],
        'closingPrayerBy': closingPrayerBy,
        'men': men,
        'women': women,
        'children': children,
        'collections': {for (final e in collections.entries) e.key.name: e.value},
        'noticesBy': noticesBy,
        'visitors': [for (final v in visitors) v.toMap()],
        'notices': notices,
        'specialOffering': specialOffering,
        'nextWeekLeaders': nextWeekLeaders,
        'secretaryName': secretaryName,
        'treasurerName': treasurerName,
        'elderName': elderName,
        if (secretarySignature != null)
          'secretarySignature': base64Encode(secretarySignature!),
        if (treasurerSignature != null)
          'treasurerSignature': base64Encode(treasurerSignature!),
        if (elderSignature != null) 'elderSignature': base64Encode(elderSignature!),
      };

  /// Written once, when the report is first saved.
  Map<String, dynamic> toMap() => {
        ...toContentMap(),
        'enteredBy': enteredBy,
        'enteredByUid': enteredByUid,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
