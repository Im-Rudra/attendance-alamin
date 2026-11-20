import 'package:attendance_alamin/core/ids/ids.dart';
import 'package:attendance_alamin/core/time/center_time.dart';
import 'package:attendance_alamin/domain/reminders/reminder_models.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';

/// Decides which class reminders to schedule (product 3.11). Pure: the caller
/// expands the effective occurrences (cancels, reschedules, extras already
/// applied) and passes them in; text is built later by the notification layer.
abstract final class ReminderPlanner {
  /// Effective lead in minutes: `null` batch lead -> [defaultLead]; `0` (from
  /// either source) = off -> `null`. Negative values are treated as off.
  static int? effectiveLead(int? batchLead, int defaultLead) {
    final lead = batchLead ?? defaultLead;
    return lead <= 0 ? null : lead;
  }

  /// Reminders for [occurrences] whose start lies within [windowDays] of
  /// [nowUtc] (inclusive) and whose fire time (start - lead) is still in the
  /// future. [leadByBatch] holds each batch's raw `reminderLead` (a missing
  /// batch or `null` = use [defaultLeadMin]; `0` = off). Result is sorted by
  /// fire time (then occ id) and capped at [maxCount] soonest.
  static List<PlannedReminder> plan({
    required List<Occurrence> occurrences,
    required Map<String, int?> leadByBatch,
    required int defaultLeadMin,
    required CenterTime center,
    required DateTime nowUtc,
    int windowDays = 7,
    int maxCount = 200,
  }) {
    final horizon = nowUtc.add(Duration(days: windowDays));
    final seen = <String>{};
    final out = <PlannedReminder>[];
    for (final o in occurrences) {
      final lead = effectiveLead(leadByBatch[o.batchId], defaultLeadMin);
      if (lead == null) continue;
      final startUtc = center.toUtc(o.date, o.startMin);
      if (startUtc.isAfter(horizon)) continue;
      final fireAt = startUtc.subtract(Duration(minutes: lead));
      if (!fireAt.isAfter(nowUtc)) continue;
      if (!seen.add(o.occ)) continue;
      out.add(PlannedReminder(
        id: Ids.fnv1a31(o.occ),
        fireAtUtc: fireAt,
        occ: o.occ,
        batchId: o.batchId,
        date: o.date,
        startMin: o.startMin,
        endMin: o.endMin,
        kind: o.kind,
        leadMin: lead,
        payload: payloadFor(o.occ),
      ));
    }
    out.sort((a, b) {
      final c = a.fireAtUtc.compareTo(b.fireAtUtc);
      return c != 0 ? c : a.occ.compareTo(b.occ);
    });
    if (maxCount >= 0 && out.length > maxCount) {
      return List<PlannedReminder>.unmodifiable(out.sublist(0, maxCount));
    }
    return List<PlannedReminder>.unmodifiable(out);
  }

  static const String _payloadPrefix = 'rollcall|';

  /// Notification payload that opens [occ]'s roll call.
  static String payloadFor(String occ) => '$_payloadPrefix$occ';

  /// Inverse of [payloadFor]; `null` for anything else.
  static String? occFromPayload(String? payload) {
    if (payload == null || !payload.startsWith(_payloadPrefix)) return null;
    final occ = payload.substring(_payloadPrefix.length);
    return occ.isEmpty ? null : occ;
  }
}
