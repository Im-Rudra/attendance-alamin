import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/core/format/app_format.dart';

/// Input validators shared by repositories (authoritative) and forms (live
/// feedback). All accept Bangla or ASCII digits and return ASCII results.
abstract final class Validators {
  static const int nameMaxLength = 80;
  static const int amountMax = 1000000;

  static final RegExp _phoneRe = RegExp(r'^01[3-9]\d{8}$');
  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// Trimmed name, 1..80 characters (code points).
  /// Throws [ValidationException] (`nameRequired` / `nameTooLong`, field `name`).
  static String name(String raw) {
    final v = raw.trim();
    if (v.isEmpty) {
      throw const ValidationException(ErrorCodes.nameRequired, field: 'name');
    }
    if (v.runes.length > nameMaxLength) {
      throw const ValidationException(ErrorCodes.nameTooLong, field: 'name');
    }
    return v;
  }

  /// Normalised Bangladeshi mobile number `01XXXXXXXXX`, or null when [raw] is
  /// null / blank. Strips spaces, dashes and a `+88` / `88` country prefix.
  /// Throws [ValidationException] (`phoneInvalid`, field `phone`) otherwise.
  static String? phone(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    var s = AppFormat.toAsciiDigits(trimmed).replaceAll(RegExp(r'[\s\-]'), '');
    if (s.startsWith('+88')) {
      s = s.substring(3);
    } else if (s.startsWith('88') && s.length == 13) {
      s = s.substring(2);
    }
    if (!_phoneRe.hasMatch(s)) {
      throw const ValidationException(ErrorCodes.phoneInvalid, field: 'phone');
    }
    return s;
  }

  /// Whole-taka amount 0..1,000,000. Accepts Bangla digits, spaces, commas and
  /// a leading ৳. Throws [ValidationException] (`amountInvalid` /
  /// `amountTooLarge`, field `amount`).
  static int amount(String raw) {
    final s = AppFormat.toAsciiDigits(raw).replaceAll(RegExp(r'[\s,৳]'), '');
    if (s.isEmpty || !_digitsOnly.hasMatch(s)) {
      throw const ValidationException(ErrorCodes.amountInvalid, field: 'amount');
    }
    final significant = s.replaceFirst(RegExp(r'^0+'), '');
    if (significant.length > 7) {
      throw const ValidationException(
        ErrorCodes.amountTooLarge,
        field: 'amount',
      );
    }
    final v = significant.isEmpty ? 0 : int.parse(significant);
    if (v > amountMax) {
      throw const ValidationException(
        ErrorCodes.amountTooLarge,
        field: 'amount',
      );
    }
    return v;
  }

  /// Lenient integer parse for steppers / free numeric fields: Bangla or ASCII
  /// digits, optional leading `-`, commas and spaces ignored. Null when [raw]
  /// is not an integer (or is absurdly long).
  static int? intLoose(String raw) {
    final s = AppFormat.toAsciiDigits(raw).replaceAll(RegExp(r'[\s,]'), '');
    if (s.isEmpty || s.length > 15) return null;
    return int.tryParse(s);
  }
}
