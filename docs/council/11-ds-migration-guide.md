# Bhor migration guide (Material / Aurora → ভোর)

## SHELL STEP (done in `ds/shell`; kept for the record)
1. **Provide BhorTheme at the app root** (and in `pumpApp`/`pumpShell` test harnesses) driven by the app's ThemeMode setting — today Bhor components fall back to platform brightness, so the in-app Light/Dark switch doesn't reach them.
2. Replace MaterialApp with WidgetsApp.router (keep l10n delegates); AdaptiveScaffold/nav → BhorScaffold + BhorBottomNav (phone) + BhorSidebar (desktop); `stub_screen.dart`, startup/error/storage-banner screens → Bhor.
3. `lib/app/services/share_service.dart` and `contact_actions.dart` show ScaffoldMessenger SnackBars → BhorToast via an app-level toast host; remove the test-only Scaffold wrappers in payments/home tests.
4. BhorToast: support up to two actions; delete the local two-action toasts (payments `paid_toast.dart`, classes cancel toast) and use the library one.
5. BhorTextField: add `textCapitalization`; BhorHeader: accept a custom title widget; BhorTimePicker: optional title. Re-unify local duplicates (clash cards in attendance/classes, sticky save bars) into `lib/app/ds` if trivial.
6. Today on phones shows the date twice (header subtitle + hero) — show it once (header only).
7. Remove the now-unused Aurora widgets/theme from `lib/app/widgets` + `lib/app/theme` (keep palette/tokens used by Bhor), then make `tool/check_no_material.sh` BLOCKING in ci.yml.

Binding spec: `10-design-system-bhor.md`. Library: `lib/app/ds/` (import only the barrel
`package:attendance_alamin/app/ds/ds.dart`). Live reference: the hidden gallery at
`/more/design-system` (long-press the version row in More › Diagnostics).

## Widget mapping

| Material / Aurora | Bhor |
|---|---|
| `Scaffold` | `BhorScaffold(header:, body:, bottomNav:, sidebar:, floating:)` |
| `AppBar` | `BhorHeader(title:, subtitle:, actions:, large:)` (back button automatic when the route can pop) |
| `NavigationBar` / `BottomNavigationBar` | `BhorBottomNav(items: [BhorNavItem], index:, onTap:)` |
| `NavigationRail` | `BhorSidebar(brand:, items:, index:, onTap:, collapsed:, onToggleCollapsed:)` |
| `ElevatedButton` / `FilledButton` | `BhorButton(label:, onPressed:)` (primary) |
| `OutlinedButton` | `BhorButton(variant: BhorButtonVariant.secondary)` |
| `TextButton` | `BhorButton(variant: BhorButtonVariant.ghost)` |
| destructive button | `BhorButton(variant: BhorButtonVariant.danger)` |
| `IconButton` | `BhorIconButton(icon:, semanticLabel:, onPressed:)` (label is required, doubles as tooltip) |
| `FloatingActionButton` | `BhorScaffold(floating: BhorButton(icon: ..., label: ...))` |
| `TextField` / `TextFormField` | `BhorTextField(label:, hint:, helper:, error:, prefix:, suffix:)` — validate in the screen, pass `error` |
| `DropdownButton` / `PopupMenuButton` (choice) | `BhorSelect<T>(options: [BhorOption], value:, onChanged:)` |
| `SegmentedButton` / Aurora `SegmentedChoice` | `BhorSegmented<T>` |
| `TabBar` | `BhorTabs(tabs:, index:, onChanged:)` + your own `IndexedStack` |
| `FilterChip` / `ChoiceChip` / month chips | `BhorChip(label:, selected:, onSelected:, count:)` |
| status `Chip`, Aurora `StatePill`, `SeverityBadge` | `BhorTag(label:, tone:)` / `BhorTag.severity(level:, label:)` |
| `Switch` / `SwitchListTile` | `BhorSwitch` inside a `BhorListRow(trailing:)` |
| `Checkbox` / `CheckboxListTile` | `BhorCheckbox(label:)` |
| `Radio` / `RadioListTile` | `BhorRadioCard<T>` |
| `Card` / Aurora `GlassCard` | `BhorCard` (`onTap` for tappable) |
| Aurora `HeroCard` | `BhorCard.hero` |
| `ListTile` / Aurora `DenseTable` row | `BhorListRow(leading:, title:, subtitle:, trailing:, onTap:)` inside `BhorCard(padding: EdgeInsets.zero)` |
| Aurora `SectionHeader` | `BhorSectionHeader(title:, count:, actionLabel:, onAction:)` |
| `CircleAvatar` / `InitialsAvatar` | `BhorAvatar(name:, image:)` |
| `LinearProgressIndicator` | `BhorProgress(value:)` |
| `CircularProgressIndicator` | `BhorSpinner` (or `BhorButton(loading: true)`) ; list loading → `BhorSkeleton` |
| Aurora `EmptyState` | `BhorEmptyState(icon:, title:, message:, action:)` |
| roll-call P/A/L toggles | `BhorAttendanceToggle(value: AttendanceKind, onChanged:)` |
| `EscalationBar` (10 segments) | `BhorEscalationBar(day:)` |
| `MoneyText` / `StatTile` | `BhorMoney(amount)` / `BhorStatText(label:, value:)` / `BhorStatText.money(...)` |
| `showModalBottomSheet` | `showBhorSheet<T>(context, title:, builder:)` |
| `showDialog` + `AlertDialog` | `showBhorConfirm(context, title:, message:, confirmLabel:, destructive:)` or `showBhorDialog(builder: (c) => BhorDialog(...))` |
| `ScaffoldMessenger.showSnackBar` | `BhorToast.show(context, message:, actionLabel:, onAction:)` |
| `showDatePicker` / `showAppDatePicker` | `showBhorDatePicker(context, initialDate:, firstDate:, lastDate:, weekStart:)` |
| `showTimePicker` / slot time fields | `showBhorTimePicker(context, initial: minutes)` (returns minutes after midnight) |
| `Tooltip` | `BhorTooltip(message:, child:)` |
| `InkWell` / `GestureDetector` for tappable custom UI | `BhorPressable(onTap:, semanticLabel:, builder: (c, states) => ...)` |
| `Theme.of(context)`, `context.aurora`, `TextTheme` | `context.bhor.colors.*`, `context.bhor.type.*`, `BhorSpace` / `BhorRadius` / `BhorSize` / `BhorMotion` |
| `Icons.x` | unchanged, imported as `import 'package:flutter/material.dart' show Icons;` |

