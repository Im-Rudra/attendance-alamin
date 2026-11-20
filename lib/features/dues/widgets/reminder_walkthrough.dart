// "সবাইকে মনে করিয়ে দিন" (UX 2d): walks through the listed students one share
// at a time. No SMS gateway: every message goes through the share sheet, the
// teacher picks WhatsApp / SMS / Messenger and comes back for the next one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/controllers/reminder_actions.dart';
import 'package:attendance_alamin/features/dues/widgets/dues_row.dart';

/// Opens the walk-through for [rows] (the students still to remind today).
Future<void> showReminderWalkthrough(BuildContext context, List<DuesRow> rows) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ReminderWalkthrough(rows: rows),
      ),
    ),
  );
}

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
    return composeReminder(
      ProviderScope.containerOf(context, listen: false),
      lang: context.lang,
      studentId: row.studentId,
      centerFallback: context.l10n.duesCenterFallback,
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
    final tokens = context.aurora;
    final l10n = context.l10n;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final bool done = _index >= widget.rows.length;

    final Widget body;
    if (done) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle, size: 56, color: tokens.accent),
          const SizedBox(height: 12),
          Text(
            l10n.duesWalkDone(fmt.number(_sent)),
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonDone),
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
                  style: tt.titleMedium?.copyWith(color: tokens.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmt.money(row.total),
                style: tt.titleMedium?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DuesStatusBadge(row: row),
          ),
          const SizedBox(height: 12),
          Text(l10n.duesWalkMessage, style: tt.labelMedium?.copyWith(color: tokens.textSecondary)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, minHeight: 72),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.track,
                borderRadius: BorderRadius.circular(AuroraMetrics.radiusChip),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FutureBuilder<String?>(
                  key: ValueKey<int>(_index),
                  future: _message,
                  builder: (BuildContext context, AsyncSnapshot<String?> snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final String text = snap.data ?? '';
                    return SingleChildScrollView(
                      child: Text(
                        text.isEmpty ? l10n.duesReminderFailed : text,
                        style: tt.bodyMedium?.copyWith(color: tokens.textPrimary),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _advance,
                  child: Text(l10n.duesWalkSkip),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<String?>(
                  key: ValueKey<String>('send-$_index'),
                  future: _message,
                  builder: (BuildContext context, AsyncSnapshot<String?> snap) {
                    final String? text = snap.data;
                    return FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                      onPressed: (text == null || text.isEmpty) ? null : () => _send(text),
                      icon: const Icon(Icons.share, size: 18),
                      label: Text(l10n.duesWalkSend),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.duesWalkTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleLarge?.copyWith(color: tokens.textPrimary),
                    ),
                  ),
                ),
                if (!done)
                  Text(
                    l10n.duesWalkProgress(
                      fmt.number(_index + 1),
                      fmt.number(widget.rows.length),
                    ),
                    style: tt.labelLarge?.copyWith(color: tokens.textSecondary),
                  ),
                IconButton(
                  tooltip: l10n.commonClose,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}
