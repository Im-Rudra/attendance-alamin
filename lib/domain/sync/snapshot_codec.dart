import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:attendance_alamin/core/errors/app_exception.dart';
import 'package:attendance_alamin/core/errors/error_codes.dart';
import 'package:attendance_alamin/domain/sync/sync_models.dart';
import 'package:attendance_alamin/domain/sync/synced_tables.dart';
import 'package:crypto/crypto.dart';

/// Backup file codec (Arch §3.4): `gzip(utf8(canonicalJson(envelope)))`.
///
/// Envelope keys: `format`, `formatVersion`, `schemaVersion`, `appVersion`,
/// `snapshotId`, `deviceId`, `deviceName`, `createdAt`, `counts`, `sha256`,
/// `tables`. `sha256` is the lowercase hex SHA-256 of
/// `utf8(canonicalJson(tables))` with every table's rows sorted by `id`.
///
/// Pure Dart and web-safe: no `dart:io`, no 64-bit integer tricks.
abstract final class SnapshotCodec {
  static const format = 'attendance-alamin-backup';
  static const formatVersion = 1;

  // ---------------------------------------------------------------------------
  // Canonical JSON & checksum
  // ---------------------------------------------------------------------------

  /// Deterministic JSON: object keys sorted (UTF-16 code-unit order), no
  /// whitespace, strings escaped minimally (`"`, `\` and control characters),
  /// integral doubles written as integers so the VM and the web agree.
  ///
  /// Lists keep their order: callers pre-sort rows by id ([tablesSha256] and
  /// [encode] do). Throws [ArgumentError] for non-JSON values (non-String map
  /// keys, NaN/infinite numbers, other objects).
  static String canonicalJson(Object? value) {
    final sb = StringBuffer();
    _writeCanonical(sb, value);
    return sb.toString();
  }

  /// Lowercase hex SHA-256 of `utf8(canonicalJson(tables))`, rows sorted by
  /// `id` (input row order and column order do not matter).
  static String tablesSha256(Map<String, List<RowMap>> tables) {
    final sorted = <String, List<RowMap>>{
      for (final e in tables.entries) e.key: _sortedById(e.key, e.value),
    };
    return sha256.convert(utf8.encode(canonicalJson(sorted))).toString();
  }

  // ---------------------------------------------------------------------------
  // Build / encode / decode
  // ---------------------------------------------------------------------------

  /// Builds an export snapshot from raw table rows (tombstones included; blobs
  /// already base64 strings). Rows are copied, sorted by id and made
  /// unmodifiable; `counts` = live (non-tombstoned) rows per table.
  ///
  /// Throws [ArgumentError] when a row has no non-empty String `id` or a table
  /// repeats an id (programming errors in the data layer).
  static Snapshot build({
    required Map<String, List<RowMap>> tables,
    required String appVersion,
    required String snapshotId,
    required String deviceId,
    required String deviceName,
    required int createdAtMs,
  }) {
    final frozen = _freezeTables(tables);
    return Snapshot(
      formatVersion: formatVersion,
      schemaVersion: kCurrentSchemaVersion,
      appVersion: appVersion,
      snapshotId: snapshotId,
      deviceId: deviceId,
      deviceName: deviceName,
      createdAtMs: createdAtMs,
      counts: _liveCounts(frozen),
      sha256: tablesSha256(frozen),
      tables: frozen,
    );
  }

  /// `gzip(utf8(canonicalJson(envelope)))`. Fields are written as given
  /// (the checksum is not recomputed), so a snapshot from [build] round-trips.
  static List<int> encode(Snapshot s) {
    final envelope = <String, Object?>{
      'format': format,
      'formatVersion': s.formatVersion,
      'schemaVersion': s.schemaVersion,
      'appVersion': s.appVersion,
      'snapshotId': s.snapshotId,
      'deviceId': s.deviceId,
      'deviceName': s.deviceName,
      'createdAt': s.createdAtMs,
      'counts': s.counts,
      'sha256': s.sha256,
      'tables': <String, List<RowMap>>{
        for (final e in s.tables.entries) e.key: _sortedById(e.key, e.value),
      },
    };
    return GZipEncoder().encodeBytes(utf8.encode(canonicalJson(envelope)));
  }

