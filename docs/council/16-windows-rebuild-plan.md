# Windows UI rebuild — plan (Gate 1 approved 2026-11-22)

Source of truth: `15-windows-ux-review.md` (every finding ID below refers to it) + `13-fluid-ui-spec.md` (look, tokens, motion; unchanged). Process: `05-builder-protocol.md` (branch → PR → full CI green → hand back once; Chair merges; no review agents). Functionality must not change except the listed behaviour fixes. No Material (CI check). Every new user-facing string goes in ARB (bn + en).

## Wave 1 — foundation (two builders in parallel, disjoint files)

### W1-A · Overlays, containers, keyboard, guard (Opus, medium)
Owns: `lib/app/ds/components/bhor_overlays.dart`, `lib/app/ds/foundation/bhor_interaction.dart`, new `lib/app/ds/components/bhor_menu.dart`, `lib/app/ds/components/bhor_guard.dart`, `tool/check_containers.sh` + its CI step, `lib/features/students/widgets/student_keys.dart`, `lib/features/dues/widgets/dues_keys.dart`, `lib/features/search/ui/search_screen.dart` (Esc only), their tests.
1. **Popover placement** (G7): a flipped-above card is bottom-aligned to the anchor (never pinned to the window top); remove the "cramped → full window from top" mode, use max-height + scroll instead; never extend past the window (Help/Diagnostics overflow); horizontal clamp. Anchor resolution must find the real trigger for ⋮/row buttons and the hero link. Unit-test `BhorPopoverPlacement.of` for below / above / short window / right edge.
2. **Container rule** (G1): on desktop (`bhorIsWide`) `showBhorSheet` must never render a sheet. It delegates to `showBhorPanel` (`list` → anchored popover, else side panel). Phone is unchanged. Add `BhorPanelKind.choice` (short single-choice lists, e.g. reminder minutes, cut-off day): desktop = anchored popover, or a small dialog when there's no anchor.
3. **`BhorMenu`** (G8): one menu component (`showBhorMenu(context, items: [BhorMenuItem(icon, label, onTap, destructive)])`). No title header and no ✕. Icons on every item. Destructive items red, last, after a divider. Keyboard ↑↓/Enter/Esc.
4. **Esc** (G2): Esc closes only the top-most route/overlay. Page-level Esc handlers (student_keys, dues_keys) must ignore Esc while any popup route is above the page (`ModalRoute.of(context)?.isCurrent`). Search: Esc with text clears; Esc with empty text closes.
5. **Unsaved guard** (G3): `BhorGuard` — `showBhorPanel(..., dirty: ValueListenable<bool>?)`. Plus a `BhorDirtyScope` widget for full pages. Closing via Esc/✕/scrim/back while dirty asks `showBhorConfirm` "বাতিল করবেন? / Discard changes?" (Keep editing / Discard).
6. `tool/check_containers.sh` (blocking CI step): features may not call `showBhorSheet` or `showBhorDialog` directly (use `showBhorPanel` / `showBhorConfirm` / `showBhorMenu`). Print an allowlist of current offenders to a file `tool/containers_allowlist.txt` so wave 2 can burn it down to zero.

### W1-B · Tokens, controls, templates, platform (Opus, medium)
Owns: `bhor_tokens.dart`, `bhor_theme.dart`, `bhor_choice.dart`, `bhor_display.dart`, `bhor_text_field.dart`, `bhor_select.dart`, `bhor_pickers.dart`, `bhor_navigation.dart`, `bhor_scaffold.dart`, `lib/app/shell/**`, `lib/app/router.dart`, `tool/platform_patches/apply.py`, the gallery, their tests.
1. **Desktop scale** (A9/L4): `BhorType` gains a desktop step at ≥ 1200 (display 28, title 22, heading 18, body 15, stat 30). Phone is unchanged.
2. **No outline rings** (L1, R3, C2): segmented thumb, radio cards, choice chips, the attendance-toggle thumb and the calendar's today marker are filled (no stroke). The keyboard focus ring shows only on keyboard focus (`FocusHighlightMode.traditional`), never on click.
3. **One field style** (L2, B6, R2): soft fill everywhere; remove white+outline variants (date/time fields, select-as-text). Read-only = text3 text + lock icon, no fill change.
4. **`BhorTabs`** (B3): a segmented-style tab bar for detail tabs. **`BhorEmptyState`** (L3): glyph in a tinted circle, title, one-line body, optional action; sizes compact/regular/page. **`BhorMasonry`**: content-sized columns (1/2/3 by width) for dashboards. **One selection style** for list cards: accentTint fill + 3 px accent bar; never dimmed text (B2).
5. **Page templates** (`lib/app/shell/templates/`), each with a gallery entry:
   - `BhorDashboardPage`: header (date + greeting + actions), masonry body, max width 1320, centered.
   - `BhorMasterDetailPage`: list 360, detail flex, optional context rail ≥ 1600 only, otherwise passed into the detail as a section.
   - `BhorSettingsPage`: section nav 240, content column max 720, top-aligned, a back crumb for sub-pages.
   - `BhorFocusPage`: keeps the sidebar; slim top bar (back + title + subtitle + actions); content max 880 centered; sticky bottom action bar (summary + primary); Esc = back via `BhorGuard`.
   - Full-screen routes that keep the sidebar must live inside the shell (router change). Roll call and onboarding: roll call moves inside the shell; onboarding stays full screen.