## Screen patterns

- **Scaffold + header.** Every screen returns `BhorScaffold(header: BhorHeader(...), body: ...)`. Top-level tabs use
  `BhorHeader(large: true, subtitle: fmt.weekdayDate(today))`. Actions are `BhorIconButton`s. Embedded detail panes
  (`PaneScope.isEmbedded`) pass `showBack: false`. Do not add a bottom nav / sidebar in screens: the shell owns them.
- **Body.** `ListView(padding: EdgeInsets.all(WindowClass.of(context).gutter))` of `BhorSectionHeader` +
  `BhorCard` groups; 4-pt spacing only (`BhorSpace.s8/s12/s16/s24`). Lists of people/rows are one `BhorCard` with
  `padding: EdgeInsets.zero` holding `BhorListRow`s (the last one `divider: false`).
- **Forms.** Full-screen routes keep their root-navigator placement. Fields are `BhorTextField`/`BhorSelect`
  stacked with `BhorSpace.s16`; the save button is `BhorButton(expand: true)` at the bottom (or a header action on
  desktop). Validation errors go into `error:`; a disabled save button gets `disabledReason:`.
- **Sheets.** Short choices and small forms use `showBhorSheet`; pop with `Navigator.of(ctx).pop(value)`. Long or
  scrolling content returns a `SingleChildScrollView` from the builder.
- **Dialogs.** Only for confirmation: `showBhorConfirm(..., destructive: true)` for deletes.
- **Toasts.** `BhorToast.show` after saves/undoable actions (undo = `actionLabel` + `onAction`; two buttons =
  `actions: [BhorToastAction(...), BhorToastAction(...)]`). The app root hosts toasts (`BhorToastHost`) and the
  shell lifts them above the phone bottom nav (`BhorToastInset`), so screens pass no `bottomOffset`. After an
  async gap use `BhorToast.anchorOf(context)` captured before it.
- **Dates/times.** Read the week start from settings (`SettingKeys.weekStart`) and pass it as `weekStart:`; pass the
  app clock's today as `today:`. Never call `DateTime.now()`.
- **Strings.** Components take already-localised labels; numbers/money/dates are formatted with `context.fmt` (Bangla
  digits) before they reach a component (`BhorMoney` formats itself).

## Rules for migrating builders

1. One screen (or one feature) per PR; screens only — do not edit `lib/app/ds/` (report gaps to the Lead instead).
2. After migration a file has no Material widget and imports `package:flutter/widgets.dart` (plus
   `material.dart show Icons` if it uses icons). `bash tool/check_no_material.sh` must show 0 for your feature.
3. No colour literals, no `Theme.of`, no Aurora widgets (`app/widgets/widgets.dart`) in migrated files.
4. Keep keys, routes, entry signatures and provider wiring unchanged; tests that look for Material types
   (e.g. `find.byType(Scaffold)` in `routes_test.dart`) are updated to the Bhor type in the same PR.
