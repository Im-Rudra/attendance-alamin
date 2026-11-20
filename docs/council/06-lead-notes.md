# Lead notes — binding caller rules reported by merged modules

Builders of later modules must follow these (they are not all in 04-plan.md).

## From M3-B (theme, #2)
- Severity/attendance colour APIs take theme-local enums. Map with `SeverityLevel.values[dueLevel.index]` and `AttendanceKind.values[status.index]` (M1-B locks the order). M4-D should add one small extension so features never repeat the index mapping.
- Light hero violet radial peak alpha is 0.80 (contrast fix).
- Mesh gradients are radius 1.0 fading to 0 at stop 0.7; M4-D applies the per-pool ellipse sizing from UX §4 rule 7.
- `EffectsMode.reducedOf` belongs to M4-D.

## From M1-B (domain models, #5)
- `Slot.activeOn` checks only validity bounds, not the weekday.
- `ChangeSummary.totalChanges` = added + updated + deleted (excludes keptLocal).
- Enum `parse` methods throw `FormatException` on unknown codes; `PaymentMethod.custom` throws `ValidationException`.

## From M2-C (reminders + stats, #6)
- `PlannedReminder` carries no text: the notification layer (M8-D) builds title/body from kind/startMin/endMin/leadMin via l10n (Product §3.11 text + suffixes).
- Use `AttendanceStats.tallyWithin(..., from: joinDate, to: endDate)` so the denominator is bounded by enrollment dates.
- Fire time ≤ now is skipped; default lead 0 and negative leads mean off.

## From M3-A (drift database, #7)
- `package:drift/drift.dart` exports `Batch` (clashes with domain `Batch`) and `isNull`/`isNotNull` (clash with flutter_test): import drift with `hide Batch` / `show ...` everywhere.
- `enrollmentEnded` means `end_date != null`; a tombstoned subject's `subjectName` reads as `''`.
- Extra CHECKs exist: session start < end, `waived = 0 OR amount = 0`, extras have no slot/original date, `student_photos.id` references students, jpeg ≤ 204800 bytes. Repositories validate these first and throw AppException (never surface raw SQLite errors).
- **Open risk for M5-A (bootstrap):** `openConnection` has no fallback if `WasmDatabase.open` throws (e.g. a browser that blocks SharedWorker/fetch). The bootstrap must catch DB-open failure and show a full-screen, localised "data storage couldn't start" error with a retry, never a blank/crashed app; and show the red "data won't be saved" banner when the storage report is in-memory.
- Pre-migration safety snapshot is not implemented (v1 has no upgrade steps); required before schemaVersion 2.

## From M2-D (snapshot codec + diff, #10)
- `winners` can be non-empty while the summary `isEmpty` is true (unknown tombstones, deleted-only changes): the data layer applies the merge ONLY when `!isEmpty`, else reports "no changes".
- Apply `winners` in their given order (deletions first, then table registry order) inside one transaction with foreign keys deferred (Arch §3.6).
- Change-summary items are grouped teacher-visibly (fees under batch, photos under student, payment rows under receipt_id); samples carry `_table` and payments `_receipt_total`.
- `decode` error codes: importNotBackup, importCorrupt, importNewerSchema (checked before checksum), importChecksum.

## From M2-A (dues engine, #8)
- `autoAllocate` needs dues from `forEnrollment` computed with the same `today` and `aheadMonths ≥ 12`.
- When editing a receipt, build the dues passed to `validateAllocations` WITHOUT that receipt's own allocation rows.
- `report()` lists only enrollments with an open due month; left/archived/ended go to `inactive` (grey group, worst = null, not in countByLevel). A student active in one batch and left in another appears in both lists.
- A month with no fee on record is `free` (fee 0), never a due.
