// The hero card of Today (UX 3, 2g): date, the current or next class with a
// countdown, and the near-white pill that opens its roll call. Also the
// no-class, all-done, other-day and no-batch variants.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/domain/models/batch.dart';
import 'package:attendance_alamin/features/classes/classes_entry.dart';
import 'package:attendance_alamin/features/onboarding/onboarding_entry.dart';
import 'package:attendance_alamin/features/home/controllers/today_model.dart';
import 'package:attendance_alamin/features/home/controllers/today_providers.dart';
import 'package:attendance_alamin/features/home/widgets/today_actions.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// Hero card of [date]. [fill] is true inside the bento, where the tile has a
/// fixed height the card must fill.
class HeroClassCard extends ConsumerWidget {
  const HeroClassCard({super.key, required this.date, this.fill = false});

  final LocalDate date;
  final bool fill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HeroState? hero = ref.watch(todayHeroProvider(date)).value;
    if (hero == null) {
      return _HeroShell(
        fill: fill,
        texts: const <Widget>[SizedBox(height: 96)],
        actions: const <Widget>[],
      );
    }
    final l10n = context.l10n;
    final AppFormat fmt = context.fmt;
    final g = context.gradients;
    final TextTheme tt = Theme.of(context).textTheme;

    final TextStyle? small =
        tt.labelLarge?.copyWith(color: g.heroTextSecondary);
    final TextStyle? status =
        tt.titleMedium?.copyWith(color: g.heroText, fontWeight: FontWeight.w600);
    final TextStyle? title =
        tt.headlineSmall?.copyWith(color: g.heroText, fontWeight: FontWeight.w700);
    final TextStyle? line = tt.bodyLarge?.copyWith(color: g.heroTextSecondary);

    Widget t(String text, TextStyle? style, {int maxLines = 2}) => Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );

    final List<Widget> texts = <Widget>[];
    final List<Widget> actions = <Widget>[];
    final DayClass? focus = hero.focus;

    switch (hero.kind) {
      case HeroKind.noBatches:
        texts
          ..add(t(l10n.todaySetupTitle, title))
          ..add(const SizedBox(height: 6))
          ..add(t(l10n.todaySetupBody, line, maxLines: 3));
        actions.add(HeroPillButton(
          label: l10n.todaySetupButton,
          onPressed: () => pushRoute(context, Routes.batchNew),
        ));
      case HeroKind.noClasses:
        texts
          ..add(t(fmt.weekdayDate(date), small, maxLines: 1))
          ..add(const SizedBox(height: 6))
          ..add(t(l10n.todayHeroRest, title));
        actions
          ..add(HeroPillButton(
            label: l10n.todayAddExtraLong,
            onPressed: () => showExtraClassSheet(context, date: date),
          ))
          ..add(_HeroTextButton(
            label: l10n.todayOtherBatchAttendance,
            onPressed: () => _pickBatch(context, ref),
          ));
      case HeroKind.allDone:
        texts
          ..add(t(fmt.weekdayDate(date), small, maxLines: 1))
          ..add(const SizedBox(height: 6))
          ..add(Row(
            children: <Widget>[
              Icon(Icons.check_circle, color: g.heroText, size: 28),
              const SizedBox(width: 8),
              Expanded(child: t(l10n.todayHeroDone, title)),
            ],
          ))
          ..add(const SizedBox(height: 4))
          ..add(t(
            l10n.todayHeroDoneSub(fmt.number(hero.taken), fmt.number(hero.total)),
            line,
            maxLines: 1,
          ));
      case HeroKind.otherDay:
        final String dateText = fmt.weekdayDate(date);
        texts
          ..add(t(
            hero.total == 0
                ? l10n.todayHeroOtherDayNone(dateText)
                : l10n.todayHeroOtherDay(dateText, fmt.number(hero.total)),
            title,
          ));
        if (hero.total > 0) {
          texts
            ..add(const SizedBox(height: 4))
            ..add(t(
              l10n.todayHeroDoneSub(
                  fmt.number(hero.taken), fmt.number(hero.total)),
              line,
              maxLines: 1,
            ));
        }
        if (focus != null) {
          actions.add(CoachMarkAnchor(
            child: HeroPillButton(
              label: l10n.todayTakeAttendance,
              onPressed: () => openRollCall(context, focus.occ),
            ),
          ));
        }
      case HeroKind.current:
      case HeroKind.next:
      case HeroKind.pending:
        texts.add(t(fmt.weekdayDate(date), small, maxLines: 1));
        texts.add(const SizedBox(height: 6));
        texts.add(t(_statusText(l10n, fmt, hero), status, maxLines: 1));
        if (focus != null) {
          texts
            ..add(const SizedBox(height: 4))
            ..add(t(l10n.clsClassLabel(focus.subjectName, focus.batch.name), title))
            ..add(const SizedBox(height: 2))
            ..add(t(fmt.timeRange(focus.startMin, focus.endMin), line, maxLines: 1));
          actions.add(CoachMarkAnchor(
            child: HeroPillButton(
              label: l10n.todayTakeAttendance,
              onPressed: () => openRollCall(context, focus.occ),
            ),
          ));
        }
    }

    return _HeroShell(fill: fill, texts: texts, actions: actions);
  }

  String _statusText(AppLocalizations l10n, AppFormat fmt, HeroState hero) {
    switch (hero.kind) {
      case HeroKind.current:
        return l10n.todayHeroNow(_leftText(l10n, fmt, hero.minutes));
      case HeroKind.next:
        return l10n.todayHeroNext(_inText(l10n, fmt, hero.minutes));
      case HeroKind.pending:
        return l10n.todayHeroPending;
      case HeroKind.noBatches:
      case HeroKind.noClasses:
      case HeroKind.allDone:
      case HeroKind.otherDay:
        return '';
    }
  }

  Future<void> _pickBatch(BuildContext context, WidgetRef ref) async {
    final List<Batch>? batches = ref.read(todayBatchesProvider).value;
    if (batches == null || batches.isEmpty) return;
    await showBatchPickerSheet(context, date: date, batches: batches);
  }
}