5. Every tappable thing is a Bhor control or `BhorPressable` with a `semanticLabel`; targets ≥ 44 px (48 on phone rows).
6. Screens still pass `testScreenMatrix` (light/dark × bn/en × phone/desktop, no overflow); check Bangla at 1.3× text.
7. `tool/check_no_material.sh` is blocking in CI (0 uses across lib/). The app root is `WidgetsApp.router` +
   `BhorAppRoot` (BhorTheme from the theme setting); the shell is `BhorScaffold` + `BhorBottomNav`/`BhorSidebar`.
   Pages pushed outside the router use `BhorPageRoute`.

## Fluid migration guide (ds/fluid → every screen)

The library and shell now follow `13-fluid-ui-spec.md` (tokens, motion, components) and `12-ux-review.md`
§3 / §4. Every existing API still compiles; screens opt into the fluid behaviour below. One screen (or one
feature) per PR, screens only — the library is done; report gaps to the Lead.

### What is already automatic (no screen change)
- Filled, borderless `BhorTextField` with a floating label (the label now sits **inside** the field; drop any
  extra `Text` label you put above it). `BhorSelect` opens a popover on desktop and a sheet list on phone.
- Press spring, hover shifts, gliding thumbs (segmented, switch, attendance toggle, tabs, bottom nav, sidebar),
  pill chips / tags / toasts, circle avatars, spring sheets with drag-to-dismiss, the floating side panel,
  dialog scale-in, phone page push with parallax, the shell's tab fade-through, reduced-motion fallbacks
  (120 ms fades) via `EffectsMode` / OS "remove animations".
- Radii / heights changed: `BhorRadius.control` 14, `card` 18, `hero` 22, `sheet` 28, `tag` = pill;
  `BhorSize.control` 46, `compact` 38, `field` 56. `BhorRadius.chip` stays 10 (calendar / week cells).

### 1. Icons → Phosphor (`BhorIcons`)
Replace every `Icons.*` with `BhorIcons.*` (Regular; `…Fill` only for active / status) and drop
`import 'package:flutter/material.dart' show Icons;`. Sizes: `BhorIconSize.inline` 16, `chip` 18, `row` 20,
`nav` 24. Mapping is in `lib/app/ds/foundation/bhor_icons.dart` (12-ux-review §1.4 table).
```dart
BhorIconButton(icon: BhorIcons.search, semanticLabel: l10n.commonSearch, variant: BhorButtonVariant.secondary, circle: true, onPressed: open)
BhorButton(label: l10n.payTake, icon: BhorIcons.takeMoney, variant: BhorButtonVariant.tonal, size: BhorButtonSize.sm, onPressed: pay)
```
Tests that find icons switch to the same constant (`find.byIcon(BhorIcons.close)`).

### 2. Edit / create flows → `showBhorPanel` (navigation table, 12-ux-review §3)
Instead of `context.push('/students/new')` / `showBhorSheet` for forms, open the adaptive container. Phone:
bottom sheet (`expand: true` = expanding sheet for long forms). Desktop: floating side panel (`kind: form`)
or centred dialog (`kind: confirm` / `kind: list`). Keep the route for deep links (it can render the same
form), but in-app taps use the panel.
```dart
final bool? saved = await showBhorPanel<bool>(
  context,
  title: l10n.payTitle,
  kind: BhorPanelKind.form,            // payment, student/batch edit, slot editor, other income, filters
  expand: true,                        // phone: opens at 60%, drags to full
  builder: (BuildContext c) => CollectPaymentForm(studentId: id),
  footer: (BuildContext c) => BhorButton(label: l10n.commonSave, expand: true, onPressed: save),
);
// Confirmations / short choices:
showBhorPanel<void>(context, kind: BhorPanelKind.confirm, title: l10n.holidayTitle, builder: ..., footer: ...);
```
Finish a save with the success moment (circle ✓ pops + draws, the panel closes, then a toast):
```dart
await showBhorSuccess<bool>(ctx, result: true, label: l10n.payDone, toast: l10n.paySaved(fmt.money(1000)));
```
Per the §3 table: batch new/edit, slot editor (`width: 560`), student new/edit, collect payment → `form`;
bulk add → `confirm` dialog (`width: 720`); add-student → `list`; other income, waive / fee change,
reschedule / extra class forms, backup export, reminder priming, holidays → `confirm`. Roll call,
onboarding, batch / student detail stay full screen.

