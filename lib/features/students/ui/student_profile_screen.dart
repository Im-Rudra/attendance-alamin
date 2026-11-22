// Student profile (UX 3, 3b): header with call / remind, one card per
// enrollment (month strip, attendance summary, [টাকা নিন]), payment history.
// Wide windows lay the profile out in two columns.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/format/app_format.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/dues_entry.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
import 'package:attendance_alamin/features/students/ui/student_form_screen.dart';
import 'package:attendance_alamin/features/students/controllers/student_providers.dart';
import 'package:attendance_alamin/features/students/students_entry.dart';
import 'package:attendance_alamin/features/students/widgets/enrollment_card.dart';
import 'package:attendance_alamin/features/students/widgets/rejoin_flow.dart';
import 'package:attendance_alamin/features/students/widgets/student_avatar.dart';
import 'package:attendance_alamin/features/students/widgets/student_keys.dart';
import 'package:attendance_alamin/features/students/widgets/student_row_tile.dart';

enum _ProfileMenu { enroll, left, rejoin, delete }

class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bool embedded = PaneScope.isEmbedded(context);
    final bool wide = WindowClass.of(context).isWide;
    final AsyncValue<Student?> async = ref.watch(stuStudentProvider(studentId));
    final Student? student = async.value;

    void edit() => showStudentFormPanel(context, studentId: studentId);
    void collect() => showCollectPaymentSheet(context, studentId: studentId);

    return StudentKeys(
      onEdit: student == null ? null : edit,
      onCollect: student == null ? null : collect,
      child: BhorScaffold(
        header: BhorHeader(
          title: l10n.shellTitleStudentProfile,
          showBack: embedded ? false : null,
          // A wide window too narrow for list + profile shows the profile
          // alone: back goes to the list.
          onBack: (!embedded && wide) ? () => stuGo(context, Routes.students) : null,
          actions: <Widget>[
            if (student != null) ...<Widget>[
              BhorIconButton(
                semanticLabel: l10n.commonEdit,
                icon: BhorIcons.edit,
                onPressed: edit,
              ),
              Builder(
                builder: (BuildContext btn) => BhorIconButton(
                  semanticLabel: l10n.commonMore,
                  icon: BhorIcons.overflowVertical,
                  onPressed: () => _openMenu(btn, context, ref, student),
                ),
              ),
            ],
          ],
        ),
        bottomNav: (student != null && !wide)
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: context.bhor.colors.surface,
                  border: Border(top: BorderSide(color: context.bhor.colors.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(BhorSpace.s12),
                    child: BhorButton(label: l10n.stuCollect, expand: true, onPressed: collect),
                  ),
                ),
              )
            : null,
        body: async.when(
          loading: () => const Center(child: BhorSpinner()),
          error: (Object e, StackTrace st) => BhorEmptyState(
            icon: BhorIcons.warning,
            title: l10n.commonLoadingFailed,
          ),
          data: (Student? s) => s == null
              ? BhorEmptyState(icon: BhorIcons.leftStudents, title: l10n.stuNotFound)
              : _ProfileBody(student: s),
        ),
      ),
    );
  }

  void _openMenu(BuildContext anchor, BuildContext context, WidgetRef ref, Student student) {
    final l10n = context.l10n;
    final bool active = student.status == StudentStatus.active;
    showBhorMenu(
      context,
      anchor: anchor,
      items: <BhorMenuItem>[
        if (active) ...<BhorMenuItem>[
          BhorMenuItem(
            icon: BhorIcons.add,
            label: l10n.stuEnrollOther,
            onTap: () => _onMenu(context, ref, student, _ProfileMenu.enroll),
          ),
          BhorMenuItem(
            icon: BhorIcons.leftStudents,
            label: l10n.stuMenuLeft,
            onTap: () => _onMenu(context, ref, student, _ProfileMenu.left),
          ),
        ] else
          BhorMenuItem(
            icon: BhorIcons.undo,
            label: l10n.stuRejoin,
            onTap: () => _onMenu(context, ref, student, _ProfileMenu.rejoin),
          ),
        BhorMenuItem(
          icon: BhorIcons.delete,
          label: l10n.commonDelete,
          destructive: true,
          onTap: () => _onMenu(context, ref, student, _ProfileMenu.delete),
        ),
      ],
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, Student s,
      _ProfileMenu m) async {
    switch (m) {
      case _ProfileMenu.enroll:
        await showEnrollSheet(context, studentId: s.id);
      case _ProfileMenu.left:
        await showMarkLeftDialog(context, studentId: s.id);
      case _ProfileMenu.rejoin:
        await runRejoinFlow(context, ref, s);
      case _ProfileMenu.delete:
        await _delete(context, ref, s);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Student s) async {
    final l10n = context.l10n;
    final fmt = context.fmt;
    final repo = ref.read(studentsRepositoryProvider);
    final impact = await repo.deleteImpact(s.id);
    if (!context.mounted) return;
    final bool ok = await showBhorConfirm(
      context,
      title: l10n.stuDeleteTitle(s.name),
      message: l10n.stuDeleteBody(
          fmt.number(impact.sessions), fmt.number(impact.payments)),
      confirmLabel: l10n.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await repo.softDelete(s.id);
      if (!context.mounted) return;
      stuGo(context, Routes.students);
    } on AppException catch (e) {
      if (context.mounted) BhorToast.show(context, message: errorText(l10n, e));
    }
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bool wide = WindowClass.of(context).isWide;
    final double gutter = WindowClass.of(context).gutter;
    final List<Enrollment> enrollments = <Enrollment>[
      ...?ref.watch(studentEnrollmentsProvider(student.id)).value,
    ]..sort((Enrollment a, Enrollment b) {
        final int open = (a.endDate == null ? 0 : 1) - (b.endDate == null ? 0 : 1);
        return open != 0 ? open : a.startMonth.compareTo(b.startMonth);
      });
    final StudentDues? dues = ref.watch(studentDuesProvider(student.id)).value;

    final List<Widget> left = <Widget>[
      _HeaderCard(student: student, dues: dues, showCollect: wide),
      if (student.status == StudentStatus.left) _LeftCard(student: student),
      if (dues != null) _DuesTotalCard(dues: dues),
      for (final Enrollment e in enrollments)
        EnrollmentCard(
          key: ValueKey<String>('enr-${e.id}'),
          student: student,
          enrollment: e,
          showCollect: enrollments.length > 1,
        ),
      if (enrollments.isEmpty)
        BhorCard(child: Text(l10n.stuNoEnrollments)),
      if (student.status == StudentStatus.active)
        BhorButton(
          key: const ValueKey<String>('stu-enroll-other'),
          variant: BhorButtonVariant.secondary,
          expand: true,
          icon: BhorIcons.add,
          label: l10n.stuEnrollOther,
          onPressed: () => showEnrollSheet(context, studentId: student.id),
        ),
    ];
    final List<Widget> right = <Widget>[
      BhorSectionHeader(title: l10n.stuPaymentHistory),
      BhorCard(child: PaymentHistoryList(studentId: student.id)),
      if ((student.notes ?? '').isNotEmpty) ...<Widget>[
        BhorSectionHeader(title: l10n.commonNotes),
        BhorCard(child: Text(student.notes!)),
      ],
    ];

    Widget column(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: BhorSpace.s12),
              items[i],
            ],
          ],
        );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool twoColumns = c.maxWidth >= 880;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(gutter, BhorSpace.s4, gutter, gutter),
          child: twoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: column(left)),
                    SizedBox(width: gutter),
                    Expanded(child: column(right)),
                  ],
                )
              : column(<Widget>[...left, ...right]),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.student,
    required this.dues,
    required this.showCollect,
  });

  final Student student;
  final StudentDues? dues;
  final bool showCollect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
    final fmt = context.fmt;
    final String? roll = student.roll;
    final String? guardian = student.guardianPhone;
    final String? own = student.phone;

    // The number itself, with copy (and call where there is a dialer) beside it.
    Widget phoneRow(String role, String number) => Row(
          key: ValueKey<String>('stu-phone-$role'),
          children: <Widget>[
            Icon(BhorIcons.phone, size: BhorIconSize.chip, color: th.colors.text2),
            const SizedBox(width: BhorSpace.s8),
            Expanded(
              child: Semantics(
                container: true,
                label: '$role ${fmt.digits(number)}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(role, style: th.type.meta.copyWith(color: th.colors.text2)),
                    Text(fmt.digits(number), style: BhorType.tabular(th.type.bodyStrong)),
                  ],
                ),
              ),
            ),
            BhorIconButton(
              icon: BhorIcons.copy,
              semanticLabel: '$role · ${l10n.commonCopyNumber}',
              onPressed: () => _copyNumber(context, number),
            ),
            if (ContactActions.canCall)
              BhorIconButton(
                icon: ContactActions.icon,
                semanticLabel: '$role · ${l10n.commonCall}',
                onPressed: () => ContactActions.callOrCopy(context, number),
              ),
          ],
        );

    return BhorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              StudentAvatar(student: student, size: 64),
              const SizedBox(width: BhorSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(student.name, style: th.type.title),
                    ),
                    if (roll != null && roll.isNotEmpty)
                      Text(
                        l10n.stuRollLine(fmt.digits(roll)),
                        style: th.type.label.copyWith(color: th.colors.text2),
                      ),
                    if (student.guardianName != null)
                      Text(
                        l10n.stuGuardianLine(student.guardianName!),
                        style: th.type.label.copyWith(color: th.colors.text2),
                      ),
                    Text(
                      l10n.stuAdmittedOn(fmt.date(student.admissionDate)),
                      style: th.type.label.copyWith(color: th.colors.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BhorSpace.s12),
          if (guardian != null) phoneRow(l10n.stuRoleGuardian, guardian),
          if (own != null) phoneRow(l10n.stuRoleStudent, own),
          if (guardian != null || own != null) const SizedBox(height: BhorSpace.s8),
          // Each action is one line (icon + label) at its natural width; the
          // row wraps rather than squeezing a label onto two lines.
          Wrap(
            spacing: BhorSpace.s8,
            runSpacing: BhorSpace.s8,
            children: <Widget>[
              if (guardian == null && own == null)
                BhorButton(
                  variant: BhorButtonVariant.secondary,
                  icon: BhorIcons.phone,
                  label: l10n.stuAddPhone,
                  onPressed: () => showStudentFormPanel(context, studentId: student.id),
                ),
              if (dues != null)
                BhorButton(
                  variant: BhorButtonVariant.secondary,
                  icon: BhorIcons.share,
                  label: l10n.stuRemind,
                  onPressed: () => shareDuesReminder(context, studentId: student.id),
                ),
              if (showCollect)
                BhorButton(
                  icon: BhorIcons.takeMoney,
                  label: l10n.stuCollect,
                  onPressed: () => showCollectPaymentSheet(context, studentId: student.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _copyNumber(BuildContext context, String phone) async {
  final String number = AppFormat.toAsciiDigits(phone).replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) return;
  final BuildContext anchor = BhorToast.anchorOf(context);
  final double lift = BhorToastInset.of(context);
  final String copied = context.l10n.shellNumberCopied(context.fmt.digits(number));
  await Clipboard.setData(ClipboardData(text: number));
  if (anchor.mounted) BhorToast.show(anchor, message: copied, bottomOffset: lift);
}

class _LeftCard extends ConsumerWidget {
  const _LeftCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
    final leftDate = student.leftDate;
    return BhorCard(
      child: Row(
        children: <Widget>[
          Icon(BhorIcons.leftStudents, color: th.colors.text2),
          const SizedBox(width: BhorSpace.s12),
          Expanded(
            child: Text(
              leftDate == null ? l10n.stuStatusLeft : l10n.stuLeftOn(context.fmt.date(leftDate)),
              style: th.type.bodyStrong,
            ),
          ),
          const SizedBox(width: BhorSpace.s8),
          BhorButton(
            key: const ValueKey<String>('stu-rejoin'),
            variant: BhorButtonVariant.secondary,
            label: l10n.stuRejoin,
            onPressed: () => runRejoinFlow(context, ref, student),
          ),
        ],
      ),
    );
  }
}

class _DuesTotalCard extends StatelessWidget {
  const _DuesTotalCard({required this.dues});

  final StudentDues dues;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final BhorThemeData th = context.bhor;
    return BhorCard(
      child: Wrap(
        spacing: BhorSpace.s12,
        runSpacing: BhorSpace.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(l10n.stuTotalOutstanding, style: th.type.label.copyWith(color: th.colors.text2)),
          BhorMoney(dues.totalOutstanding, style: th.type.title),
          StudentDuesBadge(dues: dues, compact: false),
        ],
      ),
    );
  }
}