String _inText(AppLocalizations l10n, AppFormat fmt, int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h == 0) return l10n.todayInMinutes(fmt.number(m));
  if (m == 0) return l10n.todayInHours(fmt.number(h));
  return l10n.todayInHoursMinutes(fmt.number(h), fmt.number(m));
}

String _leftText(AppLocalizations l10n, AppFormat fmt, int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h == 0) return l10n.todayLeftMinutes(fmt.number(m));
  return l10n.todayLeftHoursMinutes(fmt.number(h), fmt.number(m));
}

/// Lays the hero texts and actions out inside the [HeroCard]. On a phone the
/// card wraps its content with the actions below; in the bento it fills the
/// tile (actions beside the text when the tile is short).
class _HeroShell extends StatelessWidget {
  const _HeroShell({required this.fill, required this.texts, required this.actions});

  final bool fill;
  final List<Widget> texts;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final Widget textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: texts,
    );
    final Widget actionWrap = Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    if (!fill) {
      return HeroCard(
        cta: actions.isEmpty
            ? null
            : Align(alignment: AlignmentDirectional.centerEnd, child: actionWrap),
        child: textColumn,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        // HeroCard pads its content by 20 on every side.
        final double inner = c.hasBoundedHeight && c.maxHeight > 40 ? c.maxHeight - 40 : 0;
        final bool beside = inner < 190 && actions.isNotEmpty;
        final Widget body = beside
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: textColumn),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: actions,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  textColumn,
                  if (actions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Align(alignment: AlignmentDirectional.centerEnd, child: actionWrap),
                  ],
                ],
              );
        return HeroCard(
          child: SizedBox(
            height: inner,
            width: double.infinity,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: inner),
                child: body,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A quiet text button for the hero card's second action.
class _HeroTextButton extends StatelessWidget {
  const _HeroTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.gradients;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: g.heroText,
        minimumSize: const Size(48, 48),
      ),
      onPressed: onPressed,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
