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
