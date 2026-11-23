// "সবাইকে মনে করিয়ে দিন" (UX 2d): walks through the listed students one share
// at a time. No SMS gateway: every message goes through the share sheet, the
// teacher picks WhatsApp / SMS / Messenger and comes back for the next one.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

/// Opens the walk-through for [rows] (the students still to remind today).
Future<void> showReminderWalkthrough(BuildContext context, List<DuesRow> rows) {
  return showBhorPanel<void>(
    context,
    kind: BhorPanelKind.confirm,
    title: context.l10n.duesWalkTitle,
    builder: (BuildContext ctx) => ReminderWalkthrough(rows: rows),
  );
}

/// The body of the walk-through dialog: progress, the current student, the
/// message to share, and Skip / Share.
class ReminderWalkthrough extends ConsumerStatefulWidget {
  const ReminderWalkthrough({super.key, required this.rows});

  final List<DuesRow> rows;

  @override
  ConsumerState<ReminderWalkthrough> createState() => _ReminderWalkthroughState();
}

class _ReminderWalkthroughState extends ConsumerState<ReminderWalkthrough> {
  int _index = 0;
  int _sent = 0;
  Future<String?>? _message;

  Future<String?> _compose() {
    final DuesRow row = widget.rows[_index];
    final ProviderContainer container = ProviderScope.containerOf(context, listen: false);
    return composeReminder(
      container,
      lang: context.lang,
      studentId: row.studentId,
      centerFallback: context.l10n.duesCenterFallback,
      placeId: container.read(placeFilterProvider),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_message == null && widget.rows.isNotEmpty) _message = _compose();
  }

  void _advance() {
    setState(() {
      _index++;
      _message = _index < widget.rows.length ? _compose() : null;
    });
  }

  Future<void> _send(String text) async {
    final String id = widget.rows[_index].studentId;
    final meta = ref.read(localMetaRepositoryProvider);
    final today = ref.read(todayProvider);
    await ShareService.shareText(context, text);
    await markReminded(meta, today, id);
    if (!mounted) return;
    _sent++;
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    final BhorThemeData b = context.bhor;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final bool done = _index >= widget.rows.length;

    final Widget body;
    if (done) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(BhorIcons.checkCircleFill, size: 56, color: b.colors.accent),
          const SizedBox(height: BhorSpace.s12),
          Text(
            l10n.duesWalkDone(fmt.number(_sent)),
            textAlign: TextAlign.center,
            style: b.type.heading,
          ),
          const SizedBox(height: BhorSpace.s16),
          BhorButton(
            label: l10n.commonDone,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    } else {
      final DuesRow row = widget.rows[_index];
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: b.type.heading,
                ),
              ),
              const SizedBox(width: BhorSpace.s8),
              BhorMoney(row.total, style: b.type.heading),
            ],
          ),
          const SizedBox(height: BhorSpace.s4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DuesStatusBadge(row: row),
          ),
          const SizedBox(height: BhorSpace.s12),
          Text(l10n.duesWalkMessage, style: b.type.meta),
          const SizedBox(height: BhorSpace.s4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, minHeight: 72),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: b.colors.surface2,
                borderRadius: BorderRadius.circular(BhorRadius.chip),
              ),
              child: Padding(
                padding: const EdgeInsets.all(BhorSpace.s12),
                child: FutureBuilder<String?>(
                  key: ValueKey<int>(_index),
                  future: _message,
                  builder: (BuildContext context, AsyncSnapshot<String?> snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: BhorSpinner());
                    }
                    final String text = snap.data ?? '';
                    return SingleChildScrollView(
                      child: Text(
                        text.isEmpty ? l10n.duesReminderFailed : text,
                        style: b.type.body,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: BhorSpace.s16),
          Row(
            children: <Widget>[
              Expanded(
                child: BhorButton(
                  variant: BhorButtonVariant.secondary,
                  label: l10n.duesWalkSkip,
                  onPressed: _advance,
                ),
              ),
              const SizedBox(width: BhorSpace.s12),
              Expanded(
                child: FutureBuilder<String?>(
                  key: ValueKey<String>('send-$_index'),
                  future: _message,
                  builder: (BuildContext context, AsyncSnapshot<String?> snap) {
                    final String? text = snap.data;
                    return BhorButton(
                      icon: BhorIcons.share,
                      label: l10n.duesWalkSend,
                      onPressed: (text == null || text.isEmpty) ? null : () => _send(text),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: done
                  ? const SizedBox.shrink()
                  : Text(
                      l10n.duesWalkProgress(
                        fmt.number(_index + 1),
                        fmt.number(widget.rows.length),
                      ),
                      style: b.type.label.copyWith(color: b.colors.text2),
                    ),
            ),
            BhorIconButton(
              icon: BhorIcons.close,
              semanticLabel: l10n.commonClose,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: BhorSpace.s8),
        body,
      ],
    );
  }
}
