import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/constants/daily_verses.dart';
import 'package:church_cms/core/utils/greeting.dart';

void main() {
  test('greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 10, 9, 6)), 'Good Morning');
    expect(greetingFor(DateTime(2026, 10, 9, 12)), 'Good Afternoon');
    expect(greetingFor(DateTime(2026, 10, 9, 16, 59)), 'Good Afternoon');
    expect(greetingFor(DateTime(2026, 10, 9, 17)), 'Good Evening');
  });

  test('daily verse is stable within a day and rotates across days', () {
    final morning = verseForDate(DateTime(2026, 10, 9, 6));
    final night = verseForDate(DateTime(2026, 10, 9, 22));
    expect(morning.reference, night.reference);

    final nextDay = verseForDate(DateTime(2026, 10, 10));
    expect(nextDay.reference, isNot(morning.reference));
  });

  test('every year day maps to a verse', () {
    for (var d = 0; d < 366; d++) {
      expect(verseForDate(DateTime(2028, 1, 1).add(Duration(days: d))).text,
          isNotEmpty);
    }
  });
}
