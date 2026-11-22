// Page templates (docs/council/16-windows-rebuild-plan.md W1-B 5). Every
// screen mounts in one of these four, so width, alignment and chrome are the
// same app-wide (review root cause 2):
// - BhorDashboardPage: Today (header + masonry, max 1320, centred).
// - BhorMasterDetailPage: Batches / Students / Fees (list 360 | detail; the
//   context rail is a column only >= 1600, folded into the detail otherwise).
// - BhorSettingsPage: More sections (nav 240 | content max 720, back crumb).
// - BhorFocusPage: roll call (inside the shell: sidebar stays; slim top bar,
//   content max 880, sticky bottom bar, Esc = back).
// Import: `import 'package:attendance_alamin/app/shell/templates/templates.dart';`

export 'package:attendance_alamin/app/shell/templates/bhor_dashboard_page.dart';
export 'package:attendance_alamin/app/shell/templates/bhor_focus_page.dart';
export 'package:attendance_alamin/app/shell/templates/bhor_master_detail_page.dart';
export 'package:attendance_alamin/app/shell/templates/bhor_settings_page.dart';
