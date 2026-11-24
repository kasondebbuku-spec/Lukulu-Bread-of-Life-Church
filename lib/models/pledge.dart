import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/currency_format.dart';
import '../core/utils/date_format.dart';
import 'giving_record.dart';

/// A pledge is "open" until the member cancels it. Whether it is fulfilled or
/// overdue is worked out from what has been given, never stored.
enum PledgeStatus { open, cancelled }

/// A member's promise to give an amount by a date.
class Pledge {
  const Pledge({
    required this.id,
    required this.userId,
    required this.memberName,
    required this.amount,
    required this.madeOn,
    required this.dueDate,
    this.note = '',
    this.status = PledgeStatus.open,
    this.createdBy = '',
    this.createdAt,
  });

  final String id;

  /// The member's account.
  final String userId;
  final String memberName;

  /// What was promised, in Kwacha.
  final double amount;

  /// The day the pledge was made. Only giving on or after this day counts
  /// towards it.
  final DateTime madeOn;
  final DateTime dueDate;
  final String note;
  final PledgeStatus status;

  /// Who typed it into the app (the member, or the Finance Officer for them).
  final String createdBy;
  final DateTime? createdAt;

  bool get isCancelled => status == PledgeStatus.cancelled;

  factory Pledge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    DateTime day(Object? v) {
      final d = v is Timestamp ? v.toDate() : DateTime.now();
      return DateTime(d.year, d.month, d.day);
    }

    final rawAmount = data['amount'];
    return Pledge(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      memberName: data['memberName'] as String? ?? '',
      amount: rawAmount is num ? rawAmount.toDouble() : 0,
      madeOn: day(data['madeOn']),
      dueDate: day(data['dueDate']),
      note: data['note'] as String? ?? '',
      status: data['status'] == 'cancelled' ? PledgeStatus.cancelled : PledgeStatus.open,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'memberName': memberName,
        'amount': amount,
        'madeOn': Timestamp.fromDate(madeOn),
        'dueDate': Timestamp.fromDate(dueDate),
        'note': note,
        'status': status.name,
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

/// How a pledge stands today.
enum PledgeState { fulfilled, overdue, dueSoon, upcoming, cancelled }

/// Reminders start this many days before the due date.
const pledgeReminderLeadDays = 7;

/// A pledge with what has been given towards it.
class PledgeProgress {
  const PledgeProgress(this.pledge, this.paid, this.state, this.daysToDue);

  final Pledge pledge;

  /// Given towards it so far, never more than the pledge itself.
  final double paid;
  final PledgeState state;

  /// Whole days until the due date: negative once it has passed.
  final int daysToDue;

  double get remaining => (pledge.amount - paid).clamp(0, double.infinity).toDouble();
  double get fraction => pledge.amount <= 0 ? 0 : (paid / pledge.amount).clamp(0.0, 1.0);

  /// Worth reminding about: still owing, and due soon or already late.
  bool get needsReminder => state == PledgeState.dueSoon || state == PledgeState.overdue;

  /// e.g. `ZMW 300.00 still to give on your ZMW 500.00 pledge, due Dec 25, 2026 (in 5 days).`
  String reminderText({bool forStaff = false}) {
    final who = forStaff ? '${pledge.memberName}\'s' : 'your';
    final due = formatDate(pledge.dueDate);
    final when = daysToDue > 1
        ? 'due $due (in $daysToDue days)'
        : daysToDue == 1
            ? 'due tomorrow ($due)'
            : daysToDue == 0
                ? 'due today ($due)'
                : daysToDue == -1
                    ? 'was due yesterday ($due)'
                    : 'was due $due (${-daysToDue} days ago)';
    return '${formatZmw(remaining)} still to give on $who ${formatZmw(pledge.amount)} pledge, $when.';
  }
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Works out each pledge's progress from the giving recorded in members'
/// names, as of [now].
///
/// Giving that counts: category Pledge, Kwacha, linked to the member's account,
/// dated on or after the day the pledge was made. When a member has several
/// open pledges, each payment goes to the oldest one first and any surplus
/// rolls on to the next. Cancelled pledges take nothing.
List<PledgeProgress> pledgeProgress({
  required List<Pledge> pledges,
  required List<GivingRecord> payments,
  required DateTime now,
}) {
  final today = _day(now);
  final paidBy = <String, double>{};

  final byUser = <String, List<Pledge>>{};
  for (final p in pledges.where((p) => !p.isCancelled)) {
    byUser.putIfAbsent(p.userId, () => []).add(p);
  }
  for (final entry in byUser.entries) {
    final open = entry.value
      ..sort((a, b) {
        final c = a.madeOn.compareTo(b.madeOn);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final owed = {for (final p in open) p.id: p.amount};
    final mine = payments
        .where((r) =>
            r.category == GivingCategory.pledge &&
            r.currency == 'ZMW' &&
            r.memberUserId == entry.key)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final r in mine) {
      var left = r.amount;
      for (final p in open) {
        if (left <= 0) break;
        if (_day(r.date).isBefore(p.madeOn)) continue; // before this pledge existed
        final need = owed[p.id]!;
        if (need <= 0) continue;
        final take = left < need ? left : need;
        owed[p.id] = need - take;
        paidBy[p.id] = (paidBy[p.id] ?? 0) + take;
        left -= take;
      }
    }
  }

  return [
    for (final p in pledges)
      () {
        final paid = p.isCancelled ? 0.0 : (paidBy[p.id] ?? 0);
        final days = _day(p.dueDate).difference(today).inDays;
        final PledgeState state;
        if (p.isCancelled) {
          state = PledgeState.cancelled;
        } else if (p.amount - paid <= 0.005) {
          state = PledgeState.fulfilled;
        } else if (days < 0) {
          state = PledgeState.overdue;
        } else if (days <= pledgeReminderLeadDays) {
          state = PledgeState.dueSoon;
        } else {
          state = PledgeState.upcoming;
        }
        return PledgeProgress(p, paid, state, days);
      }(),
  ]..sort((a, b) {
      // Open ones first, soonest due first; finished and cancelled last.
      int rank(PledgeProgress x) => switch (x.state) {
            PledgeState.overdue => 0,
            PledgeState.dueSoon => 1,
            PledgeState.upcoming => 2,
            PledgeState.fulfilled => 3,
            PledgeState.cancelled => 4,
          };
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.pledge.dueDate.compareTo(b.pledge.dueDate);
    });
}
