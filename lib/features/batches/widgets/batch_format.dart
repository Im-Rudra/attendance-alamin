// Small shared helpers of the batches feature: schedule text, billing pill,
// the dues mini-badge and navigation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/schedule.dart';
import 'package:attendance_alamin/features/batches/controllers/batch_providers.dart';

/// "শনি, সোম · বিকাল ৪:০০–৫:০০" when every slot has the same time, else one
/// "শনি বিকাল ৪:০০–৫:০০" entry per slot. Empty for no slots.
String scheduleSummary(AppFormat fmt, List<Slot> slots) {
  if (slots.isEmpty) return '';
  final List<Slot> sorted = <Slot>[...slots]..sort((Slot a, Slot b) {
      final int c = kWeekOrder.indexOf(a.weekday).compareTo(kWeekOrder.indexOf(b.weekday));
      return c != 0 ? c : a.startMin.compareTo(b.startMin);
    });
  final Set<(int, int)> times = <(int, int)>{for (final Slot s in sorted) (s.startMin, s.endMin)};
  if (times.length == 1) {
    final List<int> days = <int>[];
    for (final Slot s in sorted) {
      if (!days.contains(s.weekday)) days.add(s.weekday);
    }
    final (int, int) t = times.first;
    return '${days.map(fmt.weekdayShort).join(', ')} · ${fmt.timeRange(t.$1, t.$2)}';
  }
  return sorted
      .map((Slot s) => '${fmt.weekdayShort(s.weekday)} ${fmt.timeRange(s.startMin, s.endMin)}')
      .join(' · ');
}

/// Opens [path] as the selection on wide windows, as a pushed page otherwise.
void openPath(BuildContext context, String path) {
  if (WindowClass.of(context).isWide) {
    context.go(path);
  } else {
    context.push(path);
  }
}

/// "অগ্রিম" / "মাস শেষে": plain words, never "prepaid" jargon.
class BillingPill extends StatelessWidget {
  const BillingPill({super.key, required this.type});

  final BillingType type;

  @override
  Widget build(BuildContext context) {
    final tokens = context.aurora;
    final l10n = context.l10n;
    final String label = type == BillingType.prepaid ? l10n.batchPillAdvance : l10n.batchPillAfter;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: ShapeDecoration(color: tokens.accentContainer, shape: const StadiumBorder()),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tokens.onAccentContainer),
      ),
    );
  }
}

/// "৫ বাকি" in the batch's worst severity colour; nothing when no dues.
class BatchDuesBadge extends ConsumerWidget {
  const BatchDuesBadge({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BatchDuesSummary? d = ref.watch(batchDuesProvider(batchId)).value;
    final DueLevel? worst = d?.worst;
    if (d == null || worst == null || d.count == 0) return const SizedBox.shrink();
    final sev = context.severity;
    final SeverityLevel s = worst.severityLevel;
    final Color text = sev.badgeText(s);
    final Color? border = sev.badgeBorder(s);
    final String label = context.l10n.batchDuesCount(context.fmt.number(d.count));
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: ShapeDecoration(
          color: sev.badgeFill(s),
          shape: StadiumBorder(
            side: border == null
                ? BorderSide.none
                : BorderSide(color: border, width: sev.badgeBorderWidth(s)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(worst.icon, size: 14, color: text),
            const SizedBox(width: 4),
            Text(label, maxLines: 1, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: text)),
          ],
        ),
      ),
    );
  }
}
