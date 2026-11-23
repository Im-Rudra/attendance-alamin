import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';

/// When a batch's monthly fee falls due. DB codes: `prepaid`, `postpaid`.
enum BillingType {
  prepaid,
  postpaid;

  static BillingType parse(String s) {
    switch (s) {
      case 'prepaid':
        return BillingType.prepaid;
      case 'postpaid':
        return BillingType.postpaid;
    }
    throw FormatException('Unknown BillingType', s);
  }
}

/// What a `batches` row is (schema v2). DB codes: `batch`, `tuition`
/// (a private tuition: usually 1-2 students, same weekly slots, the subject
/// may be absent). Unknown codes read as [batch].
enum BatchKind {
  batch,
  tuition;

  String get code => name;

  static BatchKind parse(String? s) =>
      s == 'tuition' ? BatchKind.tuition : BatchKind.batch;
}

/// DB codes: `active`, `left`.
enum StudentStatus {
  active,
  left;

  static StudentStatus parse(String s) {
    switch (s) {
      case 'active':
        return StudentStatus.active;
      case 'left':
        return StudentStatus.left;
    }
    throw FormatException('Unknown StudentStatus', s);
  }
}

/// DB codes: `cancel`, `reschedule`, `extra`.
enum ExceptionKind {
  cancel,
  reschedule,
  extra;

  static ExceptionKind parse(String s) {
    switch (s) {
      case 'cancel':
        return ExceptionKind.cancel;
      case 'reschedule':
        return ExceptionKind.reschedule;
      case 'extra':
        return ExceptionKind.extra;
    }
    throw FormatException('Unknown ExceptionKind', s);
  }
}

/// Declaration ORDER is binding: the theme maps `AttendanceKind.values[status.index]`
/// (present, absent, late, leave). DB codes P, A, L, E (E = leave / ছুটি).
enum AttendanceStatus {
  present('P'),
  absent('A'),
  late('L'),
  leave('E');

  const AttendanceStatus(this.code);

  final String code;

  static AttendanceStatus parse(String c) {
    for (final s in AttendanceStatus.values) {
      if (s.code == c) return s;
    }
    throw FormatException('Unknown AttendanceStatus code', c);
  }

  /// Counts toward attendance: present or late. Absent and leave do not.
  bool get attended =>
      this == AttendanceStatus.present || this == AttendanceStatus.late;
}

enum OccurrenceKind { regular, rescheduled, extra }

/// A payment method: a built-in code or `custom:<label>` (label 1..20 chars).
class PaymentMethod {
  const PaymentMethod(this.code);

  /// Builds `custom:<label>`; the label is trimmed.
  factory PaymentMethod.custom(String label) {
    final l = label.trim();
    if (l.isEmpty) {
      throw const ValidationException(ErrorCodes.nameRequired, field: 'method');
    }
    if (l.length > maxCustomLabelLength) {
      throw const ValidationException(ErrorCodes.nameTooLong, field: 'method');
    }
    return PaymentMethod('$_customPrefix$l');
  }

  /// Parses a stored code. Throws [FormatException] when it is neither a
  /// built-in nor a valid `custom:<label>`.
  factory PaymentMethod.parse(String code) {
    for (final b in builtIns) {
      if (b.code == code) return b;
    }
    if (code.startsWith(_customPrefix)) {
      final label = code.substring(_customPrefix.length);
      if (label.isNotEmpty && label.length <= maxCustomLabelLength) {
        return PaymentMethod(code);
      }
    }
    throw FormatException('Unknown payment method', code);
  }

  static const String _customPrefix = 'custom:';
  static const int maxCustomLabelLength = 20;

  final String code;

  static const cash = PaymentMethod('cash');
  static const bkash = PaymentMethod('bkash');
  static const nagad = PaymentMethod('nagad');
  static const rocket = PaymentMethod('rocket');
  static const bank = PaymentMethod('bank');
  static const other = PaymentMethod('other');
  static const builtIns = [cash, bkash, nagad, rocket, bank, other];

  bool get isCustom => code.startsWith(_customPrefix);

  String? get customLabel =>
      isCustom ? code.substring(_customPrefix.length) : null;

  @override
  bool operator ==(Object other) =>
      other is PaymentMethod && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'PaymentMethod($code)';
}
