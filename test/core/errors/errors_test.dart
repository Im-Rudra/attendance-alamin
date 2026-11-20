import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorCodes', () {
    test('all lists every code exactly once and each code equals its name', () {
      expect(ErrorCodes.all.length, 25);
      expect(ErrorCodes.all.toSet().length, ErrorCodes.all.length);
      const expectedCodes = [
        'nameRequired',
        'nameTooLong',
        'phoneInvalid',
        'amountInvalid',
        'amountTooLarge',
        'dateInvalid',
        'dateInFuture',
        'feeMonthBeforeStart',
        'slotTimeInvalid',
        'slotsEmpty',
        'scheduleClash',
        'allocationExceedsRemaining',
        'allocationBeyondHorizon',
        'duplicateOpenEnrollment',
        'notFound',
        'rollCallFutureDate',
        'batchArchived',
        'photoTooLarge',
        'importNotBackup',
        'importNewerSchema',
        'importChecksum',
        'importCorrupt',
        'importMissingParent',
        'storageFailed',
        'unknown',
      ];
      expect(ErrorCodes.all, expectedCodes);
    });

    test('codes are valid ARB-suffix identifiers', () {
      final re = RegExp(r'^[a-z][A-Za-z0-9]*$');
      for (final c in ErrorCodes.all) {
        expect(re.hasMatch(c), isTrue, reason: c);
      }
    });

    test('constants resolve', () {
      expect(ErrorCodes.scheduleClash, 'scheduleClash');
      expect(ErrorCodes.unknown, 'unknown');
    });
  });

  group('AppException', () {
    test('ValidationException carries code, field, detail', () {
      const e = ValidationException(
        ErrorCodes.phoneInvalid,
        field: 'phone',
        detail: 'x',
      );
      expect(e, isA<AppException>());
      expect(e, isA<Exception>());
      expect(e.code, 'phoneInvalid');
      expect(e.field, 'phone');
      expect(e.detail, 'x');
      expect(e.toString(), 'ValidationException(phoneInvalid: x)');
    });

    test('ValidationException field and detail are optional', () {
      const e = ValidationException(ErrorCodes.nameRequired);
      expect(e.field, isNull);
      expect(e.detail, isNull);
      expect(e.toString(), 'ValidationException(nameRequired)');
    });

    test('other subclasses', () {
      const nf = NotFoundException(ErrorCodes.notFound, detail: 'student 1');
      const imp = ImportException(ErrorCodes.importCorrupt);
      const st = StorageException(ErrorCodes.storageFailed);
      expect(nf, isA<AppException>());
      expect(nf.code, 'notFound');
      expect(nf.detail, 'student 1');
      expect(imp, isA<AppException>());
      expect(imp.code, 'importCorrupt');
      expect(st, isA<AppException>());
      expect(st.code, 'storageFailed');
    });

    test('can be caught as AppException', () {
      expect(
        () => throw const NotFoundException(ErrorCodes.notFound),
        throwsA(isA<AppException>()),
      );
    });
  });
}
