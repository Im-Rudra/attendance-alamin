import 'package:attendance_alamin/core/time/local_date.dart';

/// Parsed occurrence id (architecture 3.2a).
sealed class OccRef {
  const OccRef();
}

/// `s.<slot_id>.<original_date yyyymmdd>`; also identifies a rescheduled class.
final class RegularOccRef extends OccRef {
  const RegularOccRef(this.slotId, this.originalDate);

  final String slotId;
  final LocalDate originalDate;

  @override
  bool operator ==(Object other) =>
      other is RegularOccRef &&
      other.slotId == slotId &&
      other.originalDate == originalDate;

  @override
  int get hashCode => Object.hash(slotId, originalDate);

  @override
  String toString() => 'RegularOccRef($slotId, $originalDate)';
}

/// `x.<exception_id>`.
final class ExtraOccRef extends OccRef {
  const ExtraOccRef(this.exceptionId);

  final String exceptionId;

  @override
  bool operator ==(Object other) =>
      other is ExtraOccRef && other.exceptionId == exceptionId;

  @override
  int get hashCode => exceptionId.hashCode;

  @override
  String toString() => 'ExtraOccRef($exceptionId)';
}

abstract final class OccId {
  /// `s.<slot>.<yyyymmdd>`
  static String regular(String slotId, LocalDate originalDate) =>
      's.$slotId.${originalDate.toCompact()}';

  /// `x.<id>`
  static String extra(String exceptionId) => 'x.$exceptionId';

  /// Inverse of [regular] / [extra]. Throws [FormatException] on anything else.
  /// Ids may contain dashes (UUIDs); the date is whatever follows the LAST dot.
  static OccRef parse(String occ) {
    if (occ.startsWith('x.')) {
      final id = occ.substring(2);
      if (id.isEmpty) throw FormatException('Empty extra occurrence id', occ);
      return ExtraOccRef(id);
    }
    if (occ.startsWith('s.')) {
      final lastDot = occ.lastIndexOf('.');
      if (lastDot <= 2) {
        throw FormatException('Malformed regular occurrence id', occ);
      }
      final slotId = occ.substring(2, lastDot);
      final datePart = occ.substring(lastDot + 1);
      if (slotId.isEmpty) {
        throw FormatException('Empty slot id in occurrence id', occ);
      }
      try {
        return RegularOccRef(slotId, LocalDate.parseCompact(datePart));
      } on FormatException {
        throw FormatException('Malformed date in occurrence id', occ);
      }
    }
    throw FormatException('Unknown occurrence id', occ);
  }
}
