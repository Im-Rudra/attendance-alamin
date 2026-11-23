// Record / edit a payment (Product 3.4, plan 1 #35, UX 2c).
//
// [buildPlan] is the whole allocation rule, pure and table-testable: the
// amount follows the oldest open month, ticked months (any, gaps allowed) each
// get what they still owe, typed money fills open months oldest first (never
// beyond 12 months ahead), and a manual split may not give a month more than
// it still owes. [CollectPaymentController] keeps what the
// teacher typed; everything else is derived.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/data/repositories/local_meta_repository.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/payment.dart';
import 'package:attendance_alamin/features/payments/controllers/pay_providers.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

/// Why a plan cannot be saved.
enum PlanProblem { none, noAmount, overflow, splitExceeds, nothingOpen }

/// What saving the current input would do.
class CollectPlan {
  const CollectPlan({
    required this.allocations,
    required this.total,
    required this.problem,
    required this.prefill,
    required this.maxPlaceable,
    required this.openMonths,
    this.partialMonths = const <YearMonth>[],
    this.partialLeft = 0,
    this.advanceMonths = const <YearMonth>[],
    this.advanceTotal = 0,
  });

  final List<Allocation> allocations;

  /// Sum of [allocations] (the typed amount while the plan is rejected).
  final int total;
  final PlanProblem problem;

  /// Remaining of the oldest open month: what the amount field opens with.
  final int prefill;

  /// Most that can be taken now: the remaining of all open months up to 12
  /// months ahead.
  final int maxPlaceable;

  /// Open months up to the horizon, oldest first (the split rows).
  final List<MonthDue> openMonths;

  /// Allocated months that stay partly paid, and how much stays owing there.
  final List<YearMonth> partialMonths;
  final int partialLeft;

  /// Allocated months whose due date has not arrived, and the money going there.
  final List<YearMonth> advanceMonths;
  final int advanceTotal;

  bool get ok => problem == PlanProblem.none && allocations.isNotEmpty && total > 0;

  List<YearMonth> get months => <YearMonth>[for (final Allocation a in allocations) a.month];

  /// Every allocated month is not yet due.
  bool get pureAdvance => allocations.isNotEmpty && advanceMonths.length == allocations.length;

  int allocatedTo(YearMonth m) {
    for (final Allocation a in allocations) {
      if (a.month == m) return a.amount;
    }
    return 0;
  }
}

/// The allocation rule. [amount] null = follow the prefill; [selected]
/// non-null = the month chips the teacher picked (each gets what it still
/// owes, any order, gaps allowed; paid or closed months are ignored); [split]
/// non-null = the teacher splits by hand. [split] wins over [selected], which
/// wins over [amount].
CollectPlan buildPlan({
  required EnrollmentDues dues,
  required LocalDate today,
  int? amount,
  Map<YearMonth, int>? split,
  Set<YearMonth>? selected,
}) {
  final YearMonth horizon = today.yearMonth.addMonths(12);
  final List<MonthDue> open = <MonthDue>[
    for (final MonthDue md in dues.months)
      if (md.isOpen && !md.month.isAfter(horizon)) md,
  ];
  final Map<YearMonth, MonthDue> byMonth = <YearMonth, MonthDue>{
    for (final MonthDue md in dues.months) md.month: md,
  };
  final int prefill = open.isEmpty ? 0 : open.first.remaining;
  final int maxPlaceable = open.fold<int>(0, (int s, MonthDue m) => s + m.remaining);

  CollectPlan rejected(PlanProblem p, int total, [List<Allocation> entered = const <Allocation>[]]) => CollectPlan(
        allocations: entered,
        total: total,
        problem: p,
        prefill: prefill,
        maxPlaceable: maxPlaceable,
        openMonths: open,
      );

  List<Allocation> allocations;
  if (split != null) {
    final List<YearMonth> keys = split.keys.toList()..sort();
    allocations = <Allocation>[
      for (final YearMonth m in keys)
        if ((split[m] ?? 0) > 0) Allocation(month: m, amount: split[m]!),
    ];
    final int sum = allocations.fold<int>(0, (int s, Allocation a) => s + a.amount);
    if (allocations.isEmpty) return rejected(PlanProblem.noAmount, 0);
    try {
      DuesEngine.validateAllocations(dues: dues, allocations: allocations);
    } on ValidationException catch (e) {
      final PlanProblem p = e.code == ErrorCodes.allocationBeyondHorizon
          ? PlanProblem.overflow
          : (e.code == ErrorCodes.amountInvalid ? PlanProblem.noAmount : PlanProblem.splitExceeds);
      return rejected(p, sum, allocations);
    }
  } else if (selected != null) {
    if (open.isEmpty) return rejected(PlanProblem.nothingOpen, 0);
    allocations = <Allocation>[
      for (final MonthDue md in open)
        if (selected.contains(md.month) && md.remaining > 0) Allocation(month: md.month, amount: md.remaining),
    ];
    if (allocations.isEmpty) return rejected(PlanProblem.noAmount, 0);
  } else {
    final int wanted = amount ?? prefill;
    if (wanted <= 0) return rejected(PlanProblem.noAmount, 0);
    if (open.isEmpty) return rejected(PlanProblem.nothingOpen, wanted);
    try {
      allocations = DuesEngine.autoAllocate(dues: dues, amount: wanted, today: today);
    } on ValidationException catch (e) {
      return rejected(
        e.code == ErrorCodes.allocationBeyondHorizon ? PlanProblem.overflow : PlanProblem.noAmount,
        wanted,
      );
    }
  }

  final List<YearMonth> partial = <YearMonth>[];
  var partialLeft = 0;
  final List<YearMonth> advance = <YearMonth>[];
  var advanceTotal = 0;
  var total = 0;
  for (final Allocation a in allocations) {
    total += a.amount;
    final MonthDue? md = byMonth[a.month];
    if (md == null) continue;
    final int left = md.remaining - a.amount;
    if (left > 0) {
      partial.add(a.month);
      partialLeft += left;
    }
    if (!md.isDue) {
      advance.add(a.month);
      advanceTotal += a.amount;
    }
  }
  return CollectPlan(
    allocations: allocations,
    total: total,
    problem: PlanProblem.none,
    prefill: prefill,
    maxPlaceable: maxPlaceable,
    openMonths: open,
    partialMonths: partial,
    partialLeft: partialLeft,
    advanceMonths: advance,
    advanceTotal: advanceTotal,
  );
}

