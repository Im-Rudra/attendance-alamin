# Windows desktop UX review — full walkthrough of the real app (2026-11-22)

Method: Chair drove the installed Windows build (b244) with computer use on the owner's laptop (1920×1080 @125 % → 1536 logical). Every nav item, tab, button, ⋮ menu, row, chip, panel, dialog, picker and sub-page was opened (nothing saved). Passes: maximized 1536, restored ~1214, half-snap ~910; light + dark; Bangla + English. Owner's areas: **sizing / scaling / spacing, layout / navigation, look & feel.**

## Coverage
Today (day + week view, hero, every tile, New… menu → collect fee / add student / extra class, class popover → reschedule → date picker, extra class form, "attendance for another batch") · Batches (overview, list, detail + 4 tabs, Add student, edit panel, ⋮ menu → bulk add → CSV import, archive/delete entries, schedule tab → reminder dialog → weekly-time editor → per-day mode → time picker, attendance tab → other date, New batch panel, batch search) · Global search · Roll call (row ⋯ menu, toggles, all-present/absent, shortcuts, note, save bar, back) · Students (table, filters, batch select, Left chip, profile, copy number, collect fee, enrollment ⋮, profile ⋮, edit panel, enrol-another-batch, payment history, New student) · Fees (Dues, Collected, month nav, receipt dialog, edit payment, other income, CSV export, collect-fee picker + form) · More (Archive → archived batches / left students / holidays; Appearance; Coaching center; Class reminders → default time; Fees & payments → cut-off / payment methods / dues template / receipt template; Backup → backup page; About → licences / help / diagnostics) · sidebar collapse/rail.
Not reachable without resetting data: onboarding, reminder priming, a populated dues list, restore review. Reviewed in code/web only.

## Root causes
1. **No rule for where things open.** The same kind of task opens as a full page, a side panel, a centered dialog, a phone bottom sheet or an anchored popover depending on the entry point. The user never knows what will happen.
2. **No page templates / grid-sized cards.** Every page invents its width/alignment; equal-height grids make cards hollow *and* clipped.
3. **Overlay positioning is broken.** Menus/popovers open at the top of the window, at the left edge or past the bottom, not at their trigger.
4. **Phone sizes and phone patterns on desktop** (bottom sheets with grab handles, tiny meta text, full-width bars).
5. **Leftover visual noise.** Outline rings, underline tabs, mixed field styles, unthemed title bar.

## Findings by screen (★ = high impact)

### Shell / global
- ★G1 **Container chaos.** Add student = *full page* from Today › New, but *side panel* from Students. Bulk add, backup page and search = full pages without sidebar. Reschedule, extra class, other income and receipt = centered dialogs. Reminder minutes and fee cut-off = phone bottom sheets with a grab handle. Help and diagnostics = popovers hanging off the row. Payment, edit and payment methods = side panels.
- ★G2 **Esc is inconsistent.** It does nothing on full-page forms, bulk add, backup and roll call. In search it only clears the text. In Students, Esc on a menu or panel *also closes the student profile* (selection lost, seen 3×).
- ★G3 **No unsaved-changes guard.** Leaving Add student with data entered, or closing the weekly-time editor after a change, discards silently.
- G4 Search: three entry points (sidebar field, Ctrl K, per-page 🔍). Search opens as a bare full page with a card floating in the void, instead of a palette over the app.
- G5 Title bar follows Windows' theme, not the app's (dark bar over the light app).
- G6 Two app instances were running at once on the same database. There is no single-instance lock (data-safety risk).
- G7 Popovers/menus mispositioned:
  - the enrollment ⋮ opened at the window top;
  - "attendance for another batch" anchored to the hero's left edge;
  - the class popover covered the header;
  - the roll-call row menu is pinned to the left edge;
  - the attendance-tab date picker opened over the overview card;
  - Help and Diagnostics run off the bottom of the window.
- G8 Menus differ:
  - some have a title + ✕ header (New…, profile ⋮, row ⋯), others don't (enrollment ⋮);
  - Delete is red in the batch menu but plain in the student menu;
  - icons appear in some menus only.
- G9 Numbers are mixed: Bangla digits in the display, English digits inside fields (roll "05", phone, amounts).
- G10 Clicking a week-grid class needs >1 s before the popover appears (feels broken; first click looks like it did nothing).

