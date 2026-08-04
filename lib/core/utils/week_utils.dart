DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Sunday on/before [date]. Dart's DateTime.weekday is Monday=1..Sunday=7,
/// so `weekday % 7` gives days-since-Sunday (Sun->0, Mon->1, ..., Sat->6).
DateTime sundayOnOrBefore(DateTime date) {
  final d = _dateOnly(date);
  return d.subtract(Duration(days: d.weekday % 7));
}
