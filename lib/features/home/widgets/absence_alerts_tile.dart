// Absence alerts (Product F16, scenario 13): students absent in the last three
// held sessions of a batch, each with a call / copy-number button and a dismiss
// that lasts until their next absence (`absence_dismissed:<enrollmentId>`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/features/home/widgets/tile_frame.dart';

class AbsenceAlertsTile extends ConsumerWidget {
  const AbsenceAlertsTile({
    super.key,
    this.maxItems,
    this.hideWhenEmpty = false,
    this.gapBelow = 0,
  });

  /// Show at most this many alerts plus a "N more" line (null = all).
  final int? maxItems;

  /// Render nothing when there is no alert (phone and medium pages, where an
  /// empty "everyone attends" card would only add noise).
  final bool hideWhenEmpty;

  /// Space under the tile, only added when it is shown.
  final double gapBelow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final List<AbsenceAlert>? alerts = ref.watch(absenceAlertsProvider).value;

    final Widget header = TileHeader(
      icon: Icons.notifications_active_outlined,
      title: l10n.todayAlertsTitle,
    );
    if (alerts == null) {
      return hideWhenEmpty
          ? const SizedBox.shrink()
          : TileFrame(header: header, child: const SizedBox(height: 96));
    }
    if (alerts.isEmpty) {
      if (hideWhenEmpty) return const SizedBox.shrink();
      return TileFrame(
        header: header,
        child: TileMessage(icon: Icons.verified_outlined, message: l10n.todayAlertsEmpty),
      );
    }

    final int limit = maxItems ?? alerts.length;
    final List<AbsenceAlert> shown = alerts.length > limit ? alerts.sublist(0, limit) : alerts;
    final int more = alerts.length - shown.length;

    final Widget tile = TileFrame(
      header: header,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AbsenceAlert a in shown)
            _AlertRow(key: ValueKey<String>('today-alert-${a.enrollmentId}'), alert: a),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.todayAlertsMore(context.fmt.number(more)),
                style: tt.labelMedium?.copyWith(color: tokens.textSecondary),
              ),
            ),
        ],
      ),
    );
    return gapBelow == 0
        ? tile
        : Padding(padding: EdgeInsets.only(bottom: gapBelow), child: tile);
  }
}

class _AlertRow extends ConsumerWidget {
  const _AlertRow({super.key, required this.alert});

  final AbsenceAlert alert;

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      await ref.read(localMetaRepositoryProvider).setRaw(
            LocalMetaKeys.absenceDismissed(alert.enrollmentId),
            alert.lastSessionId,
          );
    } on Object catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    final String? phone = alert.student.callNumber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          InitialsAvatar(name: alert.student.name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.todayAlertLine(alert.student.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  alert.batch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          if (phone != null)
            IconButton(
              tooltip: ContactActions.label(l10n),
              icon: Icon(ContactActions.icon),
              onPressed: () => ContactActions.callOrCopy(context, phone),
            ),
          IconButton(
            tooltip: l10n.todayAlertDismiss,
            icon: const Icon(Icons.close),
            onPressed: () => _dismiss(context, ref),
          ),
        ],
      ),
    );
  }
}