### Today
- ★T1 Equal-height bento:
  - "Today's classes" is a ~420 px card holding one empty state;
  - "Recent payments" is clipped mid-row (third row and its share icon cut), with no scroll or "see all".
- T2 @1214: hero title ellipsized ("…— বি…"), hero button wraps to 2 lines; secondary link floats centered under the button.
- ★T3 New… › Collect fee *switches to the Fees tab* and makes you click Collect fee again. New… › Add student opens a full page (G1).
- T4 Week view:
  - class blocks are truncated ("Physics — HSC — 10 …") with no padding;
  - no current-time line;
  - the grid shows only about 3 hours and is heavy-lined;
  - the popover title reads "শুধু সোমবার…" (odd phrasing).
- T5 Extra class form **opens already in an error state** (defaults to a clashing time). The positive suggestion ("take 11:00–12:00") is a solid *red* button.
- T6 Reschedule: the time control is a − / + field (non-standard). Its big header area holds only ✕.
- T7 Backup tile copy: "Last backup 1 days ago".
- T8 Half-snap: the New… button disappears.

### Batches
- ★B1 Four columns at 1536 (sidebar · list · detail · rail):
  - the batch title wraps;
  - the rail is narrow and mostly empty (a chart with one bar);
  - the weekly routine is shown 3× (rail, schedule-tab summary, week chart).
- ★B2 Selected batch card:
  - light mode: text greyed out, so it looks *disabled*;
  - dark mode: a saturated full-indigo slab.
