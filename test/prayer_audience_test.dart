import 'package:flutter_test/flutter_test.dart';
import 'package:church_cms/core/providers/user_role_provider.dart';
import 'package:church_cms/models/prayer_request.dart';
import 'package:church_cms/repositories/prayer_repository.dart';

PrayerRequest _r(String id, DateTime? at,
        {PrayerAudience audience = PrayerAudience.pastor}) =>
    PrayerRequest(
      id: id,
      userId: 'u',
      userName: 'U',
      request: id,
      status: 'pending',
      audience: audience,
      createdAt: at,
    );

void main() {
  group('who may read which audience (mirrors firestore.rules)', () {
    UserAccess a(Set<UserRole> r) => UserAccess(r);

    test('the pastor reads everything', () {
      expect(a({UserRole.pastor}).readablePrayerAudiences,
          PrayerAudience.values.toSet());
    });
    test('an elder reads Pastor-and-Elders and All-leaders, not Pastor-only', () {
      expect(a({UserRole.elder}).readablePrayerAudiences,
          {PrayerAudience.pastorElders, PrayerAudience.leaders});
    });
    test('deacons, deaconesses, admin and secretariat read All-leaders only', () {
      for (final role in [
        UserRole.deacon,
        UserRole.deaconess,
        UserRole.admin,
        UserRole.secretariat,
      ]) {
        expect(a({role}).readablePrayerAudiences, {PrayerAudience.leaders},
            reason: role.name);
      }
    });
    test('members, finance, hospitality and oversight read none of them', () {
      for (final role in [
        UserRole.member,
        UserRole.finance,
        UserRole.hospitality,
        UserRole.oversight,
      ]) {
        expect(a({role}).readablePrayerAudiences, isEmpty, reason: role.name);
      }
    });
    test('someone with two roles gets both', () {
      expect(a({UserRole.elder, UserRole.pastor}).readablePrayerAudiences,
          PrayerAudience.values.toSet());
    });
  });

  group('audience values', () {
    test('round-trip through the stored text', () {
      for (final audience in PrayerAudience.values) {
        expect(PrayerAudience.fromValue(audience.value), audience);
      }
    });
    test('a request from before the choice existed counts as All leaders', () {
      expect(PrayerAudience.fromValue(null), PrayerAudience.leaders);
      expect(PrayerAudience.fromValue('something odd'), PrayerAudience.leaders);
    });
    test('a new request defaults to the most private choice', () {
      expect(PrayerAudience.defaultForNew, PrayerAudience.pastor);
    });
  });

  group('merging the requests a person may read', () {
    test('lists each request once, newest first', () {
      final merged = PrayerRequest.mergeNewestFirst([
        [_r('own', DateTime(2026, 3, 1)), _r('both', DateTime(2026, 3, 5))],
        [_r('both', DateTime(2026, 3, 5)), _r('shared', DateTime(2026, 3, 9))],
      ]);
      expect(merged.map((r) => r.id), ['shared', 'both', 'own']);
    });
    test('a request still waiting for its server time goes first', () {
      final merged = PrayerRequest.mergeNewestFirst([
        [_r('old', DateTime(2026, 1, 1)), _r('just-posted', null)],
      ]);
      expect(merged.first.id, 'just-posted');
    });
  });

  group('combining the live queries', () {
    test('waits for every source before showing anything, then updates',
        () async {
      final own = Stream.fromIterable([
        [_r('a', DateTime(2026, 1, 1))],
      ]);
      final shared = Stream.fromIterable([
        [_r('b', DateTime(2026, 2, 1))],
      ]);
      final lists = await PrayerRepository.mergeSnapshots([own, shared])
          .map((l) => l.map((r) => r.id).toList())
          .toList();
      expect(lists, isNotEmpty);
      expect(lists.last, ['b', 'a']);
      expect(lists.first, ['b', 'a'],
          reason: 'never a half-loaded list with only one source');
    });
    test('no sources gives an empty list', () async {
      expect(await PrayerRepository.mergeSnapshots(const []).first, isEmpty);
    });
  });
}
