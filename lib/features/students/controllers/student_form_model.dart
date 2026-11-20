// Editable state shared by the full-screen student form and the add sheet.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:attendance_alamin/app/l10n/error_text.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/time/local_date.dart';
import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:attendance_alamin/core/validation/validators.dart';
import 'package:attendance_alamin/domain/dues/dues_engine.dart';
import 'package:attendance_alamin/domain/models/drafts.dart';
import 'package:attendance_alamin/domain/models/student.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

class StudentFormModel extends ChangeNotifier {
  StudentFormModel({
    required this.admissionDate,
    String name = '',
    String phone = '',
    String guardianPhone = '',
    String guardianName = '',
    String roll = '',
    String notes = '',
    this.hadPhoto = false,
  })  : name = TextEditingController(text: name),
        phone = TextEditingController(text: phone),
        guardianPhone = TextEditingController(text: guardianPhone),
        guardianName = TextEditingController(text: guardianName),
        roll = TextEditingController(text: roll),
        notes = TextEditingController(text: notes);

  factory StudentFormModel.from(Student s) => StudentFormModel(
        admissionDate: s.admissionDate,
        name: s.name,
        phone: s.phone ?? '',
        guardianPhone: s.guardianPhone ?? '',
        guardianName: s.guardianName ?? '',
        roll: s.roll ?? '',
        notes: s.notes ?? '',
        hadPhoto: s.hasPhoto,
      );

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController guardianPhone;
  final TextEditingController guardianName;
  final TextEditingController roll;
  final TextEditingController notes;
  LocalDate admissionDate;

  /// A photo already stored for this student (edit).
  final bool hadPhoto;

  /// The picked photo (null with [photoChanged] = remove it).
  Uint8List? photo;
  bool photoChanged = false;

  /// Field name -> message of the last [validate].
  final Map<String, String> errors = <String, String>{};

  void setPhoto(Uint8List? bytes) {
    photo = bytes;
    photoChanged = true;
    notifyListeners();
  }

  void setAdmission(LocalDate d) {
    admissionDate = d;
    notifyListeners();
  }

  void clearError(String field) {
    if (errors.remove(field) != null) notifyListeners();
  }

  bool get hasAnyMoreInfo =>
      roll.text.trim().isNotEmpty ||
      phone.text.trim().isNotEmpty ||
      guardianName.text.trim().isNotEmpty ||
      notes.text.trim().isNotEmpty;

  /// The validated draft, or null with [errors] filled (live messages).
  StudentDraft? validate(AppLocalizations l10n) {
    errors.clear();
    String? nameV;
    String? phoneV;
    String? guardianPhoneV;
    try {
      nameV = Validators.name(name.text);
    } on ValidationException catch (e) {
      errors['name'] = errorText(l10n, e);
    }
    try {
      phoneV = Validators.phone(phone.text);
    } on ValidationException catch (e) {
      errors['phone'] = errorText(l10n, e);
    }
    try {
      guardianPhoneV = Validators.phone(guardianPhone.text);
    } on ValidationException catch (e) {
      errors['guardianPhone'] = errorText(l10n, e);
    }
    notifyListeners();
    if (errors.isNotEmpty || nameV == null) return null;
    return StudentDraft(
      name: nameV,
      admissionDate: admissionDate,
      roll: _blankToNull(roll.text),
      phone: phoneV,
      guardianName: _blankToNull(guardianName.text),
      guardianPhone: guardianPhoneV,
      notes: _blankToNull(notes.text),
    );
  }

  static String? _blankToNull(String s) {
    final String t = s.trim();
    return t.isEmpty ? null : t;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    guardianPhone.dispose();
    guardianName.dispose();
    roll.dispose();
    notes.dispose();
    super.dispose();
  }
}

/// Which batch and billing start a new enrollment gets.
class EnrollChoice extends ChangeNotifier {
  EnrollChoice({this.batchId});

  String? batchId;
  YearMonth? _startOverride;

  /// Optional monthly fee override (blank = the batch fee).
  final TextEditingController fee = TextEditingController();
  String? feeError;

  /// First billable month: the teacher's pick, else the cutoff default
  /// (Product 3.2, scenario 6).
  YearMonth startFor(LocalDate join, int cutoff) =>
      _startOverride ?? DuesEngine.defaultFirstBillableMonth(join, cutoff);

  bool get startEdited => _startOverride != null;

  void setStart(YearMonth? m) {
    _startOverride = m;
    notifyListeners();
  }

  void setBatch(String? id) {
    batchId = id;
    notifyListeners();
  }

  /// The override in taka (null when blank). `ok` is false, with [feeError]
  /// set, when the text is not a valid amount.
  ({bool ok, int? amount}) parseFee(AppLocalizations l10n) {
    feeError = null;
    if (fee.text.trim().isEmpty) {
      notifyListeners();
      return (ok: true, amount: null);
    }
    try {
      final int v = Validators.amount(fee.text);
      notifyListeners();
      return (ok: true, amount: v);
    } on ValidationException catch (e) {
      feeError = errorText(l10n, e);
      notifyListeners();
      return (ok: false, amount: null);
    }
  }

  @override
  void dispose() {
    fee.dispose();
    super.dispose();
  }
}