- B3 Detail tabs are underline tabs (not the segmented control). The header button "Add student" appears only on the Students tab, so the header jumps between tabs.
- B4 Attendance tab duplicates "Take attendance" (overview card + tab); then a large empty area.
- B5 Schedule tab: a full-width *primary* "change weekly time" button inside a tab (too loud).
- B6 Weekly-time editor:
  - unselected day chips have *no fill* (plain text, so they don't look clickable) and wrap 6+1;
  - per-day mode has no visible way to add a day;
  - time fields are white and outlined, unlike the soft fields elsewhere.
- B7 Time picker = a dialog stacked on a side panel stacked on the page (3 layers).
- B8 Batch reminder dialog: radio options drawn as a filled check vs outline checks (reads like checkboxes). The same setting in More is a bottom sheet with a list (two UIs).
- B9 Batch edit panel: Save is enabled with no changes; the read-only subject looks editable; the selected radio card has an outline ring; "Archive" is a link buried in the form.
- B10 Bulk add:
  - full page, card-in-card, the inner card only half the width (right half empty);
  - "Finish" is a text link at the far top-right;
  - CSV import jumps straight to the OS file picker without showing the expected format.
- B11 Overview (no batch selected): 4 small stat tiles, then a void.

### Roll call
- ★R1 Full-screen takeover (sidebar hidden). Esc does nothing.
- ★R1 (cont.) Save sits bottom-right in the rail, far from the rows. Two columns of short rows, then ~60 % empty canvas.
- R2 Start-time field white, end-time field soft. Two stacked tinted info banners.
- R3 Toggle: the selected thumb is an *outline ring*. An absent row turns grey (reads disabled), and the keyboard-focus outline around the whole row doubles the rings.
- R4 Prev/next date chevrons sit at the far window edges.
- R5 "Leave" (ছুটি) exists only in the ⋯ menu, not in the toggle.

### Students
- ★S1 Profile panel (Bangla):
  - due tags clip at the right edge ("এখনো সময় আছ…");
  - "Guardian · Copy number" wraps to 2 lines;
  - the panel is ~380 px while the table has lots of empty width.
- S2 Filter row mixes a borderless select with pill chips (different heights/styles). At half width the chips run off the edge.
- S3 Table:
  - the "Attendance" header is truncated in English;
  - the Due column is "—" for everyone (dead column);
  - the table sits in a tall, mostly empty card.
- S4 An empty filter result has no "clear filters" action.
- S5 Enrol-in-another-batch offers the batch the student is *already in* (with one batch it's a dead end).

### Fees
- ★F1 Dues with nothing due = a full-screen void with one line; no summary tiles.
- F2 Header actions change per segment (Collect fee + 🔍 vs Other income + ☁ + 🔍). ☁ = CSV export (a cloud icon misleads: it reads as sync/backup).
- F3 Collected: month nav spans the full width with chevrons at the extremes; stat numbers small; the progress bar floats between sections.
- F4 Receipt dialog:
  - plain text in a box (not a designed receipt);
  - **Delete is a solid red button equal to Edit**.
- F5 Collect-fee picker shows name + roll only: no batch, due amount or level.
- F6 Payment panel:
  - month chips wrap into 3 rows;
  - the "split months" select repeats its label;
  - large dead gap above Save.
- F7 Other income:
  - a dialog, not a panel;
  - the date is a button, not a field;
  - two disabled save buttons stacked.

### More / Settings
- ★M1 Sidebar item ≠ content: "Archive" was highlighted while Holidays showed. **Holidays lives under Archive** (wrong home); 3-level nesting with **no back button** from sub-pages (you must re-click the nav item).
- ★M2 Every section uses a different layout:
  - Holidays: centered 500 px card with a big title;
  - archived batches: small centered empty card;
  - left students: full-height empty card;
  - Appearance and the rest: left 680 px column, right half empty.
- M3 Backup has two UIs: the More › Backup list, and a separate full-page Backup reached from a row. That page has three tall equal cards with content floating mid-card, the third top-aligned. The primary action ("create backup") is an ordinary row.
- M4 Template editor:
  - raw `{student}` `{amount}` placeholders shown to the teacher;
  - editor and preview stacked in a 380 px panel, with the preview below the fold.
- M5 Fonts & licences dialog uses a text-only "close" button (yet another dialog style).
- M6 Coaching center: fields inside a card with hairlines between fields (double separation).

### Look & feel (cross-cutting)
- L1 Outline rings on selected states everywhere (segments, radio cards, attendance thumb, today in the calendar).
- L2 Field styles mixed: soft fill, white + outline, borderless select.
- L3 Empty states are the same small icon + one line everywhere; the app looks hollow with little data.
- L4 Flat hierarchy: all cards the same weight, section titles ≈ body size, small stat numbers.
- L5 Dark mode: side panels barely separate from the dimmed page; month chips low-contrast.

## Proposed direction (Gate 1)
Keep the approved ভোর look (warm paper + indigo, soft fills, spring motion, no glow). Rebuild the structure under it:

1. **One container rule**, enforced in `showBhorPanel` (and lint-checked):
   - desktop: every create/edit form and picker-with-content goes in a *side panel*;
   - every confirm or short choice is a *dialog*;
   - menus are *anchored popovers at their trigger*;
   - **no bottom sheets and no full pages for forms on desktop**;
   - phone: sheets, as now.
   - Add student, bulk add, backup, search, other income, reschedule, extra class, reminder/cut-off choosers all move to the rule.
2. **Overlay positioning fix**: one anchored-overlay engine (flip/shift to stay in the window, max-height + scroll) for all menus/popovers/pickers.
3. **Esc + unsaved guard**: Esc closes the top-most layer only (never the selection behind it). Forms/editors with changes ask "Discard?". Esc leaves roll call and the full pages that remain.
4. **Four page templates**, used by every page:
   - **Dashboard** (Today): content-sized masonry; lists show N + "সব দেখুন".
   - **Master-detail** (Batches/Students/Fees): no 4th column; the rail folds into detail.
   - **Settings**: one 720 px column, top-aligned, a back crumb on sub-pages; Holidays moves to its own item.
   - **Focus task** (roll call): keeps the sidebar, slim top bar, content ≤ 880 px centered, sticky bottom save bar.
5. **Desktop scale step** (≥ 1200): titles 28/22/18, body 15, stats 30. One spacing rhythm.
6. **Visual clean-up**:
   - remove all outline rings (filled thumbs);
   - one selection style (accentTint + 3 px bar) in both themes;
   - one field style;
   - segmented control instead of underline tabs;
   - designed empty states and zero-data tiles;
   - card hierarchy;
   - receipt as a designed card with a quiet Delete;
   - themed title bar;
   - single-instance lock;
   - Bangla digits in fields when the UI is in Bangla.
7. **Content fixes**:
   - extra class defaults to a free slot;
   - collect-fee picker shows batch + due;
   - template chips instead of raw `{}`;
   - remove duplicate buttons/routines;
   - "1 days".
8. **Verification**: the Chair re-walks this exact coverage list on the real Windows build at 1536/1214/910, light/dark, bn/en, plus the phone web at 390; then a naive tester and the Judge.

Out of scope: new features. Android keeps parity through the same components.
