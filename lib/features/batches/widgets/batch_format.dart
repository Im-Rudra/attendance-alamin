// Small shared helpers of the batches feature: schedule text, billing pill,
// the dues mini-badge, a notice strip and navigation.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/widgets/theme_mapping.dart';
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

/// Circle initials from the first (distinguishing) word of a batch name, so
/// "সকালের ব্যাচ" and "সন্ধ্যা ব্যাচ" no longer both read "সব". At most two
/// grapheme clusters, never splitting a conjunct.
class BatchAvatar extends StatelessWidget {
  const BatchAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  static String initialsOf(String name) {
    final List<String> words =
        name.trim().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final List<String> g = words.first.characters.toList();
    if (g.length == 1) return g.first;
    return g[1].runes.length <= 2 ? g[0] + g[1] : g[0];
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: b.colors.accentTint, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          initialsOf(name),
          maxLines: 1,
          style: b.type.label.copyWith(color: b.colors.accent, fontSize: size * 0.36, height: 1.2),
        ),
      ),
    );
  }
}

/// A menu row for desktop overflow menus: leading icon, title, optional
/// destructive tone.
class BatchMenuRow extends StatelessWidget {
  const BatchMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final Color fg = destructive ? b.colors.danger : b.colors.text;
    return BhorPressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (BuildContext c, BhorStates st) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: BhorSpace.s12),
        decoration: BoxDecoration(
          color: st.hovered || st.pressed ? b.colors.soft : b.colors.soft.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(BhorRadius.control),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: BhorIconSize.chip, color: fg),
            const SizedBox(width: BhorSpace.s12),
            Expanded(child: Text(label, style: b.type.body.copyWith(color: fg))),
          ],
        ),
      ),
    );
  }
}

/// "অগ্রিম" / "মাস শেষে": plain words, never "prepaid" jargon.
class BillingPill extends StatelessWidget {
  const BillingPill({super.key, required this.type});

  final BillingType type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String label = type == BillingType.prepaid ? l10n.batchPillAdvance : l10n.batchPillAfter;
    return BhorTag(label: label, tone: BhorTone.accent);
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
    final String label = context.l10n.batchDuesCount(context.fmt.number(d.count));
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: BhorTag.severity(level: worst.severityLevel, label: label, icon: worst.icon),
    );
  }
}

/// A due level as a tag: icon + word, never colour alone. [monthCount] > 1
/// adds "3 months due".
class DueTag extends StatelessWidget {
  const DueTag({super.key, required this.level, this.monthCount = 1});

  final DueLevel level;
  final int monthCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<String> parts = <String>[
      level.label(l10n),
      if (monthCount > 1) l10n.uiMonthsDue(context.fmt.number(monthCount)),
    ];
    return BhorTag.severity(level: level.severityLevel, label: parts.join(' · '), icon: level.icon);
  }
}

/// A tinted strip with an icon and a sentence: [warn] uses the danger tint,
/// otherwise a quiet hairline box. Announced as a live region.
class BatchNotice extends StatelessWidget {
  const BatchNotice({super.key, required this.text, this.warn = true, this.icon, this.children = const <Widget>[]});

  final String text;
  final bool warn;
  final IconData? icon;

  /// Extra lines under the sentence.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final BhorColors c = b.colors;
    final Color fg = warn ? c.danger : c.text2;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: warn ? c.dangerBg : c.surface2,
          borderRadius: BorderRadius.circular(BhorRadius.control),
          border: Border.all(color: warn ? c.danger : c.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(BhorSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon ?? (warn ? BhorIcons.warning : BhorIcons.checkCircle), color: fg),
                  const SizedBox(width: BhorSpace.s8),
                  Expanded(child: Text(text, style: b.type.body.copyWith(color: fg))),
                ],
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
