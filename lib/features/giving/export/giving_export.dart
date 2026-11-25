import '../../../core/utils/csv.dart';
import '../../../models/giving_record.dart';
import '../../../models/sunday_income_form.dart';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Every giving record, oldest first, one row each.
String givingCsv(List<GivingRecord> records) {
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  return toCsv([
    [
      'Date',
      'Category',
      'Description',
      'Amount',
      'Currency',
      'Linked to a member account',
      'Reference',
    ],
    for (final r in sorted)
      [
        _iso(r.date),
        r.category?.label ?? 'Uncategorized',
        r.memberName,
        r.amount,
        r.currency,
        r.memberUserId != null,
        r.id,
      ],
  ]);
}

/// Every Sunday Income Form, oldest first, one row each, with all the totals the
/// paper form calculates.
String incomeFormsCsv(
  List<SundayIncomeForm> forms,
  Map<String, double> valuesByKey,
) {
  final sorted = [...forms]..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.service.index.compareTo(b.service.index);
    });
  return toCsv([
    [
      'Date',
      'Service',
      for (final c in GivingCategory.values) c.label,
      'Forex (Kwacha value)',
      'Cheques',
      'Grand total',
      'Tithe of tithes ($titheOfTithesPercent% of tithe)',
      'Natsave deposit',
      'Total collection',
      'Total expenses',
      'Net amount (grand total less expenses)',
      'Men',
      'Women',
      'Children',
      'Attendance',
      'Prepared by',
      'Checked by',
      'Collected by',
      'Saved',
    ],
    for (final f in sorted)
      [
        _iso(f.date),
        f.service.label,
        for (final c in GivingCategory.values) f.categoryAmount(c, valuesByKey),
        f.totalForexKwacha,
        f.totalCheques,
        f.grandTotal(valuesByKey),
        f.titheOfTithes(valuesByKey),
        f.natsaveDeposit(valuesByKey),
        f.totalCollection(valuesByKey),
        f.totalExpenses,
        f.netAmount(valuesByKey),
        f.men,
        f.women,
        f.children,
        f.attendanceTotal,
        f.preparedBy,
        f.checkedBy,
        f.collectedBy,
        f.createdAt == null ? '' : _iso(f.createdAt!),
      ],
  ]);
}