6. **Windows platform** (G5, G6) via `apply.py` runner patches:
   - title bar follows the app theme: MethodChannel `bhor/window` → `setDark(bool)` → `DwmSetWindowAttribute(DWMWA_USE_IMMERSIVE_DARK_MODE)`, called on every theme change;
   - single instance: a named mutex in `main.cpp`; a second launch brings the existing window to front and exits.
7. **Digits** (G9): `BhorDigits` input formatter; fields show locale digits (Bangla when bn) and parse both. Apply it inside `BhorTextField` for `keyboardType` number/phone.

## Wave 2 — features (after wave 1 merges; Sonnet builders, parallel, disjoint folders)
Each one: adopt the wave-1 templates/containers/menu/empty state, remove your entries from `tool/containers_allowlist.txt`, fix every listed finding. No new features.
- **W2-Today** (`features/home`, `features/classes`):
  - T1–T8; masonry dashboard;
  - Recent payments shows 4 + "সব দেখুন";
  - New… › Collect fee / Add student open their panels in place;
  - extra class defaults to the next free slot; the suggestion button is accent, not red;
  - the reschedule time uses the standard time field;
  - week view: padded blocks with a 2-line title, a now-line, sensible hours range, instant popover on click.
- **W2-Batches** (`features/batches`, `features/schedule`, `features/extras` bulk-add + csv import):
  - B1–B11; master-detail template, the rail folded into the overview;
  - `BhorTabs`; no duplicate buttons/routines;
  - Schedule tab action secondary;
  - slot editor: filled day chips, add-day, standard fields;
  - reminder chooser = the same component as Settings;
  - edit panel Save disabled until dirty, Archive in ⋮;
  - bulk add → side panel with a CSV-format explainer before the picker.
- **W2-RollCall** (`features/attendance`): R1–R5; `BhorFocusPage` with a sticky bar (live counts + Save); one banner; date nav next to the date; Leave reachable on wide rows.
- **W2-Students** (`features/students`):
  - S1–S5; profile detail at ≥ 440 width, no clipping (tags wrap);
  - filter row = chips of one height (batch as a chip-menu);
  - drop the dead Due column (or show the real due);
  - clear-filters action;
  - enrol lists only other batches (empty state otherwise);
  - Add student is a panel everywhere.
- **W2-Fees** (`features/dues`, `features/payments`, `features/extras` other income):
  - F1–F7; zero-dues tiles; one header-action set (Collect fee primary, ⋮ with Other income / Export CSV);
  - designed receipt card with a quiet Delete (in ⋮, confirm);
  - picker shows batch + due level + amount;
  - payment form chip layout; other income → side panel.
- **W2-More** (`features/settings`, `features/backup`, `features/extras` holiday, `features/search`):
  - M1–M6 + G4; `BhorSettingsPage` for every section;
  - Holidays as its own section;
  - Backup = one UI inside settings (primary "create backup" card, then the rest);
  - template editor with variable chips (no raw `{}` shown), editor | preview side by side on desktop;
  - search = palette overlay over the app (Ctrl K / sidebar field), no per-page 🔍 buttons (Today, Batches, Fees and More drop theirs; owners: their wave-2 builder removes the button, W2-More owns the palette).

## Done = 
CI green per PR; containers allowlist empty; Chair re-walks the full coverage list of doc 15 on the real Windows build (1536/1214/910, light/dark, bn/en) and phone web at 390; naive tester; Judge.
