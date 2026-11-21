// Weekly slot editor used by the batch form and onboarding (plan signature
// frozen). It owns a [SlotEditorController]: every edit reports the drafts via
// `onChanged`, and the live clash check (against every other active batch and
// future one-offs, from today) reports via `onCheck` once it finishes.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/data/repositories/structure_providers.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/schedule/schedule_models.dart';
import 'package:attendance_alamin/features/schedule/controllers/slot_editor_controller.dart';
import 'package:attendance_alamin/features/schedule/widgets/slot_editor_body.dart';

class SlotEditorField extends ConsumerStatefulWidget {
  const SlotEditorField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.batchId,
    this.onCheck,
  });

  /// The slots to start from (read once, when the field first appears).
  final List<SlotDraft> initial;
  final ValueChanged<List<SlotDraft>> onChanged;

  /// The batch being edited, `null` for one that is not saved yet.
  final String? batchId;
  final ValueChanged<SlotCheckResult>? onCheck;

  @override
  ConsumerState<SlotEditorField> createState() => _SlotEditorFieldState();
}

class _SlotEditorFieldState extends ConsumerState<SlotEditorField> {
  late final SlotEditorController _controller;
  List<SlotDraft> _emitted = const <SlotDraft>[];
  SlotCheckResult? _reported;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(scheduleRepositoryProvider);
    final today = ref.read(todayProvider);
    _emitted = List<SlotDraft>.of(widget.initial);
    _controller = SlotEditorController(
      initial: widget.initial,
      checker: (List<SlotDraft> slots) =>
          repo.checkSlots(widget.batchId, slots, from: today),
    )..addListener(_onControllerChanged);
    _controller.start();
  }

  void _onControllerChanged() {
    final List<SlotDraft> now = _controller.slots;
    if (!_sameDrafts(now, _emitted)) {
      _emitted = now;
      _reported = null;
      widget.onChanged(now);
    }
    final SlotCheckResult? r = _controller.check;
    if (r != null && !_controller.checking && !identical(r, _reported)) {
      _reported = r;
      widget.onCheck?.call(r);
    }
  }

  static bool _sameDrafts(List<SlotDraft> a, List<SlotDraft> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SlotEditorBody(controller: _controller, ownBatchId: widget.batchId);
}
