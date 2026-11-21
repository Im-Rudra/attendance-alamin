// Student profile (UX 3, 3b): header with call / remind, one card per
// enrollment (month strip, attendance summary, [টাকা নিন]), payment history.
// Wide windows lay the profile out in two columns.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/attendance_providers.dart';
import 'package:attendance_alamin/app/providers/dues_providers.dart';
import 'package:attendance_alamin/app/routes.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/shell/pane_split.dart';
import 'package:attendance_alamin/app/shell/window_class.dart';
import 'package:attendance_alamin/app/theme/theme_x.dart';
import 'package:attendance_alamin/app/widgets/widgets.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/enrollment.dart';
import 'package:attendance_alamin/domain/models/enums.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/dues_entry.dart';
import 'package:attendance_alamin/features/payments/payments_entry.dart';
import 'package:attendance_alamin/features/students/controllers/student_nav.dart';
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

    void edit() => stuPush(context, Routes.studentEdit(studentId));
    void collect() => showCollectPaymentSheet(context, studentId: studentId);

    return StudentKeys(
      onEdit: student == null ? null : edit,
      onCollect: student == null ? null : collect,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !embedded,
          title: Semantics(
              header: true, child: Text(l10n.shellTitleStudentProfile)),
          actions: <Widget>[
            if (student != null) ...<Widget>[
              IconButton(
                tooltip: l10n.commonEdit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: edit,
              ),
              PopupMenuButton<_ProfileMenu>(
                tooltip: l10n.commonMore,
                onSelected: (_ProfileMenu m) =>
                    _onMenu(context, ref, student, m),
                itemBuilder: (BuildContext ctx) =>
                    <PopupMenuEntry<_ProfileMenu>>[
                  if (student.status == StudentStatus.active) ...<PopupMenuEntry<_ProfileMenu>>[
                    PopupMenuItem<_ProfileMenu>(
                      value: _ProfileMenu.enroll,
                      child: Text(l10n.stuEnrollOther),
                    ),
                    PopupMenuItem<_ProfileMenu>(
                      value: _ProfileMenu.left,
                      child: Text(l10n.stuMenuLeft),
                    ),
                  ] else
                    PopupMenuItem<_ProfileMenu>(
                      value: _ProfileMenu.rejoin,
                      child: Text(l10n.stuRejoin),
                    ),
                  PopupMenuItem<_ProfileMenu>(
                    value: _ProfileMenu.delete,
                    child: Text(l10n.commonDelete),
                  ),
                ],
              ),
            ],
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: (student != null && !wide)
            ? StickyActionBar(label: l10n.stuCollect, onPressed: collect)
            : null,
        body: SafeArea(
          top: false,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace st) => EmptyState(
              icon: Icons.error_outline,
              message: l10n.commonLoadingFailed,
            ),
            data: (Student? s) => s == null
                ? EmptyState(
                    icon: Icons.person_off_outlined,
                    message: l10n.stuNotFound,
                  )
                : _ProfileBody(student: s),
          ),
        ),
      ),
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
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    final repo = ref.read(studentsRepositoryProvider);
    final impact = await repo.deleteImpact(s.id);
    if (!context.mounted) return;
    final bool ok = await showConfirmDialog(
      context,
      title: l10n.stuDeleteTitle(s.name),
      body: l10n.stuDeleteBody(
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
      messenger?.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
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
        GlassCard(
          dense: true,
          child: Text(l10n.stuNoEnrollments),
        ),
      if (student.status == StudentStatus.active)
        OutlinedButton.icon(
          key: const ValueKey<String>('stu-enroll-other'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.add),
          label: Text(l10n.stuEnrollOther),
          onPressed: () => showEnrollSheet(context, studentId: student.id),
        ),
    ];
    final List<Widget> right = <Widget>[
      SectionHeader(title: l10n.stuPaymentHistory),
      GlassCard(
        dense: true,
        child: PaymentHistoryList(studentId: student.id),
      ),
      if ((student.notes ?? '').isNotEmpty) ...<Widget>[
        SectionHeader(title: l10n.commonNotes),
        GlassCard(dense: true, child: Text(student.notes!)),
      ],
    ];

    Widget column(List<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 12),
              items[i],
            ],
          ],
        );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final bool twoColumns = c.maxWidth >= 880;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(gutter, 4, gutter, gutter),
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
    final tokens = context.aurora;
    final fmt = context.fmt;
    final TextTheme tt = Theme.of(context).textTheme;
    final String? roll = student.roll;
    final String? guardian = student.guardianPhone;
    final String? own = student.phone;

    Widget callButton(String role, String number) => OutlinedButton.icon(
          icon: Icon(ContactActions.icon),
          label: Text(l10n.stuContactButton(role, ContactActions.label(l10n))),
          onPressed: () => ContactActions.callOrCopy(context, number),
        );

    return GlassCard(
      blur: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              StudentAvatar(student: student, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(student.name,
                          style: tt.titleLarge
                              ?.copyWith(color: tokens.textPrimary)),
                    ),
                    if (roll != null && roll.isNotEmpty)
                      Text(l10n.stuRollLine(fmt.digits(roll)),
                          style: tt.labelMedium
                              ?.copyWith(color: tokens.textSecondary)),
                    if (student.guardianName != null)
                      Text(
                          l10n.stuGuardianLine(student.guardianName!),
                          style: tt.labelMedium
                              ?.copyWith(color: tokens.textSecondary)),
                    Text(
                      l10n.stuAdmittedOn(fmt.date(student.admissionDate)),
                      style:
                          tt.labelMedium?.copyWith(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (guardian != null) callButton(l10n.stuRoleGuardian, guardian),
              if (own != null) callButton(l10n.stuRoleStudent, own),
              if (guardian == null && own == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_call),
                  label: Text(l10n.stuAddPhone),
                  onPressed: () =>
                      stuPush(context, Routes.studentEdit(student.id)),
                ),
              if (dues != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: Text(l10n.stuRemind),
                  onPressed: () =>
                      shareDuesReminder(context, studentId: student.id),
                ),
              if (showCollect)
                FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(l10n.stuCollect),
                  onPressed: () =>
                      showCollectPaymentSheet(context, studentId: student.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeftCard extends ConsumerWidget {
  const _LeftCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tokens = context.aurora;
    final leftDate = student.leftDate;
    return GlassCard(
      dense: true,
      child: Row(
        children: <Widget>[
          Icon(Icons.person_off_outlined, color: tokens.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              leftDate == null
                  ? l10n.stuStatusLeft
                  : l10n.stuLeftOn(context.fmt.date(leftDate)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            key: const ValueKey<String>('stu-rejoin'),
            onPressed: () => runRejoinFlow(context, ref, student),
            child: Text(l10n.stuRejoin),
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
    final tokens = context.aurora;
    final TextTheme tt = Theme.of(context).textTheme;
    return GlassCard(
      dense: true,
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(l10n.stuTotalOutstanding,
              style: tt.labelLarge?.copyWith(color: tokens.textSecondary)),
          MoneyText(context.fmt.money(dues.totalOutstanding),
              style: tt.titleLarge?.copyWith(color: tokens.textPrimary)),
          StudentDuesBadge(dues: dues, compact: false),
        ],
      ),
    );
  }
}