### 3. First-load stagger, count-ups, panes
```dart
BhorStaggerScope(                      // once per list; replays only on the first paint
  child: BhorList(children: <Widget>[
    for (int i = 0; i < rows.length; i++)
      BhorStagger(index: i, child: BhorListRow(title: rows[i].name, trailing: BhorMoney(rows[i].due))),
  ]),
)
BhorStatText.money(label: l10n.feesDue, amount: total, countUp: true)   // or BhorStatText.count(...)
BhorCountUp.money(amount: collected, style: b.type.stat, muteSign: true)
BhorProgress(value: collected / expected)                              // fill animates by itself
// Desktop list → detail:
BhorPaneSwitcher(paneKey: selectedId, child: StudentProfile(id: selectedId))
// In-page view toggles (Fees বকেয়া / আদায়, Today day / week):
BhorFadeThrough(child: KeyedSubtree(key: ValueKey<int>(view), child: view == 0 ? dues : collection))
```
Loading: show `BhorSkeleton` blocks with the real row heights for queries > 150 ms (it shimmers; static when
motion is reduced).

### 4. Surfaces and controls
- Lists: wrap rows in `BhorList` (surface card r20, line edge, inset hairlines; the last hairline drops).
- Hero (next class) is the only gradient: `BhorCard.hero` with a `BhorButton(variant: BhorButtonVariant.hero, expand: true)`.
- Today greeting: `BhorHeader(overline: fmt.weekdayDate(today), title: greeting, large: true, actions: [round search])`.
- Row actions use `BhorButtonVariant.tonal` / `secondary` at `BhorButtonSize.sm`; one primary per view;
  sticky CTA: `BhorActionBar(label:, onPressed:, loading:, done:)` (lg 52).
- Roll call rows on phone: `BhorAttendanceToggle(value: v, iconOnly: true, onChanged: f)`; labelled
  (default) on wide rows; live counts as `BhorTag` with `BhorTone.ok / absent / late`.
- New tones: `BhorTone.warn` (partial), `BhorTone.overdue`. Numbers: `BhorStepper` for month counts.
- Pushed pages outside the router: `BhorPageRoute` (parallax on phone, cross-fade on desktop).
- Never hand-roll `AnimatedContainer` timings: use `BhorMotion.of(context, BhorMotion.fast)` and
  `BhorMotion.curveOf(context, BhorMotion.spring)` so reduced motion works. Never put `BhorMotion.spring`
  (it overshoots) on opacity, colour or a size that animates towards 0.

### 5. Windows rebuild, wave 1 (W1-B): what wave 2 adopts
See `16-windows-rebuild-plan.md`. Use these and nothing hand-rolled:
- **Templates** (`lib/app/shell/templates/templates.dart`): `BhorDashboardPage(overline:, title:, actions:, hero:, children:)`
  (masonry, max 1320); `BhorMasterDetailPage(master:, detail:, emptyDetail:, rail:)` (list 360; the rail is a
  column only on windows >= 1600, else read it in the detail with `BhorMasterDetailPage.foldedRailOf(context)`
  and show it as a section); `BhorSettingsPage(sections:, selected:, onSelect:, title:, crumb:, onCrumb:, child:)`
  (nav 240, content max 720, back crumb on sub-pages); `BhorFocusPage(title:, subtitle:, actions:, summary:,
  primary:, body:)` (inside the shell, content max 880, sticky bar, Esc = back through `Navigator.maybePop`).
- **Selection style** (one for every list card / row): `BhorCard(selected: true, ...)` or
  `BhorListRow(selected: true, ...)`: the accent-tint fill + a 3 px accent bar, text in its normal colours.
  Custom tiles: `BhorSelectable(selected:, child:)` or `BhorSelection.fillOn(c, c.surface)` + `BhorSelectionBar`.
  Never paint a tint over the content (it dims the text) and never use a solid accent fill for a selected card.
- **Tabs**: `BhorTabs(tabs:, index:, onChanged:)` is the segmented look now (soft track, filled thumb);
  `expand: true` shares the width.
- **Empty states**: `BhorEmptyState(size: BhorEmptySize.compact | regular | page, icon:, title:, message:, action:)`.
- **Dashboards**: `BhorMasonry(children: cards)`: content-sized cards in 1 / 2 / 3 columns, never equal heights.
- **Fields**: one soft style. Date / time / chosen-elsewhere values use `BhorPickerField(label:, value:, icon:,
  onTap: (anchorCtx) => ...)`; never a white or outlined box. Read-only: `BhorTextField(readOnly: true)`
  (text3 + lock). Number / phone fields show Bangla digits in bn automatically; read them with
  `BhorDigits.parseInt(text)` (both digit sets).
- **No rings on selected states**: segmented, radio cards, chips, the attendance thumb and the calendar
  today cell are filled; the focus ring is keyboard-only (`BhorKeyboardFocusMode` at the app root).
- **Type**: windows >= 1200 get the desktop step (`BhorType.desktop`: display 28, title 22, heading 18,
  body 15, stat 30) through `context.bhor`; never hard-code font sizes to "fix" desktop.
