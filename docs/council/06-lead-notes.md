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

## From M2-A (dues engine, #8)
- `autoAllocate` needs dues from `forEnrollment` computed with the same `today` and `aheadMonths ≥ 12`.
- When editing a receipt, build the dues passed to `validateAllocations` WITHOUT that receipt's own allocation rows.
- `report()` lists only enrollments with an open due month; left/archived/ended go to `inactive` (grey group, worst = null, not in countByLevel). A student active in one batch and left in another appears in both lists.
- A month with no fee on record is `free` (fee 0), never a due.
