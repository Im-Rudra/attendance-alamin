# "ভোর" (Bhor) — fully custom design system (user-approved direction, 2026-11-21)

Replaces the Material look and the earlier Aurora Ink visuals. Nothing visible may come from Material: no Material buttons, text fields, cards, chips, app bars, nav bars/rails, dialogs, bottom sheets, snackbars, date/time pickers, switches, checkboxes, radios, list tiles, tab bars, ink ripples or Material elevation shadows. Flutter's widgets layer (layout, text, gestures, scrolling, EditableText, Overlay, Navigator, localisation) is fine.

## Character
Calm, editorial, premium. Hairline borders instead of shadows. One signature indigo. Subtle gradient in exactly three places: a faint page wash (top-left), the hero card, the primary button. Press feedback = scale 0.98 + slight darken (no ripple). Motion 120–200 ms, ease-out.

## Tokens
| Token | Light | Dark |
|---|---|---|
| bg | #F6F5F1 | #0D0E12 |
| bgWash | radial 90%×40% at top-left, accent @7% → 0 | accent @10% → 0 |
| surface | #FFFFFF | #16181E |
| surface2 (sunken / tracks / segmented bg) | #F1EFEA | #1D2028 |
| line (hairline 1px) | #E5E2DA | #272A34 |
| text | #17181C | #ECEDF1 |
| text2 | #5E616A | #A3A7B3 |
| text3 (hints/meta) | #8C8F98 | #7A7F8C |
| accent | #5B4FE0 | #8B83FF |
| accent2 (button gradient top) | #6E63EE | #9C95FF |
| accentTint (selected bg) | #EEECFC | accent @14% |
| accentLine | #CBC6F6 | accent @35% |
| focusRing | accent @14%, 4px spread | accent @18% |
| ok / okBg | #0F7A58 / #E2F3EC | #4CC79A / @13% |
| danger / dangerBg | #C23A52 / #FBE9EC | #F07C8F / @12% |
| hero gradient | 140°: #4C42C9 → #6A5BE0 | #3B3399 → #5A4BC4 |
| absent (attendance) | #3F4660 fill, white text | same |
| late | #DDF0F4 / #0E5566 | tinted cyan @15% / #7FD3E6 |

Dues severity keeps the existing honey→rose escalation hues and the solid overdue #B4194A (white text), but as compact tags (radius 6), and a thin 5px 10-segment escalation bar with today ringed. Re-verify WCAG AA for all text pairs in a contrast test.

## Type (Hind Siliguri; tabular numbers for money/stats)
display 24/700 (-0.3 tracking) · title 18/700 · heading 15/600 · body 14/400 · bodyStrong 14/600 · label 12.5/600 · meta 12/400 · caption 11/400 · stat 22/700. Line height 1.45 (Bangla needs it). Money: "৳" + thin space, ৳ at 70% size, text2 colour in stats.

## Spacing / radius / size
4-pt grid: 4, 8, 12, 16, 20, 24, 32, 40. Radius: controls 12, cards 16, hero 18, sheets 20 (top), tags 6, chips 10, avatars 9 (rounded square). Control height 44 (compact 36 on desktop toolbars). Min tap target 44×44 (48 on phone rows).

## Components (lib/app/ds/)
BhorButton (primary / secondary / ghost / danger; sizes md 44, sm 36; icon-only; loading; disabled with reason tooltip on desktop) · BhorTextField (label above, hint, helper, inline error, prefix/suffix, focus ring; built on EditableText) · BhorSelect (custom dropdown on Overlay) · BhorSegmented (sliding thumb) · BhorChip (filter) · BhorTag (status) · BhorSwitch · BhorCheckbox · BhorRadioCard · BhorCard (+ hero variant) · BhorListRow (dense table row with hairline dividers) · BhorSectionHeader · BhorSheet (custom modal bottom sheet, drag handle, safe area, root overlay) · BhorDialog (confirm/destructive) · BhorToast (top/bottom toast with optional action, auto-dismiss) · BhorDatePicker (week starts on Settings day, Bangla digits) · BhorTimePicker (period-first: ভোর/সকাল/দুপুর/বিকাল/সন্ধ্যা/রাত, then hour, then 5-min) · BhorTabs (underline) · BhorBottomNav (phone: flat bar, top hairline, active icon in accent-tint pill) · BhorSidebar (desktop: brand, nav items, badges, collapsible) · BhorHeader (screen title + date + actions; replaces AppBar) · BhorScaffold (page bg + wash + safe areas; replaces Scaffold) · BhorAvatar (rounded square initials) · BhorProgress (bar) · BhorSkeleton · BhorEmptyState · BhorAttendanceToggle (উপস্থিত/অনুপস্থিত/দেরি) · BhorEscalationBar · BhorMoney/StatText · BhorIconButton. Icons: keep the icon font only as glyphs (no Material widgets).

## Enforcement
A CI check fails if `lib/features/**` or `lib/app/**` (outside `lib/app/ds/` internals that legitimately need `package:flutter/material.dart` for nothing visible) uses Material widgets: ElevatedButton, FilledButton, TextButton, OutlinedButton, IconButton, FloatingActionButton, TextField, TextFormField, Card, Chip/FilterChip/ChoiceChip/InputChip, AppBar, NavigationBar, NavigationRail, BottomNavigationBar, Scaffold, AlertDialog, Dialog, showDialog, showModalBottomSheet, SnackBar, ScaffoldMessenger, showDatePicker, showTimePicker, Switch, Checkbox, Radio, ListTile, TabBar, InkWell, Material(, DropdownButton, PopupMenuButton, Tooltip, CircularProgressIndicator, LinearProgressIndicator. The app shell uses WidgetsApp.router (or MaterialApp kept only if strictly needed for localisation delegates — then no Material widgets render).

Mock reference: the Chair's "bhor_custom_design_system_mocks" widget (component sheet, Android Today + roll call, desktop Today with sidebar + 12-column grid).