/// A month the teacher can tick: it still owes money and lies within the
/// 12-month horizon (paid, waived, free and far-future months cannot).
bool monthSelectable(MonthDue md, LocalDate today) =>
    md.isOpen && md.remaining > 0 && !md.month.isAfter(today.yearMonth.addMonths(12));

/// The months the chips show, oldest first: up to two settled months just
/// before the first month that still owes (so the teacher sees what is
/// paid), then on, [count] in all within the 12-month horizon; plus every
/// ticked month outside that window (picked in the month grid).
List<MonthDue> chipMonths(
  EnrollmentDues dues,
  LocalDate today,
  Set<YearMonth> selected, {
  int count = 6,
}) {
  final YearMonth horizon = today.yearMonth.addMonths(12);
  final List<MonthDue> months = <MonthDue>[
    for (final MonthDue md in dues.months)
      if (!md.month.isAfter(horizon)) md,
  ];
  final int first = months.indexWhere((MonthDue md) => monthSelectable(md, today));
  final int from = first < 0
      ? (months.length - count < 0 ? 0 : months.length - count)
      : (first - 2 < 0 ? 0 : first - 2);
  final int to = from + count > months.length ? months.length : from + count;
  final List<MonthDue> window = months.sublist(from, to);
  final Set<YearMonth> shown = <YearMonth>{for (final MonthDue md in window) md.month};
  final List<MonthDue> out = <MonthDue>[
    ...window,
    for (final MonthDue md in months)
      if (selected.contains(md.month) && !shown.contains(md.month)) md,
  ];
  out.sort((MonthDue a, MonthDue b) => a.month.compareTo(b.month));
  return out;
}

/// Cash when it is shown, else the first shown method.
PaymentMethod defaultMethod(List<PaymentMethod> visible) {
  if (visible.contains(PaymentMethod.cash) || visible.isEmpty) return PaymentMethod.cash;
  return visible.first;
}

/// Which enrollment the form works on: the teacher's pick, else the one the
/// caller named, else the one that owes the oldest month.
String? resolveEnrollmentId({
  required String? picked,
  required String? requested,
  required List<EnrollmentDues> choices,
}) {
  if (picked != null) return picked;
  if (requested != null) return requested;
  return choices.isEmpty ? null : choices.first.terms.enrollmentId;
}

/// A payment that was just written.
class SavedPayment {
  const SavedPayment({required this.receiptId, required this.total, this.edited = false});

  final String receiptId;
  final int total;

  /// An existing receipt was rewritten (not a new payment).
  final bool edited;
}

/// (student, enrollment the caller asked for, receipt being edited).
typedef PayArgs = ({String studentId, String? enrollmentId, String? receiptId});

