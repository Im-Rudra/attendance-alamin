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

## Polish backlog (do before the Judge)
- Batch schedule tab on wide windows: right column shorter than the left leaves blank space (user explicitly forbids eye-pinching blank areas) — M6-A, #19.
- Week grid look at 1.3× Bangla text unverified (M6-B, #18).

## From M6-A (schedule editing, #19)
- `showReminderLeadSheet` returns `kReminderLeadUseDefault` (-1) for "use default", null for dismissed; save `storedLeadOf(result)`.
- `SlotEditorField` reads `initial` once — build it after data loads. Embed the real `BatchScheduleTab` from schedule_entry.dart.

## From M5-A (shell, #16) and M5-B (providers + harness, #15)
- Feature modules REPLACE THE BODIES of their stub screens and `*_entry.dart` files; never change routes, route params or entry signatures (router is frozen). Forms, slot editors, roll call, bulk-add and backup review open full-screen on the root navigator.
- `/students/new` gets `initialBatchId` via GoRouter `extra` (no ids in query strings). `/` redirects to `/today`.
- For list‖detail use the shell's `pane_split.dart` (PaneSplit/PaneScope, width saved under LocalMeta `pane:<screen>`), not raw PaneLayout. Use `StubScreen`'s chrome only as a fallback.
- Contact: `ContactActions.canCall/icon/label` (call on Android, copy number on Windows/web). Share via `share_service.dart`.
- Data: use M5-B providers (`todayProvider`, day plans via `buildDayPlans`/schedule providers, `enrollmentDuesProvider` for per-month detail, `studentDuesProvider` is null when nothing is open, `attendanceTallyProvider`). `DayClass.state` precedence: cancelled > moved > extra > now.
- Tests: every screen goes through `testScreenMatrix` (light/dark × bn/en × phone/desktop, fails on overflow) using `seedFakes(...)` fixtures from `test/helpers/fixtures.dart`; FixedClock default is 2026-11-21 10:00 Dhaka. Fonts are real Hind Siliguri in tests.
- The Fees tab overdue badge is M7-C's job (needs dues providers).

## From M4-D (Aurora widgets, #11)
- Import widgets via the barrel `package:attendance_alamin/app/widgets/widgets.dart`. Map enums with `dueLevel.severityLevel` / `status.kind` (theme_mapping.dart), never by hand.
- `PaneLayout` is stateless: the parent stores `listWidth` in LocalMeta (pane-width key) and passes it back, or the drag won't persist.
- `BentoGrid` placements are zero-based; it scrolls itself when tiles exceed the height (row unit = max(184, (H − 2·gutter)/3)).
- Glass is blur only (no saturation boost).
- Widget tests use the default test font; Bangla metrics at 1.3× text scale must be checked in the M5 screenshot matrix.

## From M4-C (settings + backup data, #12)
- M9-A must set `SettingKeys.lastExportAt` itself, only after `BackupFiles.save` returns true (a cancelled save is not a backup). On web `save` always returns true.
- Call settings with the typed `SettingKeys.x` constants; iterating `SettingKeys.all` through the generic methods fails a runtime type check.
- `restoreSafetyCopy` first saves the current data as a new safety copy (reason `restore`), so a restore is undoable. An empty summary returns `ApplyOutcome(applied: 0, safetyCopyId: '')`.

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
