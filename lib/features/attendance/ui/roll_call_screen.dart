// RollCallScreen (route /rollcall/:occ, root navigator): the roll call of one
// class occurrence (notification and Today deep link target). It finds the
// batch and date of the occurrence, then hands over to [RollCallPage], which
// also serves the batch launcher (batch + date, no occurrence yet).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/async_combine.dart';
import 'package:attendance_alamin/app/providers/schedule_providers.dart';
import 'package:attendance_alamin/app/shell/stub_screen.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/attendance_repository.dart';
import 'package:attendance_alamin/features/attendance/controllers/roll_models.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_editor.dart';
import 'package:attendance_alamin/features/attendance/widgets/roll_skeleton.dart';
import 'package:attendance_alamin/features/attendance/widgets/session_chooser_sheet.dart';

class RollCallScreen extends ConsumerWidget {
  const RollCallScreen({super.key, required this.occ, this.returnTo});

  /// Route "Done" returns to (the opener passes it as the router `extra`).
  final String? returnTo;

  /// Occurrence id (`s.<slot>.<yyyymmdd>` or `x.<id>`).
  final String occ;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final AsyncValue<RollLocation?> where = ref.watch(rollLocationProvider(occ));
    final RollLocation? loc = where.value;
    if (loc != null) {
      return RollCallPage(
        key: ValueKey<String>(occ),
        batchId: loc.batchId,
        date: loc.date,
        occ: occ,
        returnTo: returnTo,
      );
    }
    if (where.hasError) {
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: BhorIcons.rollCall,
        fullScreen: true,
        message: errorText(l10n, where.error!),
      );
    }
    if (where.isLoading) {
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: BhorIcons.rollCall,
        fullScreen: true,
        body: const RollSkeleton(),
      );
    }
    return StubScreen(
      name: l10n.shellTitleRollCall,
      icon: BhorIcons.rollCall,
      fullScreen: true,
      message: l10n.rollNotFound,
    );
  }
}

/// One batch's roll call on a date: decides which class (a single one opens
/// directly, 2+ ask first, none becomes an ad-hoc extra class) and keeps that
/// choice while the schedule changes underneath.
class RollCallPage extends ConsumerStatefulWidget {
  const RollCallPage({super.key, required this.batchId, required this.date, this.occ, this.returnTo});

  final String? returnTo;

  final String batchId;
  final LocalDate date;

  /// A known class; null lets the page choose from the day's classes.
  final String? occ;

  @override
  ConsumerState<RollCallPage> createState() => _RollCallPageState();
}

class _RollCallPageState extends ConsumerState<RollCallPage> {
  late LocalDate _date = widget.date;
  String? _occ;
  bool _resolved = false;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    if (widget.occ != null) {
      _occ = widget.occ;
      _resolved = true;
    }
  }

  void _goTo(LocalDate date) {
    setState(() {
      _date = date;
      _occ = null;
      _resolved = false;
      _deciding = false;
    });
  }

  void _decide(List<SessionChoice> choices) {
    if (_deciding) return;
    _deciding = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (choices.length <= 1) {
        setState(() {
          _occ = choices.isEmpty ? null : choices.first.occ;
          _resolved = true;
          _deciding = false;
        });
        return;
      }
      final String? picked = await showSessionChooserSheet(context, date: _date, choices: choices);
      if (!mounted) return;
      setState(() {
        _occ = picked ?? defaultChoice(choices)?.occ;
        _resolved = true;
        _deciding = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<List<SessionChoice>> async = combine2<DayPlan, List<SessionSummary>, List<SessionChoice>>(
      ref.watch(dayPlanProvider(_date)),
      ref.watch(sessionSummariesProvider((from: _date, to: _date))),
      (DayPlan plan, List<SessionSummary> summaries) =>
          choicesFor(batchId: widget.batchId, plan: plan, summaries: summaries),
    );
    final List<SessionChoice>? choices = async.value;
    // A known class needs no chooser: open its roster at once and let the
    // class chips (2+ classes that day) fill in when the day plan is ready.
    if (_resolved && _occ != null) {
      return RollEditor(
        key: ValueKey<String>('${_date.toIso()}|$_occ'),
        batchId: widget.batchId,
        date: _date,
        occ: _occ,
        choices: choices ?? const <SessionChoice>[],
        onDate: _goTo,
        onPick: (String occ) => setState(() => _occ = occ),
        returnTo: widget.returnTo,
      );
    }
    if (choices == null) {
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: BhorIcons.rollCall,
        fullScreen: true,
        message: async.hasError ? errorText(l10n, async.error!) : null,
        body: async.hasError ? null : const RollSkeleton(),
      );
    }
    if (!_resolved) {
      _decide(choices);
      // Behind the chooser sheet nothing spins.
      return StubScreen(
        name: l10n.shellTitleRollCall,
        icon: BhorIcons.rollCall,
        fullScreen: true,
        body: choices.length > 1 ? const SizedBox.shrink() : const RollSkeleton(),
      );
    }
    return RollEditor(
      key: ValueKey<String>('${_date.toIso()}|${_occ ?? 'adhoc'}'),
      batchId: widget.batchId,
      date: _date,
      occ: _occ,
      choices: choices,
      onDate: _goTo,
      onPick: (String occ) => setState(() => _occ = occ),
      returnTo: widget.returnTo,
    );
  }
}
