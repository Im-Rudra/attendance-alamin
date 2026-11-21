import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/l10n/generated/app_localizations.dart';

/// User-facing message for [error]. An [AppException] maps by its code to the
/// `err<Code>` string; anything else (or an unknown code) gives `errUnknown`.
/// Never exposes technical detail.
String errorText(AppLocalizations l10n, Object error) {
  final code = error is AppException ? error.code : ErrorCodes.unknown;
  return errorTextForCode(l10n, code);
}

/// Message for one `ErrorCodes` value; unknown codes give `errUnknown`.
String errorTextForCode(AppLocalizations l10n, String code) {
  switch (code) {
    case ErrorCodes.nameRequired:
      return l10n.errNameRequired;
    case ErrorCodes.nameTooLong:
      return l10n.errNameTooLong;
    case ErrorCodes.phoneInvalid:
      return l10n.errPhoneInvalid;
    case ErrorCodes.amountInvalid:
      return l10n.errAmountInvalid;
    case ErrorCodes.amountTooLarge:
      return l10n.errAmountTooLarge;
    case ErrorCodes.dateInvalid:
      return l10n.errDateInvalid;
    case ErrorCodes.dateInFuture:
      return l10n.errDateInFuture;
    case ErrorCodes.feeMonthBeforeStart:
      return l10n.errFeeMonthBeforeStart;
    case ErrorCodes.slotTimeInvalid:
      return l10n.errSlotTimeInvalid;
    case ErrorCodes.slotsEmpty:
      return l10n.errSlotsEmpty;
    case ErrorCodes.scheduleClash:
      return l10n.errScheduleClash;
    case ErrorCodes.allocationExceedsRemaining:
      return l10n.errAllocationExceedsRemaining;
    case ErrorCodes.allocationBeyondHorizon:
      return l10n.errAllocationBeyondHorizon;
    case ErrorCodes.duplicateOpenEnrollment:
      return l10n.errDuplicateOpenEnrollment;
    case ErrorCodes.notFound:
      return l10n.errNotFound;
    case ErrorCodes.rollCallFutureDate:
      return l10n.errRollCallFutureDate;
    case ErrorCodes.heldClassToFuture:
      return l10n.errHeldClassToFuture;
    case ErrorCodes.batchArchived:
      return l10n.errBatchArchived;
    case ErrorCodes.photoTooLarge:
      return l10n.errPhotoTooLarge;
    case ErrorCodes.importNotBackup:
      return l10n.errImportNotBackup;
    case ErrorCodes.importNewerSchema:
      return l10n.errImportNewerSchema;
    case ErrorCodes.importChecksum:
      return l10n.errImportChecksum;
    case ErrorCodes.importCorrupt:
      return l10n.errImportCorrupt;
    case ErrorCodes.importMissingParent:
      return l10n.errImportMissingParent;
    case ErrorCodes.storageFailed:
      return l10n.errStorageFailed;
    default:
      return l10n.errUnknown;
  }
}
