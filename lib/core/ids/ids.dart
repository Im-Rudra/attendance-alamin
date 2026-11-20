import 'dart:convert';

import 'package:attendance_alamin/core/time/year_month.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Row identifiers.
///
/// Ordinary rows use random v4 UUIDs. Rows with a natural key (a fee for
/// (batch, month), an attendance record for (occurrence, student), ...) use
/// deterministic v5 UUIDs so two devices that create "the same" row produce
/// the same id and merge cleanly.
abstract final class Ids {
  /// v5 namespace of this app (Arch section 3.1).
  static const namespace = '6f1c2b7e-1d0a-4c55-9b7e-2a4e1f0c9d31';

  static const Uuid _uuid = Uuid();

  /// A random v4 UUID.
  static String v4() => _uuid.v4();

  /// RFC 4122 name-based (SHA-1) UUID of [key] inside [namespace].
  static String v5(String key) => v5In(namespace, key);

  /// 31-bit FNV-1a hash of the UTF-8 bytes of [s]; always in `0..0x7FFFFFFF`
  /// (a valid positive Android notification id).
  ///
  /// Web-safe: every product is built from 16-bit partial products, so no
  /// intermediate value exceeds 2^53 (no 64-bit integer tricks).
  static int fnv1a31(String s) {
    const primeHi = 0x0100; // FNV prime 0x01000193 = (0x0100 << 16) | 0x0193
    const primeLo = 0x0193;
    var h = 0x811c9dc5;
    for (final b in utf8.encode(s)) {
      h = (h ^ b) & 0xFFFFFFFF;
      final hi = h >> 16;
      final lo = h & 0xFFFF;
      final cross = (hi * primeLo + lo * primeHi) & 0xFFFF;
      h = ((cross << 16) + lo * primeLo) & 0xFFFFFFFF;
    }
    return h & 0x7FFFFFFF;
  }

  /// Fee-history row of a batch: `v5('fee:<batchId>:<yyyymm>')`.
  static String batchFee(String batchId, YearMonth m) =>
      v5('fee:$batchId:${m.toInt()}');

  /// Fee-override row of an enrollment: `v5('efee:<enrollmentId>:<yyyymm>')`.
  static String enrollmentFee(String enrollmentId, YearMonth m) =>
      v5('efee:$enrollmentId:${m.toInt()}');

  /// Waiver row of an enrollment month: `v5('waive:<enrollmentId>:<yyyymm>')`.
  static String waiver(String enrollmentId, YearMonth m) =>
      v5('waive:$enrollmentId:${m.toInt()}');

  /// Cancel / reschedule exception of an occurrence: `v5('exc:<occ>')`.
  static String exceptionForOcc(String occ) => v5('exc:$occ');

  /// Attendance session of an occurrence: `v5('ses:<occ>')`.
  static String sessionForOcc(String occ) => v5('ses:$occ');

  /// Attendance record of (occurrence, student): `v5('att:<occ>:<studentId>')`.
  static String record(String occ, String studentId) =>
      v5('att:$occ:$studentId');

  /// Name-based UUID of [name] inside an explicit [ns] (exposed for RFC test vectors).
  static String v5In(String ns, String name) {
    final nsBytes = _parseUuid(ns);
    final input = <int>[...nsBytes, ...utf8.encode(name)];
    final digest = sha1.convert(input).bytes;
    final bytes = List<int>.from(digest.sublist(0, 16));
    bytes[6] = (bytes[6] & 0x0F) | 0x50; // version 5
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // RFC 4122 variant
    final hex = StringBuffer();
    for (final b in bytes) {
      hex.write(b.toRadixString(16).padLeft(2, '0'));
    }
    final h = hex.toString();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
        '-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static List<int> _parseUuid(String uuid) {
    final hex = uuid.replaceAll('-', '');
    if (hex.length != 32) {
      throw FormatException('Invalid UUID', uuid);
    }
    return <int>[
      for (var i = 0; i < 32; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }
}