  /// Parses and verifies a backup file. Throws [ImportException] with:
  /// - `importNotBackup`: not gzip, or a valid gzip whose content is not this
  ///   app's backup (not UTF-8 / not JSON / no matching `format`);
  /// - `importCorrupt`: gzip stream damaged or truncated (inflate error, or
  ///   CRC-32 / length trailer mismatch), or a backup with missing/mistyped
  ///   fields, rows without ids, duplicate ids or bad sync columns;
  /// - `importNewerSchema`: `formatVersion` or `schemaVersion` newer than this
  ///   app understands (checked before the checksum);
  /// - `importChecksum`: tables do not match the recorded `sha256`.
  ///
  /// `counts` are recomputed from the verified tables (the file's own counts
  /// are informational and not covered by the checksum).
  static Snapshot decode(List<int> bytes) {
    // 1. gzip container. The format is detected by content, not extension.
    if (bytes.length < 2 || bytes[0] != 0x1f || bytes[1] != 0x8b) {
      _fail(ErrorCodes.importNotBackup, 'not gzip');
    }
    if (bytes.length < 18) _fail(ErrorCodes.importCorrupt, 'gzip too short');
    final List<int> raw;
    try {
      raw = GZipDecoder().decodeBytes(bytes, verify: true);
    } catch (e) {
      // Inflate errors in the pure-Dart decoder can surface as RangeError etc.
      _fail(ErrorCodes.importCorrupt, 'gzip: $e');
    }
    // Own trailer check: archive's dart:io path may accept damaged streams.
    final n = bytes.length;
    final trailerCrc = _readUint32Le(bytes, n - 8);
    final trailerSize = _readUint32Le(bytes, n - 4);
    if (trailerSize != raw.length % 4294967296 || trailerCrc != _crc32(raw)) {
      _fail(ErrorCodes.importCorrupt, 'gzip trailer mismatch');
    }

    // 2. JSON envelope.
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(raw));
    } on FormatException catch (e) {
      _fail(ErrorCodes.importNotBackup, 'not json: ${e.message}');
    }
    if (json is! Map<String, dynamic> || json['format'] != format) {
      _fail(ErrorCodes.importNotBackup, 'format marker missing');
    }

    // 3. Versions (refuse newer before anything else can misinterpret data).
    final fv = _field<int>(json, 'formatVersion');
    final sv = _field<int>(json, 'schemaVersion');
    if (fv > formatVersion || sv > kCurrentSchemaVersion) {
      _fail(ErrorCodes.importNewerSchema, 'formatVersion $fv schemaVersion $sv');
    }
    if (fv < 1 || sv < 1) _fail(ErrorCodes.importCorrupt, 'bad version');

    // 4. Envelope fields.
    final appVersion = _field<String>(json, 'appVersion');
    final snapshotId = _field<String>(json, 'snapshotId');
    final deviceId = _field<String>(json, 'deviceId');
    final deviceName = _field<String>(json, 'deviceName');
    final createdAt = _field<int>(json, 'createdAt');
    final sha = _field<String>(json, 'sha256');
    final rawTables = _field<Map<String, dynamic>>(json, 'tables');

    // 5. Table shape (needed to compute the checksum).
    final tables = <String, List<RowMap>>{};
    for (final e in rawTables.entries) {
      final list = e.value;
      if (list is! List) _fail(ErrorCodes.importCorrupt, 'table ${e.key}');
      final rows = <RowMap>[];
      final seen = <String>{};
      for (final r in list) {
        if (r is! Map<String, dynamic>) {
          _fail(ErrorCodes.importCorrupt, 'row in ${e.key}');
        }
        final id = r['id'];
        if (id is! String || id.isEmpty) {
          _fail(ErrorCodes.importCorrupt, 'row id in ${e.key}');
        }
        if (!seen.add(id)) _fail(ErrorCodes.importCorrupt, 'duplicate id ${e.key}/$id');
        rows.add(Map<String, Object?>.unmodifiable(r));
      }
      rows.sort(_byId);
      tables[e.key] = List<RowMap>.unmodifiable(rows);
    }

    // 6. Integrity.
    if (tablesSha256(tables) != sha.toLowerCase()) {
      _fail(ErrorCodes.importChecksum, 'sha256 mismatch');
    }

    // 7. Sync columns (the diff relies on them).
    for (final e in tables.entries) {
      for (final r in e.value) {
        if (!_validSyncColumns(r)) {
          _fail(ErrorCodes.importCorrupt, 'sync columns ${e.key}/${r['id']}');
        }
      }
    }

    return Snapshot(
      formatVersion: fv,
      schemaVersion: sv,
      appVersion: appVersion,
      snapshotId: snapshotId,
      deviceId: deviceId,
      deviceName: deviceName,
      createdAtMs: createdAt,
      counts: _liveCounts(tables),
      sha256: sha.toLowerCase(),
      tables: Map<String, List<RowMap>>.unmodifiable(tables),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Never _fail(String code, String detail) =>
      throw ImportException(code, detail: detail);

  static T _field<T>(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is T) return v;
    _fail(ErrorCodes.importCorrupt, 'field $key');
  }

  static bool _validSyncColumns(RowMap r) {
    final id = r['id'];
    final deletedAt = r['deleted_at'];
    final deviceId = r['device_id'];
    return id is String &&
        id.isNotEmpty &&
        r['created_at'] is int &&
        r['updated_at'] is int &&
        (deletedAt == null || deletedAt is int) &&
        r.containsKey('deleted_at') &&
        deviceId is String &&
        r['rev'] is int;
  }

  static int _byId(RowMap a, RowMap b) =>
      (a['id'] as String).compareTo(b['id'] as String);

  static List<RowMap> _sortedById(String table, List<RowMap> rows) {
    for (final r in rows) {
      final id = r['id'];
      if (id is! String) {
        throw ArgumentError.value(id, 'id', 'row in $table has no String id');
      }
    }
    return List<RowMap>.of(rows)..sort(_byId);
  }

  static Map<String, List<RowMap>> _freezeTables(Map<String, List<RowMap>> tables) {
    final ordered = <String>[
      ...kSyncedTables.where(tables.containsKey),
      ...(tables.keys.where((t) => !kSyncedTables.contains(t)).toList()..sort()),
    ];
    final out = <String, List<RowMap>>{};
    for (final t in ordered) {
      final seen = <String>{};
      final rows = <RowMap>[];
      for (final r in tables[t]!) {
        final id = r['id'];
        if (id is! String || id.isEmpty) {
          throw ArgumentError.value(id, 'id', 'row in $t needs a non-empty String id');
        }
        if (!seen.add(id)) {
          throw ArgumentError.value(id, 'id', 'duplicate id in $t');
        }
        rows.add(Map<String, Object?>.unmodifiable(r));
      }
      rows.sort(_byId);
      out[t] = List<RowMap>.unmodifiable(rows);
    }
    return Map<String, List<RowMap>>.unmodifiable(out);
  }

  static Map<String, int> _liveCounts(Map<String, List<RowMap>> tables) =>
      Map<String, int>.unmodifiable(<String, int>{
        for (final e in tables.entries)
          e.key: e.value.where((r) => r['deleted_at'] == null).length,
      });

  static int _readUint32Le(List<int> b, int o) =>
      b[o] + b[o + 1] * 0x100 + b[o + 2] * 0x10000 + b[o + 3] * 0x1000000;

  static List<int>? _crcTable;

  /// CRC-32 (IEEE 802.3, as in the gzip trailer). Only 32-bit operations.
  static int _crc32(List<int> data) {
    final table = _crcTable ??= List<int>.generate(256, (n) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
      }
      return c;
    }, growable: false);
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      crc = table[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  static void _writeCanonical(StringBuffer sb, Object? v) {
    if (v == null) {
      sb.write('null');
    } else if (v is bool) {
      sb.write(v ? 'true' : 'false');
    } else if (v is int) {
      sb.write(v.toString());
    } else if (v is double) {
      if (v.isNaN || v.isInfinite) {
        throw ArgumentError.value(v, 'value', 'not representable in JSON');
      }
      if (v == v.truncateToDouble() && v.abs() <= 9007199254740991) {
        sb.write(v.toInt().toString());
      } else {
        sb.write(v.toString());
      }
    } else if (v is String) {
      _writeString(sb, v);
    } else if (v is List) {
      sb.write('[');
      for (var i = 0; i < v.length; i++) {
        if (i > 0) sb.write(',');
        _writeCanonical(sb, v[i]);
      }
      sb.write(']');
    } else if (v is Map) {
      final keys = <String>[];
      for (final k in v.keys) {
        if (k is! String) {
          throw ArgumentError.value(k, 'key', 'JSON object keys must be Strings');
        }
        keys.add(k);
      }
      keys.sort();
      sb.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) sb.write(',');
        _writeString(sb, keys[i]);
        sb.write(':');
        _writeCanonical(sb, v[keys[i]]);
      }
      sb.write('}');
    } else {
      throw ArgumentError.value(v, 'value', 'not a JSON value (${v.runtimeType})');
    }
  }

  static void _writeString(StringBuffer sb, String s) {
    sb.write('"');
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      switch (c) {
        case 0x22:
          sb.write(r'\"');
        case 0x5c:
          sb.write(r'\\');
        case 0x08:
          sb.write(r'\b');
        case 0x0c:
          sb.write(r'\f');
        case 0x0a:
          sb.write(r'\n');
        case 0x0d:
          sb.write(r'\r');
        case 0x09:
          sb.write(r'\t');
        default:
          if (c < 0x20) {
            sb.write(r'\u');
            sb.write(c.toRadixString(16).padLeft(4, '0'));
          } else {
            sb.writeCharCode(c);
          }
      }
    }
    sb.write('"');
  }
}
