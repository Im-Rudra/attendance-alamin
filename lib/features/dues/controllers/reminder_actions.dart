// Call and Remind actions of the dues list (UX 2d): "Remind" fills the
// teacher's template, opens the share sheet and remembers the reminder for
// today (`reminded:<date>`). Safe to call from rows, tables, menus and the
// walk-through.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:attendance_alamin/app/ds/ds.dart';
import 'package:attendance_alamin/app/l10n/l10n_x.dart';
import 'package:attendance_alamin/app/providers/core_providers.dart';
import 'package:attendance_alamin/app/services/contact_actions.dart';
import 'package:attendance_alamin/app/services/share_service.dart';
import 'package:attendance_alamin/core/format/lang.dart';
import 'package:attendance_alamin/core/settings/setting_keys.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/data/repositories/people_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_providers.dart';
import 'package:attendance_alamin/data/repositories/settings_repository.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/dues/dues_models.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_model.dart';
import 'package:attendance_alamin/features/dues/controllers/dues_state.dart';
import 'package:attendance_alamin/features/dues/reminder_text.dart';
import 'package:attendance_alamin/features/settings/settings_entry.dart';

void _toast(BuildContext context, String message) {
  if (context.mounted) BhorToast.show(context, message: message);
}

/// The reminder text for [studentId] in [lang], or `null` when the student has
/// no open due month. Reads the dues straight from the repositories so it also
/// works when no screen is watching them.
Future<String?> composeReminder(
  ProviderContainer container, {
  required Lang lang,
  required String studentId,
  required String centerFallback,
}) async {
  final LocalDate today = container.read(todayProvider);
  final List<EnrollmentTerms> terms = await container.read(enrollmentsRepositoryProvider).watchTerms().first;
  final List<PaymentFact> facts = await container.read(paymentsRepositoryProvider).watchFacts().first;
  final DuesReport report = DuesEngine.report(today: today, terms: terms, payments: facts);
  final StudentDues? dues = duesOfStudent(report, studentId);
  if (dues == null || dues.openMonths.isEmpty) return null;
  final SettingsRepository settings = container.read(settingsRepositoryProvider);
  final String stored = await settings.get(templateKey(TemplateKind.reminder, lang));
  final String center = (await settings.get(SettingKeys.centerName)).trim();
  final String phone = await settings.get(SettingKeys.centerPhone);
  final List<String> batches = <String>[];
  for (final EnrollmentDues e in dues.enrollments) {
    if (e.openDue.isEmpty) continue;
    if (!batches.contains(e.terms.batchName)) batches.add(e.terms.batchName);
  }
  return buildReminderText(
    lang: lang,
    template: editorTextFor(TemplateKind.reminder, lang, stored),
    student: dues.name,
    batches: batches.join(', '),
    months: dues.openMonths,
    amount: dues.totalOutstanding,
    currentYear: today.year,
    center: center.isEmpty ? centerFallback : center,
    teacherPhone: phone,
  );
}

/// Builds the reminder, opens the share sheet and marks the student as
/// reminded today. True when a message was handed to the share sheet.
Future<bool> remindStudent(
  BuildContext context,
  ProviderContainer container,
  String studentId,
) async {
  final l10n = context.l10n;
  final Lang lang = context.lang;
  String? text;
  var failed = false;
  try {
    text = await composeReminder(
      container,
      lang: lang,
      studentId: studentId,
      centerFallback: l10n.duesCenterFallback,
    );
  } on Object {
    failed = true;
  }
  if (!context.mounted) return false;
  if (failed) {
    _toast(context, l10n.duesReminderFailed);
    return false;
  }
  if (text == null) {
    _toast(context, l10n.duesNothingToRemind);
    return false;
  }
  final String? number = container.read(duesStudentMapProvider)[studentId]?.callNumber;
  if (number == null || number.trim().isEmpty) {
    // Still hand the message over (copy / share); just say there is no number.
    _toast(context, l10n.duesRemindNoPhone);
  }
  await ShareService.shareText(context, text);
  await markReminded(
    container.read(localMetaRepositoryProvider),
    container.read(todayProvider),
    studentId,
  );
  return true;
}

/// Dials the student's guardian (else the student) on Android, copies the
/// number elsewhere; says so when there is no number.
Future<void> callStudent(BuildContext context, Student? student) async {
  final String? number = student?.callNumber;
  if (number == null || number.trim().isEmpty) {
    _toast(context, context.l10n.duesNoPhone);
    return;
  }
  await ContactActions.callOrCopy(context, number);
}
