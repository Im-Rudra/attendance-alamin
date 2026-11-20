import 'package:attendance_alamin/core/time/clock.dart';

/// Source of sync-column values for repository writes (Arch 3.1, plan 2.6).
///
/// - insert: `createdAt = updatedAt = nowMs()`, `rev = 1`, `deviceId`.
/// - update / soft delete: `updatedAt = nextUpdatedAt(old.updatedAt)`,
///   `rev = nextRev(old.rev)`, `deviceId`.
class SyncStamper {
  SyncStamper({required Clock clock, required this.deviceId}) : _clock = clock;

  final Clock _clock;

  /// Device of the writer (stored in `device_id`).
  final String deviceId;

  /// The current instant as UTC epoch ms.
  int nowMs() => _clock.nowUtc().millisecondsSinceEpoch;

  /// `max(now, oldUpdatedAt + 1)`: monotonic per row despite clock skew.
  int nextUpdatedAt(int oldUpdatedAt) {
    final now = nowMs();
    final bumped = oldUpdatedAt + 1;
    return now > bumped ? now : bumped;
  }

  /// `oldRev + 1`.
  int nextRev(int oldRev) => oldRev + 1;
}
