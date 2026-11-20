/// The closed list of error codes. Each has an `err<Code>` ARB key (M3-C).
abstract final class ErrorCodes {
  static const nameRequired = 'nameRequired';
  static const nameTooLong = 'nameTooLong';
  static const phoneInvalid = 'phoneInvalid';
  static const amountInvalid = 'amountInvalid';
  static const amountTooLarge = 'amountTooLarge';
  static const dateInvalid = 'dateInvalid';
  static const dateInFuture = 'dateInFuture';
  static const feeMonthBeforeStart = 'feeMonthBeforeStart';
  static const slotTimeInvalid = 'slotTimeInvalid';
  static const slotsEmpty = 'slotsEmpty';
  static const scheduleClash = 'scheduleClash';
  static const allocationExceedsRemaining = 'allocationExceedsRemaining';
  static const allocationBeyondHorizon = 'allocationBeyondHorizon';
  static const duplicateOpenEnrollment = 'duplicateOpenEnrollment';
  static const notFound = 'notFound';
  static const rollCallFutureDate = 'rollCallFutureDate';
  static const batchArchived = 'batchArchived';
  static const photoTooLarge = 'photoTooLarge';
  static const importNotBackup = 'importNotBackup';
  static const importNewerSchema = 'importNewerSchema';
  static const importChecksum = 'importChecksum';
  static const importCorrupt = 'importCorrupt';
  static const importMissingParent = 'importMissingParent';
  static const storageFailed = 'storageFailed';
  static const unknown = 'unknown';

  /// Every code above, in declaration order.
  static const all = <String>[
    nameRequired,
    nameTooLong,
    phoneInvalid,
    amountInvalid,
    amountTooLarge,
    dateInvalid,
    dateInFuture,
    feeMonthBeforeStart,
    slotTimeInvalid,
    slotsEmpty,
    scheduleClash,
    allocationExceedsRemaining,
    allocationBeyondHorizon,
    duplicateOpenEnrollment,
    notFound,
    rollCallFutureDate,
    batchArchived,
    photoTooLarge,
    importNotBackup,
    importNewerSchema,
    importChecksum,
    importCorrupt,
    importMissingParent,
    storageFailed,
    unknown,
  ];
}
