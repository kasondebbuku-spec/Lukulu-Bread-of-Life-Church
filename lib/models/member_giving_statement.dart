import 'giving_record.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String monthName(int month) => _months[month - 1];

/// One currency's part of a member's yearly statement.
class CurrencyStatement {
  const CurrencyStatement({
    required this.currency,
    required this.total,
    required this.byMonth,
    required this.byCategory,
    required this.uncategorized,
    required this.records,
  });

  final String currency;
  final double total;

  /// Index 0 = January ... 11 = December.
  final List<double> byMonth;
  final Map<GivingCategory, double> byCategory;
  final double uncategorized;

  /// Oldest first.
  final List<GivingRecord> records;
}

/// A member's own giving for one calendar year, kept separate per currency.
class MemberGivingStatement {
  const MemberGivingStatement({
    required this.memberName,
    required this.year,
    required this.currencies,
  });

  final String memberName;
  final int year;
  final List<CurrencyStatement> currencies;

  bool get isEmpty => currencies.isEmpty;

  /// Years that have at least one record, newest first.
  static List<int> yearsWithGiving(List<GivingRecord> records) =>
      (records.map((r) => r.date.year).toSet().toList()..sort((a, b) => b.compareTo(a)));

  factory MemberGivingStatement.compute({
    required String memberName,
    required int year,
    required List<GivingRecord> records,
  }) {
    final byCurrency = <String, List<GivingRecord>>{};
    for (final r in records) {
      if (r.date.year == year) byCurrency.putIfAbsent(r.currency, () => []).add(r);
    }

    // ZMW first, then the rest alphabetically.
    final codes = byCurrency.keys.toList()
      ..sort((a, b) {
        if (a == 'ZMW') return -1;
        if (b == 'ZMW') return 1;
        return a.compareTo(b);
      });

    final sections = <CurrencyStatement>[];
    for (final code in codes) {
      final list = byCurrency[code]!..sort((a, b) => a.date.compareTo(b.date));
      final months = List<double>.filled(12, 0);
      final categories = <GivingCategory, double>{};
      var uncategorized = 0.0;
      var total = 0.0;
      for (final r in list) {
        total += r.amount;
        months[r.date.month - 1] += r.amount;
        final c = r.category;
        if (c == null) {
          uncategorized += r.amount;
        } else {
          categories[c] = (categories[c] ?? 0) + r.amount;
        }
      }
      sections.add(CurrencyStatement(
        currency: code,
        total: total,
        byMonth: months,
        byCategory: categories,
        uncategorized: uncategorized,
        records: list,
      ));
    }

    return MemberGivingStatement(memberName: memberName, year: year, currencies: sections);
  }

  String get pdfFilename => 'giving-statement-$year.pdf';
}