/// What the teacher has typed or picked so far. Null fields follow the
/// defaults (prefilled amount, last method, today).
class CollectInput {
  const CollectInput({
    this.enrollmentId,
    this.amountText,
    this.split,
    this.selected,
    this.method,
    this.paidOn,
    this.note = '',
    this.busy = false,
    this.errorCode,
  });

  /// Input of an edit: the receipt's own split, date, method and note.
  factory CollectInput.fromReceipt(List<Payment> rows) {
    final Payment first = rows.first;
    return CollectInput(
      enrollmentId: first.enrollmentId,
      split: <YearMonth, int>{for (final Payment p in rows) p.billingMonth: p.amount},
      method: first.method,
      paidOn: first.paidOn,
      note: first.note ?? '',
    );
  }

  final String? enrollmentId;

  /// ASCII digits as typed; null = follow the prefill.
  final String? amountText;

  /// Manual split by month; null = automatic.
  final Map<YearMonth, int>? split;

  /// The months the teacher ticked (chips or the month grid); null = follow
  /// the typed or prefilled amount. Empty = every month was unticked.
  final Set<YearMonth>? selected;
  final PaymentMethod? method;
  final LocalDate? paidOn;
  final String note;
  final bool busy;

  /// `ErrorCodes` value of the last failed save.
  final String? errorCode;

  /// The typed amount; null while untouched.
  int? get amount {
    final String? t = amountText;
    if (t == null) return null;
    return int.tryParse(AppFormat.toAsciiDigits(t)) ?? 0;
  }

