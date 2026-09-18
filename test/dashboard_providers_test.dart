import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/models/church_event.dart';
import 'package:church_cms/repositories/repository_providers.dart';

void main() {
  test('Upcoming events exclude past days, include today, and sort by date',
      () async {
    final now = DateTime(2026, 9, 9, 12);
    ChurchEvent event(String id, DateTime date) => ChurchEvent(
          id: id,
          title: id,
          date: date,
          location: 'Church',
        );
    final container = ProviderContainer(overrides: [
      dashboardClockProvider.overrideWith((ref) => Stream.value(now)),
      eventsProvider.overrideWith((ref) => Stream.value([
            event('future', DateTime(2026, 9, 12)),
            event('past', DateTime(2026, 9, 8)),
            event('today', DateTime(2026, 9, 9)),
          ])),
    ]);
    addTearDown(container.dispose);
    await container.read(dashboardClockProvider.future);
    await container.read(eventsProvider.future);
    expect(container.read(upcomingEventsProvider).requireValue.map((e) => e.id),
        ['today', 'future']);
  });

  test('Upcoming events preserve data errors', () async {
    final container = ProviderContainer(overrides: [
      eventsProvider.overrideWith((ref) => Stream.error(StateError('offline'))),
    ]);
    addTearDown(container.dispose);
    await expectLater(container.read(eventsProvider.future), throwsStateError);
    expect(container.read(upcomingEventsProvider).hasError, isTrue);
  });
}