  CollectInput copyWith({
    String? enrollmentId,
    String? amountText,
    bool clearAmount = false,
    Map<YearMonth, int>? split,
    bool clearSplit = false,
    Set<YearMonth>? selected,
    bool clearSelected = false,
    PaymentMethod? method,
    LocalDate? paidOn,
    String? note,
    bool? busy,
    String? errorCode,
    bool clearError = false,
  }) {
    return CollectInput(
      enrollmentId: enrollmentId ?? this.enrollmentId,
      amountText: clearAmount ? null : (amountText ?? this.amountText),
      split: clearSplit ? null : (split ?? this.split),
      selected: clearSelected ? null : (selected ?? this.selected),
      method: method ?? this.method,
      paidOn: paidOn ?? this.paidOn,
      note: note ?? this.note,
      busy: busy ?? this.busy,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

final collectPaymentControllerProvider =
    NotifierProvider.autoDispose.family<CollectPaymentController, CollectInput, PayArgs>(
        CollectPaymentController.new);

class CollectPaymentController extends Notifier<CollectInput> {
  CollectPaymentController(this.args);

  final PayArgs args;

  @override
  CollectInput build() {
    final String? receiptId = args.receiptId;
    if (receiptId != null) {
      final List<Payment> rows = ref.read(payReceiptRowsProvider(receiptId)).value ?? const <Payment>[];
      if (rows.isNotEmpty) return CollectInput.fromReceipt(rows);
      return const CollectInput();
    }
    _loadLastMethod();
    return const CollectInput();
  }

  Future<void> _loadLastMethod() async {
    final String? raw =
        await ref.read(localMetaRepositoryProvider).getRaw(LocalMetaKeys.lastMethod(args.studentId));
    if (!ref.mounted || raw == null || state.method != null) return;
    final PaymentMethod method;
    try {
      method = PaymentMethod.parse(raw);
    } on FormatException {
      return;
    }
    if (!ref.read(paymentMethodsConfigProvider).visible.contains(method)) return;
    state = state.copyWith(method: method);
  }

  /// Another batch: the amount and any split start over.
  void pickEnrollment(String id) {
    if (state.enrollmentId == id) return;
    state = CollectInput(
      enrollmentId: id,
      method: state.method,
      paidOn: state.paidOn,
      note: state.note,
    );
  }

  /// The dues the form works on now (null while they load).
  EnrollmentDues? _dues() {
    final List<EnrollmentDues> choices =
        ref.read(payChoicesProvider(args.studentId)).value ?? const <EnrollmentDues>[];
    final String? enrollmentId = resolveEnrollmentId(
      picked: state.enrollmentId,
      requested: args.enrollmentId,
      choices: choices,
    );
    if (enrollmentId == null) return null;
    return ref.read(payDuesProvider((enrollmentId: enrollmentId, receiptId: args.receiptId))).value;
  }

  /// The months ticked now: the teacher's own pick, else the months the
  /// current amount or split pays.
  Set<YearMonth> shownMonths(EnrollmentDues dues) {
    final Set<YearMonth>? picked = state.selected;
    if (picked != null) return picked;
    final CollectPlan plan = buildPlan(
      dues: dues,
      today: ref.read(todayProvider),
      amount: state.amount,
      split: state.split,
    );
    return plan.months.toSet();
  }

  /// A month chip (or a month-grid cell) was tapped: tick or untick [month].
  /// Any months, in any order, with gaps. The amount becomes the sum of what
  /// the ticked months still owe; a typed amount or a manual split is
  /// dropped. Months that cannot take money (paid, waived, beyond the
  /// horizon) are ignored.
  void toggleMonth(YearMonth month) {
    final EnrollmentDues? dues = _dues();
    if (dues == null) return;
    MonthDue? md;
    for (final MonthDue m in dues.months) {
      if (m.month == month) md = m;
    }
    if (md == null || !monthSelectable(md, ref.read(todayProvider))) return;
    final Set<YearMonth> next = <YearMonth>{...shownMonths(dues)};
    if (!next.remove(month)) next.add(month);
    state = state.copyWith(selected: next, clearAmount: true, clearSplit: true, clearError: true);
  }

  /// [ascii] holds digits only. A typed amount drops a manual split and the
  /// ticked months: it spreads from the oldest open month again.
  void setAmount(String ascii) {
    state = state.copyWith(amountText: ascii, clearSplit: true, clearSelected: true, clearError: true);
  }

  /// Gives [month] exactly [amount] in a manual split. [base] is the split the
  /// teacher sees now (the automatic allocation when none was started).
  void setSplit(YearMonth month, int amount, Map<YearMonth, int> base) {
    final Map<YearMonth, int> next = <YearMonth, int>{...(state.split ?? base)};
    if (amount <= 0) {
      next.remove(month);
    } else {
      next[month] = amount;
    }
    state = state.copyWith(split: next, clearAmount: true, clearSelected: true, clearError: true);
  }

  /// Back to automatic allocation of the typed (or prefilled) amount.
  void resetSplit({int? keepAmount}) {
    state = state.copyWith(
      clearSplit: true,
      clearSelected: true,
      clearAmount: keepAmount == null,
      amountText: keepAmount?.toString(),
      clearError: true,
    );
  }

  void setMethod(PaymentMethod m) => state = state.copyWith(method: m);
  void setDate(LocalDate d) => state = state.copyWith(paidOn: d);
  void setNote(String n) => state = state.copyWith(note: n);

  /// Records (or, when editing, rewrites) the payment. Returns what was saved,
  /// or null when the input is not valid or the repository refused it (the
  /// reason is then in [CollectInput.errorCode]).
  Future<SavedPayment?> submit() async {
    final CollectInput input = state;
    if (input.busy) return null;
    final List<EnrollmentDues> choices = ref.read(payChoicesProvider(args.studentId)).value ?? const <EnrollmentDues>[];
    final String? enrollmentId = resolveEnrollmentId(
      picked: input.enrollmentId,
      requested: args.enrollmentId,
      choices: choices,
    );
    if (enrollmentId == null) return null;
    final EnrollmentDues? dues =
        ref.read(payDuesProvider((enrollmentId: enrollmentId, receiptId: args.receiptId))).value;
    if (dues == null) return null;
    final LocalDate today = ref.read(todayProvider);
    final CollectPlan plan = buildPlan(
      dues: dues,
      today: today,
      amount: input.amount,
      split: input.split,
      selected: input.selected,
    );
    if (!plan.ok) return null;

    final List<PaymentMethod> visible = ref.read(paymentMethodsConfigProvider).visible;
    final PaymentMethod method = input.method ?? defaultMethod(visible);
    final String note = input.note.trim();
    final PaymentDraft draft = PaymentDraft(
      studentId: args.studentId,
      enrollmentId: enrollmentId,
      allocations: plan.allocations,
      paidOn: input.paidOn ?? today,
      method: method,
      note: note.isEmpty ? null : note,
    );
    state = input.copyWith(busy: true, clearError: true);
    try {
      final repo = ref.read(paymentsRepositoryProvider);
      final String? editing = args.receiptId;
      final String receiptId;
      if (editing == null) {
        receiptId = await repo.record(draft);
      } else {
        await repo.updateReceipt(editing, draft);
        receiptId = editing;
      }
      if (ref.mounted) {
        // Remembering the method must not delay the success moment.
        unawaited(ref
            .read(localMetaRepositoryProvider)
            .setRaw(LocalMetaKeys.lastMethod(args.studentId), method.code)
            .catchError((Object _) {}));
      }
      if (ref.mounted) state = state.copyWith(busy: false);
      return SavedPayment(receiptId: receiptId, total: plan.total, edited: editing != null);
    } on AppException catch (e) {
      if (ref.mounted) state = state.copyWith(busy: false, errorCode: e.code);
      return null;
    }
  }
}
