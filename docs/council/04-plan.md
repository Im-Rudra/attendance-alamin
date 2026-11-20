# Phase 3 — Build Plan (Tech Lead)

> Binding inputs, in priority order when they conflict: `00-contract.md` > `01-product.md` > `02-architecture.md` > `03-ux.md`. This plan turns them into an executable, compile-safe sequence. Names and signatures written here are **verbatim contracts**: builders code against them without a compiler. A builder who finds a contract that cannot compile against the real package API fixes it minimally, lists the change under **"Contract deviations"** in the PR description, and the Lead updates this file before the next milestone.

---

## 0. Operating model

- **Roles.** *Lead/Integrator* owns `main`, the shared files in §3, merges and milestone gates. *Builders* own one module each (ids like `M4-B`).
- **Branches/PRs.** One branch per module: `m<N>/<module-id-lowercase>` (e.g. `m2/m2-a-dues`). Push early, open a PR to `main`; `ci.yml` runs on every PR push. Read failures with `gh run view <id> --log-failed`; download generated code with `gh run download <id> -n generated-sources`.
- **Independence rule.** A module compiles against `main` *as of its milestone start* plus this plan. Modules in the same milestone never import each other's new files. The only exception is a declared **stacked** pair (merged in the stated order).
- **Stubs make features independent.** In M5 the Shell module creates every route's screen class and every feature's `*_entry.dart` file with the final signatures and placeholder bodies. Later feature modules *replace the bodies* of the files they own. Feature A can call feature B's entry function before B is built.
- **Milestone gate.** All PRs merged in order → `main` CI fully green (all jobs listed in §4 for that milestone) → evaluation panel (§7) passes → next milestone.
- **No new packages.** `pubspec.yaml` is frozen after M0 (Lead only). No `dart:io` in shared code (web). No codegen beyond drift + gen-l10n.
- **Handback.** A builder hands back only with a green PR run, the self-checked §6 checklist, the file list, and any contract deviations.

---

## 1. Contradictions found and how they are resolved

| # | Topic | Resolution (one line, citing both places) |
|---|---|---|
| 1 | Tab count | UX §1 (5 tabs incl. বেতন/Fees) vs Arch §1.4 (4 tabs): **5 branches** — IA is UX-owned and Product M3/F10 needs dues ≤2 taps; Arch's mechanism (`StatefulShellRoute.indexedStack`, path params) is unchanged. |
| 2 | Reminder horizon | Product §3.11 (7 days) vs Arch §0/§4B (14 days): **7 days**, `maxCount 200`; Home hint when < 3 days remain stays. |
| 3 | Notification text | Product §3.11 vs UX §7: **Product** (title `{subject} · {batch}`, body `{start}–{end} ক্লাস — {N} মিনিট পর` + suffixes); UX's "হাজিরা নিন" action button is kept. |
| 4 | Per-batch reminder "Off" | Product §3.11 has "বন্ধ" but Arch §3.2 (`0..720`, 0 = at start): **`reminder_lead_min = 0` means Off**, `NULL` = default; no "at start" option exists in Product. |
| 5 | Free-slot suggestions | Product §3.10 (same date, 5-min steps, earlier + later, 06:00–23:00) vs Arch §4A (15-min spiral, 7 days, 360/1320): **Product**; `day_window_end_min` default **1380**. |
| 6 | Ad-hoc roll call time | Product §3.6 (prefill batch's most common slot) vs Arch §3.2a (now rounded): **Product**; fallback when the batch has no slots = now rounded down to 15 min, 60-min duration. |
| 7 | Severity model | Product §3.5 (6 levels) vs Arch §4 (`warning(day 1..10)`): engine returns **both** `dayInDue` (1..10) and `DueLevel`; the 10-segment bar uses the day, badges use the level. |
| 8 | Dues sort | Product §3.5 vs Arch §4.8 / UX §2d: **Product** — level desc → open due months desc → total desc → name. |
| 9 | Payment = record + allocations | Product §3.4 vs Arch §3.2 (`payments` row per month): rows stay one-per-month (= allocation) and gain **`receipt_id TEXT NOT NULL`** grouping one record. |
| 10 | Fee-override history | Product §3.1 (override has effective-from month) vs Arch §3.2 (`enrollments.fee_override` single value): new table **`enrollment_fees`** (like `batch_fees`, `amount NULL` = override cleared); `fee_override` column dropped. |
| 11 | Enrollment dates | Product §3.6/F4 (join date, leave date drive roll-call listing) vs Arch §3.2 (months only): add **`join_date TEXT NOT NULL`, `end_date TEXT NULL`** to `enrollments`. |
| 12 | Leave status | Product F21/§3.6 vs Arch CHECK `('P','A','L')`: CHECK becomes **`('P','A','L','E')`**, `E` = ছুটি. |
| 13 | Custom payment methods | Product §3.12 vs Arch `method` CHECK: CHECK allows built-ins **or `custom:<label>`** (label ≤ 20 chars). |
| 14 | Other income (F22) | Product F22 needs storage, Arch has none: add synced table **`other_income`** in schema v1 (avoids a v2 migration). |
| 15 | Safety copies | Product §4 (3) vs Arch §3.3 (5): **3**. |
| 16 | Backup file name | Product §4 / Arch §3.4 / UX §2f differ: **`coaching-backup-YYYY-MM-DD-HHmm.ambackup`** (Product name, Arch format/extension). |
| 17 | Change-summary samples | Product §4 (3) vs Arch §3.5 (5): **3**. |
| 18 | LWW tie-break | Product §4 (updatedAt, then device) vs Arch §3.5 (updated_at, rev, device_id): **(updated_at, device_id, rev)** lexicographic. |
| 19 | Settings list | Product §3.12 owns the list; Arch §3.8 adds hidden keys; UX §3a adds rows: use Product's list + Arch's hidden keys (`day_window_*`, `center_utc_offset_min`) + UX "কম ইফেক্ট" (device). Dropped (not in Product): bKash/Nagad numbers, greeting, default billing type, default payment method. |
| 20 | Wording | Product glossary §5 wins over UX: মাফ (not মওকুফ), আগামী (not "এখনো সময় আছে"), ছেড়ে গেছে (not চলে গেছে), billing type texts "অগ্রিম (মাসের শুরুতে)" / "মাস শেষে (পরের মাসের শুরুতে)", class reminder = "ক্লাস রিমাইন্ডার". |
| 21 | Message templates | Product §5 (one reminder + one receipt template) vs UX §7 (gentle/firm): **Product**. Defaults live in Dart (`core/templates/`), not ARB, because `{placeholders}` would be parsed by gen-l10n. |
| 22 | Day-period words | Product §5 (ভোর 4–6, সকাল 6–12, দুপুর 12–15, বিকাল 15–18, সন্ধ্যা 18–20, রাত 20–4) vs UX §2g picker (5 periods, সকাল from 5): **Product bands** for display and the picker (6 segments). |
| 23 | Range prefixes | Scenario 17 ("সকাল ১১:০০–দুপুর ১২:০০") vs Scenario 25 ("বিকাল ৫:০০–৬:০০" for 17:00–18:00) are mutually inconsistent: each end takes **its own clock time's period**, prefix shown once when equal; Scenario 25 is read as "বিকাল ৫:০০–সন্ধ্যা ৬:০০". |
| 24 | Month lists | Product §5 example ("অক্টোবর, নভেম্বর ২০২৬") vs Scenarios 5/14 (no year): year printed **only when it differs from today's year**, once per year group. |
| 25 | Month/weekday spellings | Arch §2 says `AppFormat` is pure Dart *and* reads ARB keys (impossible): spellings live in pure-Dart `core/format/lexicon.dart` (Product-owned text), no ARB month keys. |
| 26 | Permission timing | Product §3.11 (first save of a batch with a slot) vs Arch §4B (first enable / reminder settings): priming shows **after the first save of a batch with ≥1 slot** (= onboarding step 4) and when the switch is turned on; never on cold start. |
| 27 | Center name in first run | Product §3.12 ("asked in first-run") missing from UX §2a: optional field on onboarding step 1. |
| 28 | Radii | UX §4 Aurora list (cards 20, hero 24, sheets 24, dense 16, buttons pill) vs UX §4 "Spacing" list (cards 12, buttons 12): **Aurora values**; chips 8, FAB 16. |
| 29 | Absence alerts | UX §3b adds "< 75% this month"; Product F16 is 3 consecutive held sessions only: **Product**. |
| 30 | Theme extensions | Arch §4C (3 extensions) vs UX §4 (`AuroraTokens`): **4 extensions** — `AuroraTokens`, `AppGradients`, `SeverityColors`, `AttendanceColors`. |
| 31 | ARB location | Arch §2 (`lib/l10n/arb/*.arb` committed) vs parallel builders: per-module **fragments** committed under `lib/l10n/fragments/`, merged into `lib/l10n/arb/` by CI (gitignored). `check_arb_keys.dart` becomes `tool/merge_arb.py`. |
| 32 | Cross-feature calls | Arch §5 (only router or `app/widgets`) is too narrow for shared sheets: each feature's **`<feature>_entry.dart`** is its public surface and may be imported by other features. Nothing else may be. |
| 33 | Windows min size | UX §3b (960×600 enforced) vs Arch §1.2 (no `window_manager`): enforced by a **runner patch** (`WM_GETMINMAXINFO`) in `apply.py`. |
| 34 | Missing setting keys | Product §3.12 week start, cutoff day, payment methods, backup reminder, device name are absent from Arch §3.8: added to the registry (§2.9). |
| 35 | Payment sheet | UX §2c (amount = fee × chips, "extra as advance?" prompt) vs Product §3.4 (prefill oldest open month, auto-allocate oldest-first): Product's algorithm; UX chips are the manual "মাস ভাগ" view; the advance prompt shows when allocation reaches beyond the selected chips. |
| 36 | App display name | Arch §4B expects a product name that Product never defines: **`হাজিরা খাতা` / `Hajira Khata`** (label only; package/appId/AUMID never change). User may rename before release. |

---

## 2. Global conventions

### 2.1 Versions (from Arch §1, verbatim)
Flutter **3.47.9 stable** (Dart 3.13.7) via `subosito/flutter-action@v2`. `environment: sdk: ^3.13.0, flutter: ">=3.47.0"`. Dependencies exactly as Arch §1.2 (`flutter_riverpod ^3.5.0`, `go_router ^18.1.4`, `drift 2.35.4` exact, `drift_flutter ^0.3.1`, `path_provider ^2.1.6`, `uuid ^4.6.0`, `archive ^4.7.1`, `crypto ^3.0.8`, `file_picker ^13.4.0`, `share_plus ^13.3.1`, `url_launcher ^6.3.3`, `image_picker ^1.2.4`, `package_info_plus ^10.2.2`, `flutter_local_notifications ^23.0.3`, `timezone ^0.11.2`, `intl: any`; dev: `flutter_lints ^6.0.0`, `drift_dev 2.35.3`, `build_runner ^2.17.1`). Package `attendance_alamin`, org `com.imrudra`. Fallback for risk 8: `flutter_local_notifications 22.3.3` (Lead decides).

### 2.2 Folder tree (all paths fixed)
```
.github/workflows/  ci.yml bootstrap.yml commit-generated.yml keystore.yml pages.yml release.yml
tool/  ci_prepare.sh merge_arb.py fetch_web_assets.sh fetch_fonts.sh fonts.sha256 check_domain_purity.sh
       check_schema_dump.sh platform_patches/apply.py
assets/fonts/hind_siliguri/  HindSiliguri-{Regular,Medium,SemiBold,Bold}.ttf  OFL.txt
drift_schemas/drift_schema_v1.json          (committed by commit-generated.yml)
lib/main.dart
lib/app/  app.dart app_info.dart bootstrap.dart router.dart routes.dart
          theme/ tokens.dart app_theme.dart theme_x.dart extensions/{aurora_tokens,app_gradients,severity_colors,attendance_colors}.dart
          widgets/  (shared presentational widgets, §M4-D)
          shell/    adaptive_scaffold.dart window_class.dart adaptive_detail.dart stub_screen.dart
          l10n/     l10n_x.dart error_text.dart
          providers/ app_prefs_providers.dart core_providers.dart schedule_providers.dart dues_providers.dart
                     attendance_providers.dart async_combine.dart
          services/ contact_actions.dart share_service.dart reminder_bootstrap.dart
lib/core/  time/{local_date,year_month,date_range,clock,center_time}.dart  ids/ids.dart
           errors/{app_exception,error_codes}.dart  format/{lang,lexicon,app_format}.dart
           validation/validators.dart  settings/setting_keys.dart  templates/{template_engine,default_templates}.dart
lib/domain/ models/{enums,subject,batch,schedule,fee_period,student,enrollment,payment,attendance,other_income,drafts}.dart
            dues/{dues_models,dues_engine}.dart   schedule/{schedule_models,occ_id,schedule_engine}.dart
            reminders/{reminder_models,reminder_planner}.dart   attendance_stats/attendance_stats.dart
            sync/{synced_tables,sync_models,snapshot_codec,sync_diff}.dart
lib/data/  infra_providers.dart
           db/ app_database.dart tables/*.dart mappers.dart db_queries.dart sync_stamper.dart migrations.dart
               connection/{open_connection,open_connection_native,open_connection_web,web_storage_report,
                           storage_persist,storage_persist_stub,storage_persist_web}.dart
           repositories/ <x>_repository.dart (interfaces) drift/<x>_repository_drift.dart
                         structure_providers.dart people_providers.dart settings_providers.dart
           backup/{backup_repository,backup_repository_drift,backup_files,backup_providers}.dart
           notifications/{notification_gateway,notification_gateway_io,notification_gateway_web,notification_providers}.dart
lib/features/<f>/ <f>_entry.dart  ui/  widgets/  controllers/
   f ∈ home batches schedule classes students attendance payments dues settings backup search onboarding reminders extras
lib/l10n/fragments/<prefix>.bn.arb <prefix>.en.arb    lib/l10n/arb/ (generated)    lib/l10n/generated/ (generated)
test/  mirrors lib/ + helpers/{pump_app,fixtures}.dart helpers/fakes/*.dart  flutter_test_config.dart
dart_test.yaml  analysis_options.yaml  l10n.yaml  pubspec.yaml  .gitignore
```

### 2.3 Naming
Files `snake_case.dart` named after their main class. Interfaces `XRepository`, drift impl `DriftXRepository`. Providers `xProvider`. Controllers `XController` + immutable `XState`. Screens `XScreen`. Sheets/dialogs are top-level functions `Future<T?> showX(BuildContext context, {…})`. Enum values lowerCamel; DB enum codes are the strings listed in M3-A. Test files `<subject>_test.dart`.

### 2.4 Imports & layering
- **Always `package:attendance_alamin/...`** (lint `always_use_package_imports` on). Relative only in `part` directives.
- `core/`, `domain/`: `dart:*`, `uuid`, `crypto`, `archive`, each other. **No** `package:flutter`, `drift`, `riverpod`, `meta` (meta is not a declared dependency).
- `data/`: core, domain, drift, flutter foundation, plugins. Never `features/` or `app/`.
- `features/`: core, domain, `data/repositories/*_repository.dart` interfaces + `*_providers.dart`, `data/backup/backup_providers.dart`, `data/notifications/notification_providers.dart`, `app/**`, and **other features' `*_entry.dart` only**. Never `data/db/**`.
- `app/` may import everything except `features/*/ui|widgets|controllers` (only `router.dart` imports screens; it imports them through each screen file path listed in M5-A).
- Only `data/notifications/` imports `flutter_local_notifications` / `timezone`. Only `core/time/clock.dart` calls `DateTime.now()`.

### 2.5 Riverpod 3 (hand-written, no codegen)
```dart
// singleton
final subjectsRepositoryProvider = Provider<SubjectsRepository>(
    (ref) => DriftSubjectsRepository(ref.watch(appDatabaseProvider), ref.watch(syncStamperProvider)));
// DB stream
final subjectsProvider = StreamProvider<List<Subject>>((ref) => ref.watch(subjectsRepositoryProvider).watchAll());
final batchProvider = StreamProvider.family<Batch?, String>((ref, id) => ref.watch(batchesRepositoryProvider).watchById(id));
// screen/form controller: arg goes to the constructor, build() has no params
final batchFormControllerProvider =
    NotifierProvider.autoDispose.family<BatchFormController, BatchFormState, String?>(BatchFormController.new);
class BatchFormController extends Notifier<BatchFormState> {
  BatchFormController(this.batchId);
  final String? batchId;
  @override
  BatchFormState build() => BatchFormState.initial();
}
```
Rules: no `StateProvider`/`StateNotifierProvider`/`riverpod/legacy.dart`; base classes are `Notifier`/`AsyncNotifier` (no `AutoDispose*`/`Family*` classes in v3); `Ref` is non-generic; family args are `String`, `LocalDate`, or a Dart **record** (structural equality); check `ref.mounted` after every `await`; read async values with `.value` (nullable) / `.when(...)`, never `valueOrNull`; combine several `AsyncValue`s only via `app/providers/async_combine.dart`; `ProviderScope`/`ProviderContainer` use `retry: (_, __) => null`. The `Override` type comes from `package:flutter_riverpod/misc.dart`.

### 2.6 Repositories & streams
- Interfaces return **domain models only** (`lib/domain/models`), never drift rows or companions.
- Reads: `Stream<T> watchX(...)` (drift `.watch()` mapped), one-shots `Future<T> getX(...)`. Multi-table reads use `db.watchComposite(tables, loader)` (M3-A) — **no SQL joins in v1**; load small tables and combine in Dart.
- Writes: `Future<void>` / `Future<String id>`, each in `db.transaction`, stamping sync columns through `SyncStamper` (insert: `createdAt = updatedAt = now`, `rev = 1`; update/soft-delete: `updatedAt = stamper.nextUpdatedAt(old.updatedAt)`, `rev = old.rev + 1`, `deviceId`). Never hard-delete (sole exception: safety-copy restore, M4-C). All reads filter `deletedAt IS NULL`.
- Validation (`core/validation`) and schedule clash checks run **inside repositories**; UI also pre-checks for live feedback.

### 2.7 Errors
`core/errors/app_exception.dart` (abstract, **not sealed** — subclasses live in other libraries). Repositories throw `AppException` subclasses for expected failures; unexpected errors propagate. Controllers wrap writes in `try { … } on AppException catch (e) { … }` (or `AsyncValue.guard`) and show `errorText(context.l10n, e)` in a snackbar or inline. Error codes are the closed list in `ErrorCodes` (M1-A); each has an `err<Code>` ARB key (M3-C). No technical text on screen (UX §3).

### 2.8 Localisation
- **Every user-visible string** comes from ARB in **both bn and en** — including semantics labels, tooltips, snackbars, notification texts and share texts' fixed parts. Exceptions: Product's editable templates (Dart defaults, §1 #21) and lexicon spellings (§1 #25).
- Fragments: `lib/l10n/fragments/<prefix>.bn.arb` + `<prefix>.en.arb`, owned by one module each (§3). Key = `<prefix>` + `UpperCamelRest` (e.g. `rollSaveButton`), must match `^<prefix>[A-Z][A-Za-z0-9]*$`. bn fragment carries `@key` with `description` and `placeholders` (every placeholder `"type": "String"`, ASCII camelCase name); en uses the same placeholder names. No ICU plural/select, no literal `{`/`}` other than placeholders. Numbers/dates/money are pre-formatted with `context.fmt`.
- `tool/merge_arb.py` merges fragments into `lib/l10n/arb/app_bn.arb` (template, `@@locale: bn`) and `app_en.arb`, failing on: duplicate keys, wrong prefix, bn/en key-set mismatch, missing `@key.description`, placeholder mismatch, invalid JSON.
- Access: `context.l10n` (`AppLocalizations`, `nullable-getter: false`) and `context.fmt` (`AppFormat` for the current locale). Non-widget code (notifications) uses `lookupAppLocalizations(Locale(lang.code))`.
- Prefix owners: `common nav err a11y` M3-C · `ui` M4-D · `shell` M5-A · `sched` M6-A · `cls` M6-B · `batch` M6-C · `stu` M6-D · `set` M6-E · `roll` M7-A · `pay` M7-B · `dues` `coll` M7-C · `today` M8-A · `search` M8-B · `onb` M8-C · `remind` M8-D · `backup` M9-A · `extra` M9-B. Need a `common*` key you don't own? Ask the Lead (M3-C list below is meant to be complete).

### 2.9 Money, time, ids, settings
- **Money: `int` whole taka** everywhere (DB, domain, UI state). Range 0..1,000,000. Display only via `fmt.money()` (lakh grouping, `৳` prefix).
- **Dates:** `LocalDate` (center wall-clock date); DB `TEXT 'YYYY-MM-DD'`. **Months:** `YearMonth`; DB `INTEGER yyyymm`. **Times of day:** `int` minutes 0..1440. **Instants:** `int` UTC epoch ms in DB, `DateTime` (UTC) only in `Clock`, `CenterTime` and the reminder planner/gateway. Center offset fixed **UTC+6** (`CenterTime.dhaka`), Arch §3.1. `today` always comes from `todayProvider`.
- **Ids:** `Ids.v4()` for ordinary rows; deterministic `Ids.*` helpers (M1-A) for natural keys and occurrence-derived rows; settings rows use the key as id.
- **Settings:** only through `SettingKeys` (M1-A) + `SettingsRepository` (M4-C); dynamic device keys (drafts, per-student last method, reminded-today log, dismissed alerts, pane widths) through `LocalMetaRepository` with the key formats in M4-C.

### 2.10 Theme access (no literal colours outside `lib/app/theme/`)
```dart
context.aurora      // AuroraTokens: bg, glass, glassNav, glassNoBlur, surfaceDense, surfaceSolid, hairline, topHighlight,
                    // track, scrim, textPrimary, textSecondary, textDisabled, accent, onAccent, accentContainer,
                    // onAccentContainer, avatarBg, avatarText, statePillBg, statePillText, error, errorContainer,
                    // onErrorContainer, info, infoContainer, grainOpacity
context.gradients   // AppGradients: meshA, meshB, meshC (RadialGradient), hero (List<Gradient> + base Color)
context.severity    // SeverityColors: hue(DueLevel), badgeFill(DueLevel), badgeText(DueLevel), badgeBorder(DueLevel)?,
                    // segment(int day1to10), paid/advance/waived/notDue fill+text
context.attendance  // AttendanceColors: fill(AttendanceStatus), text(AttendanceStatus), border(AttendanceStatus)?
EffectsMode.reducedOf(context)  // bool, reduced effects (UX §4 rule 5)
```
CI greps `Color(0x`, `Color.fromARGB`, `Color.fromRGBO` and `Colors\.(?!transparent)` outside `lib/app/theme/`.

### 2.11 Test helpers (M5-B owns; everyone uses)
```dart
enum TestViewport { phone(Size(360, 640)), desktop(Size(1280, 800)); const TestViewport(this.size); final Size size; }
Future<void> pumpApp(WidgetTester tester, Widget child, {
  ThemeMode themeMode = ThemeMode.light, Lang lang = Lang.bn, TestViewport viewport = TestViewport.phone,
  List<Override> overrides = const [], bool reducedEffects = true, LocalDate? today});
/// 8 cases: {light, dark} × {bn, en} × {phone, desktop}; fails on any exception incl. RenderFlex overflow.
void testScreenMatrix(String name, Widget Function() build, {
  List<Override> Function()? overrides, Future<void> Function(WidgetTester tester)? verify, bool phoneOnly = false});
ProviderContainer makeContainer({List<Override> overrides = const [], DateTime? nowUtc}); // addTearDown(dispose)
```
Widget tests use **fake repositories** (`test/helpers/fakes/`, M4-A/B/C), not drift, to avoid pending-timer flakiness. Repository tests use `AppDatabase(NativeDatabase.memory())`.

---

## 3. Shared files & ownership

| File(s) | Owner | Others |
|---|---|---|
| `pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml`, `.gitignore`, `dart_test.yaml`, `.github/workflows/*`, `tool/*` | M0 → Lead | request changes in PR text |
| ARB | each module's own fragment pair (§2.8) | never edit another fragment |
| `lib/app/router.dart`, `routes.dart` | M5-A, then **frozen** | new route = Lead amendment |
| `lib/features/<f>/<f>_entry.dart` and screen files | stub by M5-A; body owned by the feature module | signatures frozen |
| `lib/app/widgets/**` | M4-D | features keep private widgets in their own `widgets/`; promotion to shared = Lead |
| `lib/data/repositories/*_providers.dart` | M4-A / M4-B / M4-C (one file each) | — |
| `lib/app/providers/**` | M5-A (`app_prefs_providers`) / M5-B (rest) | — |
| `lib/app/services/reminder_bootstrap.dart` | stub M5-A → body M8-D | — |
| `lib/main.dart` | M0-A hello app → replaced by M5-A | — |
| `test/helpers/pump_app.dart`, `fixtures.dart`, `flutter_test_config.dart` | M5-B | — |

---

## 4. CI feedback loop

`tool/ci_prepare.sh` (every job, bash; on Windows `shell: bash`): `python3||python tool/merge_arb.py` → `flutter pub get` → `flutter gen-l10n` → `dart run build_runner build --delete-conflicting-outputs`. Merge runs **before** `pub get` because `generate: true` may trigger gen-l10n.

`ci.yml` triggers: `push`, `pull_request`, `workflow_dispatch` (needed: commits pushed by `GITHUB_TOKEN` from bootstrap/commit-generated do not trigger workflows).

| Job | Runs | From |
|---|---|---|
| `fast` (ubuntu) | `merge_arb.py`, `pub get`, `flutter test test/core test/domain` (no codegen), `check_domain_purity.sh` | M1 |
| `check` (ubuntu) | prepare; purity; `sha256sum -c tool/fonts.sha256`; `apply.py --verify`; `check_schema_dump.sh` (warn if no committed dump, fail on diff); `flutter analyze --no-fatal-infos`; `flutter test --coverage --exclude-tags screenshot`; upload `generated-sources` (**`if: always()`** after prepare) | M0 |
| `web` (ubuntu, needs check) | prepare; `fetch_web_assets.sh`; build web (Arch §6.2 flags); 404 copy; artifact `web-<sha>` | M0 |
| `android` (ubuntu, needs check) | Java 17; optional keystore; `flutter build apk --release`; artifact | M0 |
| `windows` (windows-latest, needs check) | prepare; build; copy VC runtime DLLs; zip; artifact | M0 |
| `screens` (ubuntu, needs check) | `flutter test --tags screenshot --update-goldens`; artifact `screens-<sha>`; non-blocking until M9 | M5 |

Per milestone, the gate requires: M0 check+web+android+windows · M1/M2 fast+check (+builds) · M3+ all jobs · M5+ also `screens` artifact produced · M9 `screens` blocking (exceptions only), `release.yml` dry run.

Builder loop: push → watch PR checks → on red, fix the **first** failing step only, re-push → never stack new code on a red branch.

---

## 5. Milestones and modules

Size: **S** ≤ 300 LOC, **M** 300–900, **L** 900–2000, **XL** > 2000 (code + tests).

### M0 — Bootstrap (2 parallel) → then Lead dispatches `bootstrap.yml`

**M0-A · Scaffold, CI & tooling** — size L — deps: none
- Files: `pubspec.yaml` (Arch §1.2 + fonts block + `flutter: generate: true, uses-material-design: true`), `analysis_options.yaml` (`include: package:flutter_lints/flutter.yaml`; exclude `**/*.g.dart`, `lib/l10n/generated/**`; enable `always_use_package_imports`), `l10n.yaml` (Arch §2), `.gitignore` (+ `lib/l10n/arb/`, `lib/l10n/generated/`, `**/*.g.dart`, `web/sqlite3.wasm`, `web/drift_worker.js`, `android/key.properties`, `*.jks`), `dart_test.yaml` (`tags: {screenshot: {}}`), all `tool/*` except `apply.py`, `.github/workflows/{ci,bootstrap,commit-generated,keystore}.yml`, `lib/app/app_info.dart`, `lib/main.dart` (hello app), `lib/l10n/fragments/common.{bn,en}.arb` (bootstrap keys `commonAppTitle`, `commonHello` only — M3-C extends), `test/smoke_test.dart`.
- Contract:
```dart
// lib/app/app_info.dart
const kAppDisplayNameBn = 'হাজিরা খাতা';
const kAppDisplayNameLatin = 'Hajira Khata';
const kWindowsAumid = 'ImRudra.AttendanceAlamin';
const kWindowsToastGuid = '1e797322-5c87-4fef-8348-609333181532';
```
- `bootstrap.yml` (manual): checkout → flutter 3.47.9 → `python3 tool/merge_arb.py` → `bash tool/fetch_fonts.sh` (download + verify into `assets/fonts/hind_siliguri/`, copy `OFL.txt`) → `flutter create --org com.imrudra --project-name attendance_alamin --platforms=android,windows,web .` → delete `test/widget_test.dart` if it mentions `MyApp` → `python3 tool/platform_patches/apply.py` → `flutter pub get` → commit `android/ windows/ web/ pubspec.lock .metadata assets/fonts/` to `main` (`permissions: contents: write`).
- `commit-generated.yml` (manual): prepare → `dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/` → commit `drift_schemas/`.
- `check_domain_purity.sh`: fails on forbidden imports in `lib/core|lib/domain` (§2.4), `DateTime.now(` outside `lib/core/time/clock.dart`, colour literals outside `lib/app/theme/` (§2.10), `import 'package:attendance_alamin/data/db` under `lib/features/`, `flutter_local_notifications|timezone` outside `lib/data/notifications/`, `dart:io` under `lib/` except `lib/data/db/connection/*_native.dart`.
- Hello app: `MaterialApp` with `fontFamily: 'HindSiliguri'`, bn/en delegates, shows `commonAppTitle`, the sample `০১২৩৪৫৬৭৮৯ ৳১,২০,০০০ ক্ষ ন্ত্র`, and a bn/en toggle.
- Acceptance: after bootstrap, `ci.yml` (dispatched) is green on check+web+android+windows; the web artifact served per Arch §6.4 shows Bangla text in Hind Siliguri; APK installs.
- Tests: smoke test pumps the hello app in bn and en.

**M0-B · Platform patcher** — size M — deps: none (runs after `flutter create`)
- Files: `tool/platform_patches/apply.py` (+ `--verify` exits 1 if any edit would change a file).
- Edits (anchored regex/XML; fail loudly when an anchor is missing; idempotent): Android per Arch §4B (AGP 9.1.1, compileSdk 37, desugaring, multidex, manifest permissions + 3 receivers, release signing from `key.properties` else debug, `android:label="হাজিরা খাতা"`), `res/drawable/ic_stat_class.png` (white glyph on transparent, generated with `zlib`+`struct`, 96×96); Windows `runner/main.cpp` title `L"Hajira Khata"`, initial size 1280×800; `runner/win32_window.cpp` insert `case WM_GETMINMAXINFO:` (min track size 960×600 scaled by `GetDpiForWindow / 96`) before `case WM_DPICHANGED:`; `Runner.rc` ProductName/FileDescription; web `index.html` `<title>`, description, `theme-color #0A0C12`; `manifest.json` name/short_name/colors.
- Acceptance: running twice yields no diff; `--verify` passes on the bootstrapped tree; APK and Windows builds green.

### M1 — Core & domain types (2, **stacked**: M1-A merges first)

**M1-A · Core** — size L — deps: M0
- Files: `lib/core/**` (tree §2.2) + `test/core/**`.
- Contract:
```dart
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);
  final int year; final int month; final int day;
  static LocalDate parse(String iso);            // 'YYYY-MM-DD', FormatException otherwise
  static LocalDate? tryParse(String? iso);
  static LocalDate parseCompact(String yyyymmdd);
  static LocalDate fromEpochDay(int epochDay);
  static LocalDate fromUtc(DateTime utc, int offsetMin);
  int get epochDay; int get isoWeekday;          // Mon=1 … Sat=6, Sun=7
  YearMonth get yearMonth;
  LocalDate addDays(int n); int daysUntil(LocalDate other);
  bool isBefore(LocalDate o); bool isAfter(LocalDate o);
  String toIso(); String toCompact();
  DateTime toUtc(int minutes, int offsetMin);
  // ==, hashCode, compareTo, toString() => toIso()
}
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);
  final int year; final int month;
  static YearMonth fromInt(int yyyymm);
  int toInt(); YearMonth addMonths(int n); int monthsUntil(YearMonth o);
  LocalDate get firstDay; LocalDate get lastDay;
  bool isBefore(YearMonth o); bool isAfter(YearMonth o);
}
class DateRange { const DateRange(this.start, this.end); final LocalDate start, end; // inclusive
  Iterable<LocalDate> get days; bool contains(LocalDate d); }
abstract interface class Clock { DateTime nowUtc(); }
class SystemClock implements Clock { const SystemClock(); }
class FixedClock implements Clock { FixedClock(this.fixedUtc); final DateTime fixedUtc; }
class CenterTime {
  const CenterTime(this.offsetMin); static const dhaka = CenterTime(360); final int offsetMin;
  LocalDate today(Clock clock); int minutesNow(Clock clock);
  DateTime toUtc(LocalDate date, int minutes); LocalDate dateOfEpochMs(int epochMs);
}
abstract final class Ids {
  static const namespace = '6f1c2b7e-1d0a-4c55-9b7e-2a4e1f0c9d31';
  static String v4(); static String v5(String key); static int fnv1a31(String s); // web-safe
  static String batchFee(String batchId, YearMonth m);          // v5('fee:$batchId:${m.toInt()}')
  static String enrollmentFee(String enrollmentId, YearMonth m); // v5('efee:…')
  static String waiver(String enrollmentId, YearMonth m);        // v5('waive:…')
  static String exceptionForOcc(String occ); static String sessionForOcc(String occ);
  static String record(String occ, String studentId);            // v5('att:$occ:$studentId')
}
abstract class AppException implements Exception {
  const AppException(this.code, {this.detail}); final String code; final String? detail; }
final class ValidationException extends AppException {
  const ValidationException(super.code, {this.field, super.detail}); final String? field; }
final class NotFoundException extends AppException { const NotFoundException(super.code, {super.detail}); }
final class ImportException extends AppException { const ImportException(super.code, {super.detail}); }
final class StorageException extends AppException { const StorageException(super.code, {super.detail}); }
abstract final class ErrorCodes { static const nameRequired='nameRequired', nameTooLong='nameTooLong',
  phoneInvalid='phoneInvalid', amountInvalid='amountInvalid', amountTooLarge='amountTooLarge',
  dateInvalid='dateInvalid', dateInFuture='dateInFuture', feeMonthBeforeStart='feeMonthBeforeStart',
  slotTimeInvalid='slotTimeInvalid', slotsEmpty='slotsEmpty', scheduleClash='scheduleClash',
  allocationExceedsRemaining='allocationExceedsRemaining', allocationBeyondHorizon='allocationBeyondHorizon',
  duplicateOpenEnrollment='duplicateOpenEnrollment', notFound='notFound', rollCallFutureDate='rollCallFutureDate',
  batchArchived='batchArchived', photoTooLarge='photoTooLarge', importNotBackup='importNotBackup',
  importNewerSchema='importNewerSchema', importChecksum='importChecksum', importCorrupt='importCorrupt',
  importMissingParent='importMissingParent', storageFailed='storageFailed', unknown='unknown';
  static const all = <String>[/* every code above */]; }
enum Lang { bn, en; String get code => name; static Lang fromCode(String? c) => c == 'en' ? en : bn; }
class AppFormat {
  const AppFormat(this.lang); final Lang lang;
  String digits(String ascii);  static String toAsciiDigits(String s);
  String number(int n);        // lakh grouping: 120000 → ১,২০,০০০ / 1,20,000
  String money(int taka);      // ৳১,৫০০ / ৳1,500
  String percent(int p);       // ৮৫%
  String monthName(int m); String monthShort(int m); String weekdayName(int iso); String weekdayShort(int iso);
  String date(LocalDate d);    // ৫ নভেম্বর ২০২৬ / 5 Nov 2026
  String dateShort(LocalDate d); // ২২ নভে / 22 Nov
  String weekdayDate(LocalDate d); // বৃহস্পতিবার, ১৯ নভেম্বর / Thursday, 19 Nov
  String monthYear(YearMonth ym);  // নভেম্বর ২০২৬
  String monthList(List<YearMonth> months, {required int currentYear, Set<YearMonth> partial = const {}});
  String time(int minutes);    // বিকাল ৪:৩০ / 4:30 PM ; 0 and 1440 → রাত ১২:০০ / 12:00 AM
  String timeRange(int start, int end); // §1 #23; en: "4:00–5:00 PM" or "11:00 AM–12:00 PM"
  String dayPeriod(int minutes);        // bn word per §1 #22; en 'AM'/'PM'
}
abstract final class Lexicon { // exact Product spellings
  static const monthsBn = ['জানুয়ারি','ফেব্রুয়ারি','মার্চ','এপ্রিল','মে','জুন','জুলাই','আগস্ট','সেপ্টেম্বর','অক্টোবর','নভেম্বর','ডিসেম্বর'];
  static const monthsShortBn = ['জানু','ফেব্রু','মার্চ','এপ্রি','মে','জুন','জুলা','আগ','সেপ্টে','অক্টো','নভে','ডিসে'];
  static const weekdaysBn = ['সোমবার','মঙ্গলবার','বুধবার','বৃহস্পতিবার','শুক্রবার','শনিবার','রবিবার']; // ISO 1..7
  static const weekdaysShortBn = ['সোম','মঙ্গল','বুধ','বৃহঃ','শুক্র','শনি','রবি'];
  // + monthsEn, monthsShortEn, weekdaysEn, weekdaysShortEn; periodsBn ভোর/সকাল/দুপুর/বিকাল/সন্ধ্যা/রাত
}
abstract final class Validators {
  static String name(String raw);                 // trim, 1..80 else ValidationException
  static String? phone(String? raw);              // ascii digits, strip +88/spaces/dashes, ^01[3-9]\d{8}$, null if empty
  static int amount(String raw);                  // ascii digits, 0..1_000_000
  static int? intLoose(String raw);
}
enum SettingScope { synced, device }
class SettingKey<T> { const SettingKey(this.id, this.scope, this.defaultValue, this.fromJson, this.toJson);
  final String id; final SettingScope scope; final T defaultValue;
  final T Function(Object? json) fromJson; final Object? Function(T value) toJson; }
abstract final class SettingKeys { // synced
  static const centerName = SettingKey<String>('center_name', SettingScope.synced, '', _str, _id);
  // centerPhone 'center_phone' '' · centerAddress 'center_address' '' · weekStart 'week_start' int 6 (6|7|1)
  // defaultReminderLead 'default_reminder_lead_min' int 15 (1..180) · billingCutoffDay 'billing_cutoff_day' int 15 (1..28)
  // paymentMethods 'payment_methods' String JSON '[]' (hidden built-ins + customs) · reminderTemplateBn/En,
  // receiptTemplateBn/En String '' (= use default) · dayWindowStart 'day_window_start_min' 360 ·
  // dayWindowEnd 'day_window_end_min' 1380 · centerUtcOffset 'center_utc_offset_min' 360
  // device: locale 'locale' 'bn' · themeMode 'theme_mode' 'system' · remindersEnabled bool true ·
  // reducedEffects 'reduced_effects' 'auto'|'on' · backupReminderDays int 7 (0=off) · deviceName '' ·
  // lastExportAt int? null · onboardingDone bool false · lastBillingType 'prepaid' · notifPromptedVersion '' ·
  // exactPromptedVersion '' · remindersPlannedUntil int? null
  static const all = <SettingKey<Object?>>[/* every key */];
}
String fillTemplate(String template, Map<String, String> values); // replaces {key}; unknown left as-is
abstract final class DefaultTemplates { static const reminderBn = '…Product §5 verbatim…', reminderEn = '…',
  receiptBn = '…', receiptEn = '…'; }
```
- Acceptance: lexicon strings equal Product §5; `fmt.timeRange(600, 660)` = `সকাল ১০:০০–১১:০০`, `(660, 720)` = `সকাল ১১:০০–দুপুর ১২:০০`, `(720, 780)` = `দুপুর ১২:০০–১:০০`; `money(120000)` = `৳১,২০,০০০`; `toAsciiDigits('০১৭১২')` = `01712`; `fnv1a31` gives identical results to a reference table (VM) using only 16-bit partial products.
- Tests (≥ 60): date arithmetic across month/year/leap boundaries, isoWeekday for 2026-11-21 (= 6), compact round-trip, CenterTime at UTC 17:59/18:00 boundaries, all format functions bn+en, validators, fillTemplate, ids determinism.

**M1-B · Domain models & engine value types** — size M — deps: M1-A (stacked)
- Files: `lib/domain/models/*.dart`, `lib/domain/{dues/dues_models,schedule/schedule_models,schedule/occ_id,reminders/reminder_models,sync/sync_models,sync/synced_tables}.dart`, tests.
- Contract (all classes immutable, `const` named-param constructors, every field `final`):
```dart
enum BillingType { prepaid, postpaid; static BillingType parse(String s); }
enum StudentStatus { active, left; static StudentStatus parse(String s); }
enum ExceptionKind { cancel, reschedule, extra; static ExceptionKind parse(String s); }
enum AttendanceStatus { present('P'), absent('A'), late('L'), leave('E');
  const AttendanceStatus(this.code); final String code; static AttendanceStatus parse(String c); bool get attended; }
enum OccurrenceKind { regular, rescheduled, extra }
class PaymentMethod { const PaymentMethod(this.code); final String code; // 'cash'…'other' | 'custom:<label>'
  static const cash = PaymentMethod('cash'), bkash = PaymentMethod('bkash'), nagad = PaymentMethod('nagad'),
    rocket = PaymentMethod('rocket'), bank = PaymentMethod('bank'), other = PaymentMethod('other');
  static const builtIns = [cash, bkash, nagad, rocket, bank, other];
  bool get isCustom; String? get customLabel; factory PaymentMethod.custom(String label); }
class Subject { id, name, int sortOrder, String? notes, bool archived }
class Batch { id, subjectId, name, BillingType billingType, int? reminderLeadMin /*null=default, 0=off*/,
  LocalDate? archivedOn, LocalDate createdOn, int sortOrder, String? notes; bool get archived; }
class Slot { id, batchId, int weekday, int startMin, int endMin, LocalDate? validFrom, LocalDate? validTo;
  bool activeOn(LocalDate d); int get durationMin; }
class ScheduleException { id, batchId, ExceptionKind kind, String? slotId, LocalDate? originalDate,
  LocalDate? newDate, int? newStartMin, int? newEndMin, String? note }
class FeePeriod { YearMonth effective; int? amount /* null only for a cleared override */ }
class Student { id, name, String? roll, String? phone, String? guardianName, String? guardianPhone,
  LocalDate admissionDate, StudentStatus status, LocalDate? leftDate, String? notes, bool hasPhoto;
  String? get callNumber /* guardianPhone ?? phone */; }
class Enrollment { id, studentId, batchId, LocalDate joinDate, YearMonth startMonth, YearMonth? endMonth,
  LocalDate? endDate, String? notes; bool coversDate(LocalDate d); }
class Payment { id, receiptId, studentId, enrollmentId, batchId, YearMonth billingMonth, int amount,
  LocalDate paidOn, PaymentMethod method, String? note, bool waived }
class AttendanceSession { id, occ, batchId, String? slotId, LocalDate? originalDate, String? exceptionId,
  LocalDate date, int startMin, int endMin, String? note }
class AttendanceRecord { id, sessionId, batchId, studentId, LocalDate date, AttendanceStatus status }
class OtherIncome { id, String? studentId, String label, int amount, LocalDate paidOn, PaymentMethod method, String? note }
// drafts.dart (repository inputs)
class SlotDraft { String? id, int weekday, int startMin, int endMin }
class BatchDraft { String subjectId, String name, BillingType billingType, int? reminderLeadMin, int monthlyFee,
  YearMonth feeFrom, List<SlotDraft> slots, LocalDate slotsFrom, String? notes }
class StudentDraft { String name, String? roll, String? phone, String? guardianName, String? guardianPhone,
  LocalDate admissionDate, String? notes }
class Allocation { YearMonth month, int amount }
class PaymentDraft { String studentId, String enrollmentId, List<Allocation> allocations, LocalDate paidOn,
  PaymentMethod method, String? note; int get total; }
// dues_models.dart
enum DueLevel { upcoming(0), justDue(1), remind(2), followUp(3), urgent(4), finalDays(5), overdue(6);
  const DueLevel(this.rank); final int rank; static DueLevel forDay(int dayInDue); } // 1-2,3-4,5-6,7-8,9-10,≥11
enum MonthState { waived, free, paid, partial, unpaid }
class EnrollmentTerms { enrollmentId, studentId, batchId, String studentName, String batchName, String subjectName,
  BillingType billing, YearMonth start, YearMonth? end, List<FeePeriod> batchFees, List<FeePeriod> overrides,
  bool batchArchived, bool studentLeft, bool enrollmentEnded }
class PaymentFact { enrollmentId, YearMonth month, int amount, bool waived }
class MonthDue { YearMonth month, int fee, bool feeMissing, int paid, int remaining, MonthState state,
  LocalDate dueDate, bool isDue, DueLevel? level /*null when closed*/, int? dayInDue /*1..10 else null*/, int overpaid;
  bool get isOpen; }
class EnrollmentDues { EnrollmentTerms terms, List<MonthDue> months /*start..min(end, today+12m)*/;
  List<MonthDue> openDue, int totalOutstanding, DueLevel? worst, int? worstDay, YearMonth? oldestOpenDue,
  bool inactive /*left || archived || ended*/; }
class StudentDues { String studentId, String name, List<EnrollmentDues> enrollments, DueLevel? worst,
  int? worstDay, int openDueMonths, int totalOutstanding, YearMonth? oldestOpenDue, List<YearMonth> openMonths }
class DuesReport { List<StudentDues> active /*sorted*/, List<StudentDues> inactive, Map<DueLevel,int> countByLevel,
  int totalOutstandingActive, int totalOutstandingInactive, int studentsWithDues, int overdueStudents }
// schedule_models.dart
class BatchSchedule { Batch batch, String subjectName, List<Slot> slots, List<ScheduleException> exceptions }
class Occurrence { String occ, String batchId, LocalDate date, int startMin, int endMin, OccurrenceKind kind,
  String? slotId, String? exceptionId, LocalDate? originalDate, int? originalStartMin, int? originalEndMin }
class CancelledOccurrence { String occ, batchId, LocalDate date, int startMin, int endMin, String exceptionId, String? note }
class MovedAway { String occ, batchId, LocalDate originalDate, int originalStartMin, LocalDate newDate, int newStartMin }
class ExpandResult { List<Occurrence> occurrences, List<CancelledOccurrence> cancelled, List<MovedAway> movedAway }
class Clash { Occurrence candidate, Occurrence existing }
class ClashGroup { String batchId, int startMin, int endMin, bool everyWeek, int weekday, LocalDate? date,
  OccurrenceKind existingKind, int count } // everyWeek → "প্রতি রবিবার"; else date → "২৬ নভে"
class FreeSuggestion { int durationMin, int? earlierStartMin, int? laterStartMin;
  int? get primaryStartMin; } // smaller |shift|, tie → later
class SlotCheckResult { List<ClashGroup> groups, FreeSuggestion? suggestion; bool get ok; }
final class ScheduleClashException extends AppException {
  ScheduleClashException(this.result) : super(ErrorCodes.scheduleClash); final SlotCheckResult result; }
// occ_id.dart
sealed class OccRef { const OccRef(); }
final class RegularOccRef extends OccRef { const RegularOccRef(this.slotId, this.originalDate); final String slotId; final LocalDate originalDate; }
final class ExtraOccRef extends OccRef { const ExtraOccRef(this.exceptionId); final String exceptionId; }
abstract final class OccId { static String regular(String slotId, LocalDate originalDate); // 's.<slot>.<yyyymmdd>'
  static String extra(String exceptionId); /* 'x.<id>' */ static OccRef parse(String occ); /* FormatException */ }
// reminder_models.dart
enum ReminderPermission { granted, exactDenied, denied, unsupported } // used by data/notifications and features
class PlannedReminder { int id, DateTime fireAtUtc, String occ, String batchId, LocalDate date, int startMin,
  int endMin, OccurrenceKind kind, int leadMin, String payload }
// synced_tables.dart
const kCurrentSchemaVersion = 1;
const kSyncedTables = <String>['subjects','batches','batch_slots','schedule_exceptions','batch_fees','students',
  'student_photos','enrollments','enrollment_fees','attendance_sessions','attendance_records','payments',
  'other_income','settings'];
const kBlobColumns = <String, Set<String>>{'student_photos': {'jpeg'}};
const kSyncColumns = {'id','created_at','updated_at','deleted_at','device_id','rev'};
// sync_models.dart
typedef RowMap = Map<String, Object?>;
class Snapshot { int formatVersion, int schemaVersion, String appVersion, String snapshotId, String deviceId,
  String deviceName, int createdAtMs, Map<String,int> counts, String sha256, Map<String, List<RowMap>> tables }
enum ChangeKind { add, update, delete, restore }
class RowChange { String table, String id, ChangeKind kind, RowMap incoming, RowMap? local }
enum SummaryEntity { subjects, batches, schedule, students, enrollments, attendance, payments, settings }
class EntityChange { int added, int updated /*incl. restored*/, int deleted, int keptLocal,
  List<RowMap> addedSamples, List<RowMap> updatedSamples, List<RowMap> deletedSamples /*≤3 each*/ }
class ChangeSummary { Map<SummaryEntity, EntityChange> entities, List<RowChange> winners;
  int get totalChanges; bool get isEmpty; }
```
- Acceptance: `OccId` round-trips ids containing UUID dashes; `DueLevel.forDay` matches Product §3.5 bands; all models construct `const` where fields allow.
- Tests: occ parse/format incl. malformed input; enum `parse` for every DB code; `Enrollment.coversDate`; `Slot.activeOn` with null bounds.

### M2 — Pure engines (4 parallel)

**M2-A · Dues engine** — size L — deps: M1
- Files: `lib/domain/dues/dues_engine.dart`, `test/domain/dues_test.dart`.
```dart
abstract final class DuesEngine {
  static LocalDate dueDate(BillingType b, YearMonth m);        // prepaid → 1st of m; postpaid → 1st of m+1
  static ({int fee, bool missing}) feeFor(EnrollmentTerms t, YearMonth m); // latest override ≤ m (null amount = cleared) ?? latest batch fee ≤ m
  static EnrollmentDues forEnrollment({required EnrollmentTerms terms, required List<PaymentFact> payments,
      required LocalDate today, int aheadMonths = 12});
  static DuesReport report({required LocalDate today, required List<EnrollmentTerms> terms, required List<PaymentFact> payments});
  static YearMonth defaultFirstBillableMonth(LocalDate joinDate, int cutoffDay); // day ≤ C → that month, else next
  static YearMonth defaultLastBillableMonth(LocalDate leaveOrArchiveDate);     // day ≥ 11 → that month, else previous
  static List<Allocation> autoAllocate({required EnrollmentDues dues, required int amount, required LocalDate today});
  static void validateAllocations({required EnrollmentDues dues, required List<Allocation> allocations}); // throws
  static int monthsBecomingPartial({required List<EnrollmentTerms> before, required List<EnrollmentTerms> after,
      required List<PaymentFact> payments, required LocalDate today});
}
```
- Rules: Product §3.1–3.5 + Arch §4. Waived (any waived fact) beats everything; fee 0 → `free`; `paid ≥ fee` → paid (excess → `overpaid`); open = partial|unpaid; `isDue = today ≥ dueDate`; `dayInDue = today − dueDate + 1` (1..10 only), level via `forDay`, later months → overdue. Allocation: oldest open month first (due or upcoming), never above a month's remaining, forward to `today.yearMonth + 12`; leftover → `ValidationException(allocationBeyondHorizon)`. Report sorting §1 #8; inactive enrollments go to `inactive` (grey group) and are excluded from `countByLevel`.
- Acceptance: Scenarios **1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11** at engine level; plus Arch §4 required list.
- Tests: ≥ 45 table-driven cases (each scenario one group; Dec→Jan rollover; leap Feb; today before start; fee change mid-enrollment; override 800 vs batch fee change; overpaid; advance payment; feeMissing; partial after fee raise via `monthsBecomingPartial`).

**M2-B · Schedule engine** — size L — deps: M1
- Files: `lib/domain/schedule/schedule_engine.dart`, `test/domain/schedule_test.dart`.
```dart
abstract final class ScheduleEngine {
  static bool overlaps(int aStart, int aEnd, int bStart, int bEnd); // a.start < b.end && b.start < a.end
  static ExpandResult expand({required DateRange range, required List<BatchSchedule> batches});
  static List<Clash> findClashes({required List<Occurrence> candidates, required List<Occurrence> existing});
  static SlotCheckResult checkSlotEdit({required BatchSchedule proposed, required List<BatchSchedule> others,
      required LocalDate from, required LocalDate today, Set<String>? onlySlotIds, int horizonWeeks = 12,
      int dayStartMin = 360, int dayEndMin = 1380});
  static SlotCheckResult checkSingle({required Occurrence candidate, required List<BatchSchedule> all,
      String? excludeOcc, int dayStartMin = 360, int dayEndMin = 1380});
  static FreeSuggestion suggestSameDay({required int preferredStartMin, required int durationMin,
      required List<(int, int)> busy, int dayStartMin = 360, int dayEndMin = 1380, int stepMin = 5});
}
```
- Rules: Product §3.9–3.10 + Arch §4A rules 1–5 (archived batches yield nothing; regular occurrences only on `d ≥ batch.createdOn` and `slot.activeOn(d)`; cancel drops + lists in `cancelled`; reschedule replaces, keeps `occ`, included when `newDate` in range; extras added; sort by date, start, batchId). `checkSlotEdit` expands proposed (new slots + the batch's exceptions) and others over `[max(from,today), +horizon]` ∪ dates of all future one-offs, checks proposed↔others and proposed↔proposed (pairs where at least one side comes from `onlySlotIds` when given), groups via `ClashGroup` (regular existing → `everyWeek`), suggestion = start free on **every** checked date of that weekday. `checkSingle` compares the candidate with all effective occurrences on its date minus `excludeOcc`. Suggestion window `[dayStart, dayEnd − duration]`, 5-min steps, touching allowed.
- Acceptance: Scenarios **17, 18, 19, 20, 21, 25** (incl. exact suggestion times 09:00 and 12:00 in 17).
- Tests: ≥ 45 incl. every Arch §4A bullet, legacy-conflict exclusion via `onlySlotIds`, suggestion none ("no free time" → both null).

**M2-C · Reminder planner & attendance stats** — size M — deps: M1
- Files: `lib/domain/reminders/reminder_planner.dart`, `lib/domain/attendance_stats/attendance_stats.dart`, tests.
```dart
abstract final class ReminderPlanner {
  static int? effectiveLead(int? batchLead, int defaultLead); // 0 → null (off); null → default
  static List<PlannedReminder> plan({required List<Occurrence> occurrences, required Map<String, int?> leadByBatch,
      required int defaultLeadMin, required CenterTime center, required DateTime nowUtc,
      int windowDays = 7, int maxCount = 200});
  static String payloadFor(String occ); // 'rollcall|<occ>'
  static String? occFromPayload(String? payload);
}
class AttendanceTally { const AttendanceTally({this.present = 0, this.absent = 0, this.late = 0, this.leave = 0});
  final int present, absent, late, leave; int get held; int? get percent; // (P+L)/(held−leave), round half-up, null if 0
  AttendanceTally add(AttendanceStatus s); }
abstract final class AttendanceStats {
  static AttendanceTally tally(Iterable<AttendanceStatus> statuses);
  static int? meanPercent(Iterable<AttendanceTally> perStudent);   // batch % = mean of non-null
  static bool absenceStreak(List<AttendanceStatus> chronological, {int length = 3}); // leave skipped, late breaks
}
```
- Acceptance: Scenario **22** (15:45 / 09:30 / default 10 → 15:50 / cancelled removed / extra 18:00 → 17:50); **12** (late counts as attended); **13**; fire times computed in UTC on a UTC runner.
- Tests: ≥ 25 (window edges, past fire skipped, cap, off batch, payload round-trip, % rounding, streak variants).

**M2-D · Snapshot codec & diff** — size M — deps: M1
- Files: `lib/domain/sync/{snapshot_codec,sync_diff}.dart`, tests.
```dart
abstract final class SnapshotCodec {
  static const format = 'attendance-alamin-backup'; static const formatVersion = 1;
  static String canonicalJson(Object? value);          // sorted keys, no whitespace, rows pre-sorted by id
  static String tablesSha256(Map<String, List<RowMap>> tables);
  static Snapshot build({required Map<String, List<RowMap>> tables, required String appVersion,
      required String snapshotId, required String deviceId, required String deviceName, required int createdAtMs});
  static List<int> encode(Snapshot s);                 // gzip(utf8(json))
  static Snapshot decode(List<int> bytes);             // throws ImportException(importNotBackup|importNewerSchema|importChecksum|importCorrupt)
}
abstract final class SyncDiff {
  static bool incomingWins(RowMap incoming, RowMap local); // (updated_at, device_id, rev) strictly greater
  static bool contentDiffers(RowMap a, RowMap b);           // all columns except id/created_at/updated_at/device_id/rev
  static ChangeSummary diff({required Map<String, List<RowMap>> local, required Snapshot incoming});
}
```
- Rules: Arch §3.5 + Product §4; entity mapping: batch_fees→batches, slots+exceptions→schedule, student_photos→students, enrollment_fees→enrollments, attendance counted as **distinct session ids**, payments counted as **distinct receipt_id** (+ other_income rows), settings by key. Blobs arrive base64 (data layer converts).
- Acceptance: Scenario **15** reproduced with row maps (Added 1, Deleted 1, keptLocal 1 for Rahim, Sara's payment untouched); importing the applied result again → `isEmpty`.
- Tests: ≥ 25 (each LWW branch, unknown tombstone skipped, restore, tie-breaks, gzip round-trip, checksum tamper, newer schema).

### M3 — Persistence & visual foundations (3 parallel) → then Lead dispatches `commit-generated.yml`

**M3-A · Drift database** — size L — deps: M1
- Files: `lib/data/db/**`, `lib/data/infra_providers.dart`, `test/data/db/*`.
- Tables (each `extends Table with SyncColumns` unless local; `@DataClassName('<Row>')`; `primaryKey => {id}`; CHECKs via `customConstraints`; `@TableIndex` per Arch §3.2):

| SQL table | Table class | Row class | Companion | db getter | Extra columns vs Arch §3.2 |
|---|---|---|---|---|---|
| subjects | `Subjects` | `SubjectRow` | `SubjectsCompanion` | `subjects` | — |
| batches | `Batches` | `BatchRow` | `BatchesCompanion` | `batches` | — |
| batch_slots | `BatchSlots` | `SlotRow` | `BatchSlotsCompanion` | `batchSlots` | — |
| schedule_exceptions | `ScheduleExceptions` | `ExceptionRow` | `ScheduleExceptionsCompanion` | `scheduleExceptions` | — |
| batch_fees | `BatchFees` | `BatchFeeRow` | `BatchFeesCompanion` | `batchFees` | — |
| students | `Students` | `StudentRow` | `StudentsCompanion` | `students` | — |
| student_photos | `StudentPhotos` | `StudentPhotoRow` | `StudentPhotosCompanion` | `studentPhotos` | — |
| enrollments | `Enrollments` | `EnrollmentRow` | `EnrollmentsCompanion` | `enrollments` | +`join_date`, +`end_date`, −`fee_override` |
| enrollment_fees | `EnrollmentFees` | `EnrollmentFeeRow` | `EnrollmentFeesCompanion` | `enrollmentFees` | new: `enrollment_id`, `effective_month`, `amount INT NULL` |
| attendance_sessions | `AttendanceSessions` | `SessionRow` | `AttendanceSessionsCompanion` | `attendanceSessions` | — |
| attendance_records | `AttendanceRecords` | `RecordRow` | `AttendanceRecordsCompanion` | `attendanceRecords` | status CHECK +`'E'` |
| payments | `Payments` | `PaymentRow` | `PaymentsCompanion` | `payments` | +`receipt_id`; method CHECK allows `custom:%` |
| other_income | `OtherIncome` | `OtherIncomeRow` | `OtherIncomeCompanion` | `otherIncome` | new: `student_id NULL`, `label`, `amount`, `paid_on`, `method`, `note` |
| settings | `SyncedSettings` (`tableName => 'settings'`) | `SettingRow` | `SyncedSettingsCompanion` | `syncedSettings` | `value TEXT` |
| local_meta | `LocalMeta` (no sync cols) | `LocalMetaRow` | `LocalMetaCompanion` | `localMeta` | `meta_key` PK, `meta_value` |
| safety_snapshots | `SafetySnapshots` | `SafetySnapshotRow` | `SafetySnapshotsCompanion` | `safetySnapshots` | `id`, `created_at`, `reason`, `bytes BLOB` |
| import_log | `ImportLog` | `ImportLogRow` | `ImportLogCompanion` | `importLog` | per Arch §3.3 |

```dart
mixin SyncColumns on Table { TextColumn get id => text()(); IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()(); IntColumn get deletedAt => integer().nullable()();
  TextColumn get deviceId => text()(); IntColumn get rev => integer().withDefault(const Constant(1))(); }
@DriftDatabase(tables: [/* all 17 */])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  @override int get schemaVersion => 1;              // == kCurrentSchemaVersion (test)
  @override MigrationStrategy get migration;         // onCreate createAll; beforeOpen PRAGMA foreign_keys=ON
  Stream<T> watchComposite<T>(Set<ResultSetImplementation<dynamic, dynamic>> tables, Future<T> Function() load);
      // customSelect('SELECT 1', readsFrom: tables).watch().asyncMap((_) => load())
}
class SyncStamper { SyncStamper({required Clock clock, required String deviceId});
  final String deviceId; int nowMs(); int nextUpdatedAt(int oldUpdatedAt); } // max(now, old+1)
// mappers.dart: one top-level fn per row → domain, needs CenterTime for epoch→LocalDate
Subject subjectFromRow(SubjectRow r); Batch batchFromRow(BatchRow r, CenterTime c); Slot slotFromRow(SlotRow r);
ScheduleException exceptionFromRow(ExceptionRow r); FeePeriod feeFromRow(BatchFeeRow r); FeePeriod overrideFromRow(EnrollmentFeeRow r);
Student studentFromRow(StudentRow r); Enrollment enrollmentFromRow(EnrollmentRow r); Payment paymentFromRow(PaymentRow r);
AttendanceSession sessionFromRow(SessionRow r); AttendanceRecord recordFromRow(RecordRow r); OtherIncome otherIncomeFromRow(OtherIncomeRow r);
// db_queries.dart (shared read helpers used by several repos)
Future<List<BatchSchedule>> loadAllSchedules(AppDatabase db, CenterTime c); // live batches incl. archived flag
Future<List<EnrollmentTerms>> loadEnrollmentTerms(AppDatabase db, CenterTime c);
// connection
QueryExecutor openConnection();       // conditional export: _native (dart:io allowed) / _web (records WebStorageInfo)
class WebStorageInfo { const WebStorageInfo(this.implementation, this.missingFeatures); final String implementation;
  final List<String> missingFeatures; bool get persistent => implementation != 'inMemory'; }
final webStorageReport = ValueNotifier<WebStorageInfo?>(null);
Future<void> requestPersistentStorage(); // web: navigator.storage.persist() via package:web; else no-op
// infra_providers.dart
final clockProvider = Provider<Clock>((ref) => const SystemClock());
final centerTimeProvider = Provider<CenterTime>((ref) => CenterTime.dhaka);
final deviceIdProvider = Provider<String>((ref) => throw UnimplementedError('override in bootstrap'));
final appDatabaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override in bootstrap'));
final syncStamperProvider = Provider<SyncStamper>((ref) =>
    SyncStamper(clock: ref.watch(clockProvider), deviceId: ref.watch(deviceIdProvider)));
Future<String> ensureDeviceId(AppDatabase db); // creates local_meta 'device_id' (v4) on first launch
```
- Acceptance: every CHECK in Arch §3.2 (+ this table) rejects bad input in tests; `kSyncedTables` all exist; `schemaVersion == kCurrentSchemaVersion`; web build green with the conditional connection; `generated-sources` shows the names above.
- Tests: create/open in-memory, FK enforcement, CHECKs, `watchComposite` emits on each table, mappers round-trip, `loadAllSchedules` excludes tombstones, reopen preserves rows (v1 migration test).

**M3-B · Theme (Aurora Ink tokens)** — size M — deps: M0
- Files: `lib/app/theme/**`, `test/app/theme_contrast_test.dart`.
```dart
abstract final class LightTokens { /* every UX §4 + §5 + §6 value as static const Color */ }
abstract final class DuskTokens { /* same names */ }
ThemeData buildTheme(Brightness brightness); // explicit ColorScheme, fontFamily HindSiliguri, M3, UX §4 type scale,
                                             // component themes (pill buttons, radii §1 #28), 4 extensions
class AuroraTokens extends ThemeExtension<AuroraTokens> { /* fields per §2.10 */ copyWith; lerp; }
class AppGradients extends ThemeExtension<AppGradients> { final RadialGradient meshA, meshB, meshC; final Color heroBase;
  final List<RadialGradient> heroRadials; final Color heroCtaFill, heroCtaText; }
class SeverityColors extends ThemeExtension<SeverityColors> { Color hue(DueLevel l); Color badgeFill(DueLevel l);
  Color badgeText(DueLevel l); Color? badgeBorder(DueLevel l); Color segment(int day);
  final Color paidFill, paidText, waivedFill, waivedText, notDueFill, notDueText; }
class AttendanceColors extends ThemeExtension<AttendanceColors> { Color fill(AttendanceStatus s); Color text(AttendanceStatus s);
  Color? border(AttendanceStatus s); final Color heatLow, heatHigh; }
extension ThemeX on BuildContext { AuroraTokens get aurora; AppGradients get gradients;
  SeverityColors get severity; AttendanceColors get attendance; TextStyle get statNumber; }
```
- Acceptance: Scenario **24** contrast part — every text/fill pair in UX §4–6 meets ≥ 4.5 (body) / ≥ 3.0 (large, icons), both themes, incl. text over glass composited on each mesh pool and hero text at the teal pool centre; OD badge identical in both themes.
- Tests: pure contrast computation (relative luminance + alpha compositing helper), `lerp` at 0/0.5/1.

**M3-C · l10n plumbing & common strings** — size M — deps: M1-A
- Files: `lib/app/l10n/{l10n_x,error_text}.dart`, fragments `common`, `nav`, `err`, `a11y`, `test/app/l10n_test.dart`.
```dart
extension L10nX on BuildContext { AppLocalizations get l10n; AppFormat get fmt; Lang get lang; }
String errorText(AppLocalizations l10n, Object error); // AppException.code → err<Code>; else errUnknown
```
- Keys (bn per Product glossary): `commonSave commonCancel commonDelete commonEdit commonUndo commonRetry commonClose commonBack commonNext commonDone commonYes commonNo commonOk commonSearch commonMore commonCall commonCopyNumber commonCopied commonShare commonDetails commonOptional commonToday commonAll commonNotes commonLoadingFailed`; `nav{Today,Batches,Students,Fees,More}`; `err<Code>` for every `ErrorCodes.all`; `a11y` merged-label helpers with placeholders.
- Acceptance: `errorText` covers `ErrorCodes.all` (test iterates the list in bn and en); merged ARB passes `merge_arb.py`.

### M4 — Repositories & shared widgets (4 parallel)

**M4-A · Structure repositories** — size L — deps: M3-A
- Files: `lib/data/repositories/{subjects,batches,schedule}_repository.dart`, `drift/*_drift.dart`, `structure_providers.dart`, `test/data/structure/*`, `test/helpers/fakes/fake_structure_repos.dart`.
```dart
abstract interface class SubjectsRepository {
  Stream<List<Subject>> watchAll(); Future<Subject?> findByName(String name);
  Future<String> create({required String name, String? notes}); Future<void> rename(String id, String name);
  Future<void> softDelete(String id); }
class DeleteImpact { const DeleteImpact({required this.sessions, required this.payments, required this.students});
  final int sessions, payments, students; }
abstract interface class BatchesRepository {
  Stream<List<Batch>> watchAll({bool includeArchived = false}); Stream<Batch?> watchById(String id);
  Future<Batch?> getById(String id);
  Future<String> create(BatchDraft draft);  // batch + fee row + slots, clash-checked, one tx; stores lastBillingType
  Future<void> rename(String id, String name); Future<void> setBillingType(String id, BillingType t);
  Future<void> setReminderLead(String id, int? minutes); Future<void> setNotes(String id, String? notes);
  Stream<List<FeePeriod>> watchFees(String batchId);
  Future<int> previewPartialMonths(String batchId, int amount, YearMonth from);
  Future<void> setFee(String batchId, int amount, YearMonth from);
  Future<void> archive(String id, {required LocalDate on, required YearMonth lastBillableMonth});
  Future<SlotCheckResult> previewUnarchive(String id);
  Future<int> unarchive(String id, {bool acceptClashes = false, bool waiveGap = true}); // returns gap months; throws ScheduleClashException unless accepted
  Future<DeleteImpact> deleteImpact(String id); Future<void> softDelete(String id); }
abstract interface class ScheduleRepository {
  Stream<List<BatchSchedule>> watchAllSchedules();
  Future<SlotCheckResult> checkSlots(String? batchId, List<SlotDraft> slots, {required LocalDate from});
  Future<void> replaceSlots(String batchId, List<SlotDraft> slots, {required LocalDate from}); // Arch §3.2 split rules
  Future<SlotCheckResult> checkSingle({required String batchId, required LocalDate date, required int startMin,
      required int endMin, String? replacingOcc});
  Future<String> addExtra({required String batchId, required LocalDate date, required int startMin,
      required int endMin, String? note});                       // returns occ 'x.<id>'
  Future<void> reschedule(String occ, {required LocalDate newDate, required int startMin, required int endMin});
  Future<void> cancel(String occ, {String? note});
  Future<void> restore(String occ);                                // un-cancel (clash-checked) / un-move
  Future<void> deleteExtra(String occ);
  Future<OccurrenceInfo?> resolve(String occ);
  Future<int> cancelRange(DateRange range, {String? note}); Future<int> undoCancelRange(DateRange range); }
class OccurrenceInfo { const OccurrenceInfo({required this.batch, required this.subjectName, this.occurrence,
  this.cancelled = false}); final Batch batch; final String subjectName; final Occurrence? occurrence; final bool cancelled; }
// structure_providers.dart: subjectsRepositoryProvider, batchesRepositoryProvider, scheduleRepositoryProvider
```
- Acceptance: scenarios **9** (archive LBM), **17–21, 25** through repository calls (clash → `ScheduleClashException`, saves otherwise); slot edit "from date" keeps past sessions (**20**); unarchive gap-waive prompt data; all writes stamp sync columns.
- Tests: in-memory DB per method; fakes mirror behaviour (no clash checks in fakes unless configured).

**M4-B · People & money repositories** — size L — deps: M3-A
- Files: `lib/data/repositories/{students,enrollments,payments,attendance,other_income}_repository.dart`, `drift/*`, `people_providers.dart`, tests, `test/helpers/fakes/fake_people_repos.dart`.
```dart
abstract interface class StudentsRepository {
  Stream<List<Student>> watchAll({StudentStatus? status}); Stream<Student?> watchById(String id);
  Future<Student?> getById(String id); Future<List<Student>> findDuplicates({required String name, String? phone});
  Future<String> nextRoll();                                   // max numeric roll + 1, zero-padded to 2
  Future<String> create(StudentDraft d); Future<void> update(String id, StudentDraft d);
  Future<void> markLeft(String id, {required LocalDate on, required Map<String, YearMonth> lastBillableByEnrollment});
  Future<int> rejoin(String id, {required bool waiveGap});     // clears LBM/endDate, returns gap months
  Future<Uint8List?> getPhoto(String id); Future<void> setPhoto(String id, Uint8List? jpeg); // ≤200 KB else photoTooLarge
  Future<DeleteImpact> deleteImpact(String id); Future<void> softDelete(String id); }
abstract interface class EnrollmentsRepository {
  Stream<List<Enrollment>> watchAll(); Stream<List<Enrollment>> watchForStudent(String studentId);
  Stream<List<Enrollment>> watchForBatch(String batchId);
  Stream<List<EnrollmentTerms>> watchTerms();                  // via loadEnrollmentTerms + watchComposite
  Future<String> enroll({required String studentId, required String batchId, required LocalDate joinDate,
      required YearMonth startMonth, int? feeOverride});        // duplicateOpenEnrollment guard
  Future<void> setStartMonth(String enrollmentId, YearMonth m);
  Future<void> setOverride(String enrollmentId, int? amount, {required YearMonth from});
  Stream<List<FeePeriod>> watchOverrides(String enrollmentId);
  Future<void> end(String enrollmentId, {required LocalDate on, required YearMonth lastBillableMonth});
  Future<List<Student>> rosterOn(String batchId, LocalDate date); } // Product §3.6 listing, sorted roll then name
abstract interface class PaymentsRepository {
  Stream<List<Payment>> watchAll(); Stream<List<Payment>> watchForStudent(String studentId);
  Stream<List<PaymentFact>> watchFacts();
  Future<String> record(PaymentDraft d);                        // validates via DuesEngine; returns receiptId
  Future<void> updateReceipt(String receiptId, PaymentDraft d); Future<void> deleteReceipt(String receiptId);
  Future<List<Payment>> receipt(String receiptId);
  Future<void> waive(String enrollmentId, YearMonth month, {String? reason}); Future<void> unwaive(String enrollmentId, YearMonth month); }
class SessionSummary { const SessionSummary({required this.session, required this.tally}); final AttendanceSession session; final AttendanceTally tally; }
abstract interface class AttendanceRepository {
  Future<(AttendanceSession, List<AttendanceRecord>)?> getSession(String occ);
  Future<void> saveRollCall({required Occurrence occurrence, required Map<String, AttendanceStatus> statuses,
      String? note, bool removeCancel = false});                // session + records, one tx; future date → rollCallFutureDate
  Future<String> saveAdHocRollCall({required String batchId, required LocalDate date, required int startMin,
      required int endMin, required Map<String, AttendanceStatus> statuses}); // creates extra (clash-checked) + session, one tx; returns occ
  Future<void> deleteSession(String occ);
  Stream<List<SessionSummary>> watchSummaries({String? batchId, LocalDate? from, LocalDate? to});
  Stream<List<AttendanceRecord>> watchRecords({String? studentId, String? batchId}); }
abstract interface class OtherIncomeRepository {
  Stream<List<OtherIncome>> watchBetween(LocalDate from, LocalDate to); Future<String> add(OtherIncome draft);
  Future<void> softDelete(String id); }
// people_providers.dart: studentsRepositoryProvider, enrollmentsRepositoryProvider, paymentsRepositoryProvider,
// attendanceRepositoryProvider, otherIncomeRepositoryProvider
```
- Acceptance: scenarios **4, 5, 7, 8, 10, 12, 15-prep** at repository level; roll call is idempotent (same ids on re-save, Arch §3.2a); receipt edit replaces all its rows atomically.
- Tests: in-memory DB, every method; fakes.

**M4-C · Settings, local meta & backup data** — size L — deps: M3-A, M2-D (merged in M2)
- Files: `lib/data/repositories/{settings,local_meta}_repository.dart`, `drift/*`, `settings_providers.dart`, `lib/data/backup/**`, tests, `test/helpers/fakes/fake_settings_repos.dart`.
```dart
abstract interface class SettingsRepository {
  Stream<T> watch<T>(SettingKey<T> key); Future<T> get<T>(SettingKey<T> key); Future<void> set<T>(SettingKey<T> key, T value); }
abstract interface class LocalMetaRepository { // raw device keys:
  // 'rollcall_draft:<occ>' JSON · 'last_method:<studentId>' · 'reminded:<yyyymmdd>' JSON list of studentIds ·
  // 'absence_dismissed:<enrollmentId>' sessionId · 'pane:<screen>' double
  Future<String?> getRaw(String key); Stream<String?> watchRaw(String key);
  Future<void> setRaw(String key, String? value); }
abstract interface class BackupRepository {
  Future<Snapshot> buildSnapshot({required String appVersion});  // blobs → base64; records lastExportAt
  Future<ChangeSummary> preview(Snapshot incoming);               // row validation (types, enums, FK presence) then diff
  Future<ApplyOutcome> apply(Snapshot incoming, ChangeSummary summary); // safety copy, defer_foreign_keys, upserts, import_log, checks; all-or-nothing
  Stream<List<SafetyCopyInfo>> watchSafetyCopies();               // newest first, max 3 kept
  Future<void> restoreSafetyCopy(String id);                      // full replace of synced tables (only sanctioned hard delete)
  Future<int> countOverfilledMonths(); }
class ApplyOutcome { const ApplyOutcome({required this.applied, required this.safetyCopyId}); final int applied; final String safetyCopyId; }
class SafetyCopyInfo { const SafetyCopyInfo({required this.id, required this.createdAtMs, required this.reason}); final String id; final int createdAtMs; final String reason; }
abstract interface class BackupFiles { Future<bool> save(Uint8List bytes, {required String fileName});
  Future<void> share(Uint8List bytes, {required String fileName}); Future<Uint8List?> pick(); }
String backupFileName(int createdAtMs, CenterTime c); // coaching-backup-2026-11-20-2130.ambackup
// settings_providers.dart: settingsRepositoryProvider, localMetaRepositoryProvider; backup_providers.dart: backupRepositoryProvider, backupFilesProvider
```
- Acceptance: scenario **15** end-to-end on two in-memory DBs (export P, import into W, summary counts, apply, re-import empty, restore safety copy); device keys never appear in snapshots; `apply` failure leaves DB unchanged.

**M4-D · Aurora widget library** — size XL — deps: M3-B, M3-C
- Files: `lib/app/widgets/*.dart`, fragment `ui`, `test/app/widgets/*`.
```dart
class EffectsMode extends InheritedWidget { const EffectsMode({super.key, required this.reduced, required super.child});
  final bool reduced; static bool reducedOf(BuildContext context); }
class MeshBackground extends StatelessWidget { const MeshBackground({super.key, required this.child}); } // 3 pools + grain, RepaintBoundary
class GlassCard extends StatelessWidget { const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16),
  this.dense = false, this.blur = false, this.onTap, this.radius = 20}); }   // blur only for ≤3 regions/screen
class HeroCard extends StatelessWidget { const HeroCard({super.key, required this.child, this.cta}); final Widget? cta; }
class HeroPillButton extends StatelessWidget { const HeroPillButton({super.key, required this.label, required this.onPressed}); }
class SeverityBadge extends StatelessWidget { const SeverityBadge({super.key, required this.level, this.dayInDue,
  this.monthCount = 1, this.partialRemaining, this.compact = false}); final DueLevel level; final int? dayInDue;
  final int monthCount; final int? partialRemaining; final bool compact; }
class LevelEdgeBar extends StatelessWidget { const LevelEdgeBar({super.key, required this.level}); final DueLevel? level; }
class EscalationBar extends StatelessWidget { const EscalationBar({super.key, required this.todayDay, this.overdueCount = 0});
  final int? todayDay; /* 1..10 or null when beyond */ final int overdueCount; }
class MonthStateChip extends StatelessWidget { const MonthStateChip({super.key, required this.due, this.selected = false, this.onTap}); final MonthDue due; }
class MonthStrip extends StatelessWidget { const MonthStrip({super.key, required this.months, this.onTap}); final List<MonthDue> months;
  final ValueChanged<YearMonth>? onTap; }
class AttendanceStatusChip extends StatelessWidget { const AttendanceStatusChip({super.key, required this.status, this.short = false}); }
enum ClassState { now, moved, cancelled, extra }
class StatePill extends StatelessWidget { const StatePill({super.key, required this.state}); final ClassState state; }
class StatTile extends StatelessWidget { const StatTile({super.key, required this.label, required this.value, this.caption, this.footer}); }
class EmptyState extends StatelessWidget { const EmptyState({super.key, required this.icon, required this.message,
  this.actionLabel, this.onAction, this.fill = true}); }
class StickyActionBar extends StatelessWidget { const StickyActionBar({super.key, required this.label, this.onPressed,
  this.disabledReason, this.summary}); }
class InitialsAvatar extends StatelessWidget { const InitialsAvatar({super.key, required this.name, this.size = 40}); } // grapheme-safe
class ConflictFix { const ConflictFix({required this.label, required this.onTap, this.primary = false}); final String label; final VoidCallback onTap; final bool primary; }
class ConflictCard extends StatelessWidget { const ConflictCard({super.key, required this.lines, this.moreCount = 0, this.fixes = const []});
  final List<String> lines; final int moreCount; final List<ConflictFix> fixes; } // live region
class SectionHeader extends StatelessWidget { const SectionHeader({super.key, required this.title, this.trailing}); }
class SegmentedChoice<T> extends StatelessWidget { const SegmentedChoice({super.key, required this.options,
  required this.selected, required this.onChanged, required this.labelOf}); }
class BentoPlacement { const BentoPlacement({required this.col, required this.row, required this.colSpan, this.rowSpan = 1, required this.child}); }
class BentoGrid extends StatelessWidget { const BentoGrid({super.key, required this.placements, required this.rowCount,
  required this.gutter, this.columns = 12, this.minRowUnit = 184}); } // asserts full coverage, equal rows
class PaneLayout extends StatelessWidget { const PaneLayout({super.key, required this.list, required this.detail, this.contextPane,
  this.listWidth, this.onListWidthChanged, this.listMin = 320, this.listMax = 440, this.detailMax = 720, this.contextWidth = 320}); }
class DenseColumn<T> { const DenseColumn({required this.label, required this.cell, this.flex = 1, this.numeric = false}); }
class DenseTable<T> extends StatelessWidget { const DenseTable({super.key, required this.columns, required this.rows,
  this.onRowTap, this.selected}); } // sticky header, 48dp rows, fills pane
Future<bool> showConfirmDialog(BuildContext context, {required String title, String? body, required String confirmLabel, bool destructive = false});
void showUndoSnackBar(BuildContext context, {required String message, VoidCallback? onUndo, String? actionLabel, VoidCallback? onAction});
```
- Acceptance: legibility law (UX §4) — dense content on `surfaceDense`; OD badge solid; L5 rose border; never colour-only (icon + label); grain generated once (fixed seed); reduced mode removes blur + grain; `BentoGrid` asserts on a ragged row.
- Tests: `testScreenMatrix` is not yet available (M5) — use a local mini-harness; one golden-tagged gallery of every widget in both themes (screenshot tag).

### M5 — App shell (2 parallel)

**M5-A · Shell, router & stubs** — size XL — deps: M3, M4
- Files: `lib/main.dart`, `lib/app/{app,bootstrap,router,routes}.dart`, `lib/app/shell/**`, `lib/app/providers/app_prefs_providers.dart`, `lib/app/services/{contact_actions,share_service,reminder_bootstrap}.dart`, **all stub screens and `*_entry.dart` files** listed below, fragment `shell`, `test/app/shell/*`.
```dart
Future<void> bootstrap(); // open DB, ensureDeviceId, requestPersistentStorage (web), preload AppPrefs, onboarding flag,
                          // launch route via initRemindersAndGetLaunchRoute; runApp(UncontrolledProviderScope(...))
class AppPrefs { const AppPrefs({required this.lang, required this.themeMode, required this.reducedEffects, required this.onboardingDone});
  final Lang lang; final ThemeMode themeMode; final bool reducedEffects; final bool onboardingDone; }
final initialPrefsProvider = Provider<AppPrefs>((ref) => throw UnimplementedError());
final initialLocationProvider = Provider<String>((ref) => Routes.today);
final langProvider = NotifierProvider<LangController, Lang>(LangController.new);           // set(Lang) persists
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
final reducedEffectsProvider = NotifierProvider<ReducedEffectsController, bool>(ReducedEffectsController.new); // auto rules UX §4.5
final routerProvider = Provider<GoRouter>((ref) => buildRouter(ref.watch(initialLocationProvider)));
class App extends ConsumerWidget { const App({super.key}); } // MaterialApp.router; locale; themes; builder wraps MeshBackground+EffectsMode
enum WindowClass { compact, medium, expanded, large, extraLarge; static WindowClass of(BuildContext c); bool get isWide; } // 600/840/1200/1600
class AdaptiveScaffold extends StatelessWidget { const AdaptiveScaffold({super.key, required this.navigationShell}); } // pill / rail / extended rail; Ctrl+1..5, Ctrl+F/K, '?'
class AdaptiveDetail extends StatelessWidget { const AdaptiveDetail({super.key, required this.id,
  required this.master, required this.detail}); final String id; final Widget Function(String id) master, detail; } // wide → master(id), else detail(id)
class StubScreen extends StatelessWidget { const StubScreen({super.key, required this.name}); }
abstract final class ContactActions { static Future<void> callOrCopy(BuildContext context, String phone); } // Android tel:, else copy + snackbar
abstract final class ShareService { static Future<void> shareText(BuildContext context, String text); } // share_plus; web/windows also copy
Future<String?> initRemindersAndGetLaunchRoute(ProviderContainer container) async => null; // stub → M8-D
```
- Routes (`Routes` constants/builders; shell branches 0–4 in this order):

| Path | Screen (file) | Branch |
|---|---|---|
| `/today` | `TodayScreen()` (`features/home/ui/today_screen.dart`) | 0 |
| `/batches`, `/batches/new`, `/batches/:batchId`, `…/edit`, `…/slots`, `…/rollcall/:date`, `…/bulk-add` | `BatchesScreen({String? selectedId})`, `BatchFormScreen({String? batchId})`, `BatchDetailScreen({required String batchId})` via `AdaptiveDetail`, `SlotEditorScreen({required String batchId})` (schedule), `BatchRollCallLauncher({required String batchId, required LocalDate date})` (attendance), `BulkAddScreen({required String batchId})` (extras) | 1 |
| `/students`, `/students/new`, `/students/:studentId`, `…/edit` | `StudentsScreen({String? selectedId})`, `StudentFormScreen({String? studentId, String? initialBatchId})`, `StudentProfileScreen({required String studentId})` | 2 |
| `/fees`, `/fees/s/:studentId`, `/fees/collection` | `FeesScreen({String? selectedStudentId})`, `CollectionScreen()` (dues) | 3 |
| `/more`, `/more/backup`, `/more/backup/review`, `/more/archived`, `/more/left`, `/more/templates/:kind`, `/more/payment-methods`, `/more/holidays`, `/more/diagnostics`, `/more/help` | `MoreScreen()`, `BackupScreen()`, `BackupReviewScreen()`, `ArchivedBatchesScreen()` (batches), `LeftStudentsScreen()` (students), `TemplateEditorScreen({required String kind})`, `PaymentMethodsScreen()`, `HolidayScreen()` (extras), `DiagnosticsScreen()`, `HelpScreen()` | 4 |
| `/rollcall/:occ` (root navigator) | `RollCallScreen({required String occ})` | — |
| `/search`, `/onboarding`, `/reminders/priming` (root) | `SearchScreen()`, `OnboardingScreen()`, `ReminderPrimingScreen()` | — |

Static segments (`new`, `collection`, `s`) are declared before `:param` siblings.
- Entry stubs (signature frozen, body = no-op / `null` / `SizedBox.shrink()`):
```dart
// features/schedule/schedule_entry.dart (M6-A)
Future<int?> showTimePickerSheet(BuildContext context, {required int initialMin, String? title});
Future<int?> showReminderLeadSheet(BuildContext context, {required int? current, required int defaultLead});
class SlotEditorField extends StatefulWidget { const SlotEditorField({super.key, required this.initial, required this.onChanged,
  this.batchId, this.onCheck}); final List<SlotDraft> initial; final ValueChanged<List<SlotDraft>> onChanged;
  final String? batchId; final ValueChanged<SlotCheckResult>? onCheck; }
class BatchScheduleTab extends StatelessWidget { const BatchScheduleTab({super.key, required this.batchId}); final String batchId; }
// features/classes/classes_entry.dart (M6-B)
Future<void> showClassActionsSheet(BuildContext context, {required String occ});
Future<String?> showExtraClassSheet(BuildContext context, {String? batchId, LocalDate? date, int? startMin});
Future<bool> showRescheduleSheet(BuildContext context, {required String occ});
class DayStrip extends StatelessWidget { const DayStrip({super.key, required this.selected, required this.onSelected}); final LocalDate selected; final ValueChanged<LocalDate> onSelected; }
class WeekGrid extends StatelessWidget { const WeekGrid({super.key, required this.weekStart, this.onSelectOcc}); final LocalDate weekStart; final ValueChanged<String>? onSelectOcc; }
// features/batches/batches_entry.dart (M6-C)
Future<bool> showArchiveBatchDialog(BuildContext context, {required String batchId});
Future<bool> showUnarchiveBatchFlow(BuildContext context, {required String batchId});
// features/students/students_entry.dart (M6-D)
Future<String?> showAddStudentToBatchSheet(BuildContext context, {required String batchId});
Future<bool> showEnrollSheet(BuildContext context, {required String studentId});
Future<bool> showMarkLeftDialog(BuildContext context, {required String studentId});
// features/attendance/attendance_entry.dart (M7-A)
Future<void> openRollCallForBatchDate(BuildContext context, {required String batchId, required LocalDate date});
class BatchAttendanceTab extends StatelessWidget { const BatchAttendanceTab({super.key, required this.batchId}); final String batchId; }
class EnrollmentAttendanceSummary extends StatelessWidget { const EnrollmentAttendanceSummary({super.key, required this.studentId, required this.batchId}); final String studentId, batchId; }
// features/payments/payments_entry.dart (M7-B)
Future<String?> showCollectPaymentSheet(BuildContext context, {required String studentId, String? enrollmentId});
class CollectPaymentPanel extends StatelessWidget { const CollectPaymentPanel({super.key, required this.studentId, this.enrollmentId}); final String studentId; final String? enrollmentId; }
Future<void> shareReceipt(BuildContext context, {required String receiptId});
Future<bool> showWaiveDialog(BuildContext context, {required String enrollmentId, required YearMonth month});
class PaymentHistoryList extends StatelessWidget { const PaymentHistoryList({super.key, required this.studentId}); final String studentId; }
// features/dues/dues_entry.dart (M7-C)
Future<void> shareDuesReminder(BuildContext context, {required String studentId});
class BatchFeesTab extends StatelessWidget { const BatchFeesTab({super.key, required this.batchId}); final String batchId; }
// features/reminders/reminders_entry.dart (M8-D) — ReminderPermission is from domain/reminders/reminder_models.dart
final reminderPermissionProvider = FutureProvider<ReminderPermission>((ref) async => ReminderPermission.unsupported);
Future<bool> showReminderPriming(BuildContext context);
Future<void> sendTestReminder(BuildContext context);
Future<void> requestExactAlarms(BuildContext context);
// features/backup/backup_entry.dart (M9-A)
Future<void> runExportBackup(BuildContext context);
Future<void> runImportBackup(BuildContext context);
// features/extras/extras_entry.dart (M9-B)
Future<bool> showOtherIncomeSheet(BuildContext context, {String? studentId});
Future<void> runCsvExport(BuildContext context, {required YearMonth month});
```
- Acceptance: every route renders (stub) in `testScreenMatrix`; theme/language switch instant without restart (**16**, **24** behaviour); phone pill vs desktop rail at the UX §3b breakpoints; deep link `/rollcall/s.x.20261121` reaches the stub; window ≥ 840 shows master+detail for `/batches/:id`.

**M5-B · Derived providers & test harness** — size L — deps: M2, M4
- Files: `lib/app/providers/{core_providers,schedule_providers,dues_providers,attendance_providers,async_combine}.dart`, `test/helpers/{pump_app,fixtures}.dart`, `test/flutter_test_config.dart` (loads HindSiliguri + MaterialIcons via `FontLoader`; `driftRuntimeOptions.dontWarnAboutMultipleDatabases = true`), tests.
```dart
AsyncValue<R> combine2<A, B, R>(AsyncValue<A> a, AsyncValue<B> b, R Function(A a, B b) f);
AsyncValue<R> combine3<A, B, C, R>(AsyncValue<A> a, AsyncValue<B> b, AsyncValue<C> c, R Function(A a, B b, C c) f);
final minuteTickProvider = StreamProvider<int>(...);            // emits every wall-clock minute
final todayProvider = Provider<LocalDate>(...); final nowMinutesProvider = Provider<int>(...);
final weekStartProvider = StreamProvider<int>(...);             // ISO weekday from SettingKeys.weekStart
final schedulesProvider = StreamProvider<List<BatchSchedule>>(...);
class DayClass { const DayClass({required this.occ, required this.batch, required this.subjectName, required this.startMin,
  required this.endMin, this.state, this.occurrence, this.session, this.tally, this.enrolledCount = 0,
  this.originalDate, this.originalStartMin});
  final String occ; final Batch batch; final String subjectName; final int startMin, endMin; final ClassState? state;
  final Occurrence? occurrence; final AttendanceSession? session; final AttendanceTally? tally; final int enrolledCount;
  final LocalDate? originalDate; final int? originalStartMin; bool get cancelled; bool get taken; }
class DayPlan { const DayPlan({required this.date, required this.classes, required this.movedAway});
  final LocalDate date; final List<DayClass> classes; final List<MovedAway> movedAway; }
final dayPlanProvider = Provider.family<AsyncValue<DayPlan>, LocalDate>(...);
final weekPlanProvider = Provider.family<AsyncValue<List<DayPlan>>, LocalDate>(...); // arg = week start
final legacyConflictsProvider = Provider<AsyncValue<List<Clash>>>(...);             // next 28 days
final enrollmentTermsProvider = StreamProvider<List<EnrollmentTerms>>(...);
final paymentFactsProvider = StreamProvider<List<PaymentFact>>(...);
final duesReportProvider = Provider<AsyncValue<DuesReport>>(...);
final studentDuesProvider = Provider.family<AsyncValue<StudentDues?>, String>(...);
final enrollmentDuesProvider = Provider.family<AsyncValue<EnrollmentDues?>, String>(...);
class BatchDuesSummary { const BatchDuesSummary({this.worst, this.count = 0, this.total = 0}); final DueLevel? worst; final int count, total; }
final batchDuesProvider = Provider.family<AsyncValue<BatchDuesSummary>, String>(...);
final attendanceTallyProvider = Provider.family<AsyncValue<AttendanceTally>,
    ({String studentId, String batchId, YearMonth? month})>(...);
class AbsenceAlert { const AbsenceAlert({required this.student, required this.batch, required this.enrollmentId, required this.lastSessionId});
  final Student student; final Batch batch; final String enrollmentId; final String lastSessionId; }
final absenceAlertsProvider = Provider<AsyncValue<List<AbsenceAlert>>>(...);        // excludes dismissed
```
`fixtures.dart`: the Product §6 seed (Physics A / Chem B, slots, fees, Rahim, Karim, Sara…) as domain objects + `seedFakes(...)` populating the M4 fakes, and `FixedClock` helpers (`at('2026-11-05', '10:00')` center time).
- Acceptance: providers recompute on fake-repo emission; `todayProvider` follows `FixedClock`; harness runs 8 matrix cases with zero pending timers.

### M6 — Features wave 1 (5 parallel)

Every feature module: owns the listed files + its fragment; implements stubs from M5-A without changing signatures; all layouts compact→XL per UX §3b; every screen covered by `testScreenMatrix`; desktop shortcuts and right-click menus per UX §3b for its screens.

**M6-A · Schedule editing (`schedule`, `sched`)** — L — deps: M5
- Files: `features/schedule/schedule_entry.dart`, `ui/slot_editor_screen.dart`, `widgets/{time_picker_sheet,slot_editor_field,batch_schedule_tab,reminder_lead_sheet}.dart`, `controllers/slot_editor_controller.dart`.
- Acceptance: time picker requires a period first (6 Product periods; en AM/PM), 5-min "অন্য মিনিট", desktop typed input parses "7:30 pm", "19:30", "৭:৩০ সন্ধ্যা"; slot editor "সব দিনে একই সময়", per-day multiple slots, live sentence, **live** clash card with fixes (**17, 18, 20, 21**), disabled save with reason, "কবে থেকে?" on save; reminder lead sheet stores null / 5…60 / custom 1–180 / 0 off, row text per UX §2h (**22** UI path).

**M6-B · Class actions & week (`classes`, `cls`)** — L — deps: M5
- Files: `features/classes/classes_entry.dart`, `widgets/{class_actions_sheet,extra_class_sheet,reschedule_sheet,day_strip,week_grid}.dart`, `controllers/*`.
- Acceptance: sheet titled "শুধু {date}" (+ time when the batch has 2+ classes that day); cancel with undo snackbar + "অভিভাবকদের জানান" share (cancel message via `cls` ARB); reschedule/extra with live clash card and suggestions (**17, 19, 25**); restore; week grid 7 cols × auto hour range, cancelled dashed, moved ghost, keyboard arrows/Enter/N/[ ].

**M6-C · Batches & subjects (`batches`, `batch`)** — XL — deps: M5
- Files: `features/batches/batches_entry.dart`, `ui/{batches_screen,batch_detail_screen,batch_form_screen,archived_batches_screen}.dart`, `widgets/*`, `controllers/*`.
- Acceptance: subjects never a destination (pick-or-create in form); billing radio cards with Product wording, default = last used; fee change asks "কোন মাস থেকে?" + partial-month warning (**11**); detail tabs শিক্ষার্থী (own) · হাজিরা (`BatchAttendanceTab`) · বেতন (`BatchFeesTab`) · সময়সূচি (`BatchScheduleTab`); archive dialog with LBM (**9**), unarchive flow (**21**); delete behind secondary menu with impact numbers; desktop list‖detail‖context.

**M6-D · Students (`students`, `stu`)** — XL — deps: M5
- Files: `features/students/students_entry.dart`, `ui/{students_screen,student_profile_screen,student_form_screen,left_students_screen}.dart`, `widgets/*`, `controllers/*`.
- Acceptance: search-first add sheet (existing match → "এই ব্যাচে যোগ করুন"); duplicate guard; FBM default via cutoff (**6**); enroll in second batch (**7**); mark Left with per-enrollment LBM (**8**), rejoin with gap-waive prompt; profile: call/remind buttons, one card per enrollment with `MonthStrip`, `EnrollmentAttendanceSummary`, `[টাকা নিন]` → `showCollectPaymentSheet`, `PaymentHistoryList`; photo ≤ 200 KB (image_picker 512 px, quality 70); desktop data table (UX §3b columns).

**M6-E · Settings & More (`settings`, `set`)** — L — deps: M5
- Files: `features/settings/ui/{more_screen,template_editor_screen,payment_methods_screen,diagnostics_screen,help_screen}.dart`, `widgets/*`, `controllers/*`.
- Acceptance: exactly the Product §3.12 rows (+ কম ইফেক্ট), two-line rows with current value, instant save; theme 3-segment with swatches (**24**); language switch (**16**); reminder rows call `reminders_entry` (switch on → `showReminderPriming`, permission chip, test button; web note); template editor with placeholder chips, live preview, "ডিফল্টে ফেরান"; payment methods show/hide + custom; backup rows call `backup_entry` + last-backup age; diagnostics shows `webStorageReport`, device name, version, and the Android uninstall warning; desktop index ‖ content.

### M7 — Features wave 2 (3 parallel)

**M7-A · Attendance (`attendance`, `roll`)** — XL — deps: M6 merged
- Files: `features/attendance/attendance_entry.dart`, `ui/{roll_call_screen,batch_roll_call_launcher}.dart`, `widgets/{roll_row,session_chooser_sheet,batch_attendance_tab,enrollment_attendance_summary}.dart`, `controllers/roll_call_controller.dart`.
- Acceptance: all-present default, tap toggles P↔A, trailing দেরি button, long-press → ছুটি (F21)/নোট, live counts header, sticky save "(৩০ জন)", draft survives kill (`rollcall_draft:<occ>`), autosave after first save, leave guard, past-day banner, future disabled, session chips/chooser for 2+ classes (**25**), unscheduled → ad-hoc note + extra (Product §3.6), cancelled → note + `removeCancel`, archived read-only, delete session; desktop 2–4 column-major roster + summary pane + keys (UX §2b). Scenarios **12, 23 (screen part), 25**.

**M7-B · Payments (`payments`, `pay`)** — L — deps: M6 merged
- Files: `features/payments/payments_entry.dart`, `widgets/{collect_payment_sheet,collect_payment_panel,allocation_editor,receipt_preview,payment_history_list,waive_dialog}.dart`, `controllers/collect_payment_controller.dart`, `receipt_text.dart`.
- Acceptance: prefill per Product §3.4/§1 #35; button label repeats months + amount; method remembers last per student; partial inline note; manual split cannot exceed remaining; > 12-month overflow message; snackbar "৳৮০০ জমা হয়েছে" + রসিদ পাঠান + undo; receipt from template with `{remaining_line}` (**5**), in-app preview renders "✓" as `Icons.check`; edit/delete receipt with confirm; waive/unwaive (**10**). Scenarios **4, 5, 7, 10**.

**M7-C · Dues & collection (`dues`, `dues`+`coll`)** — XL — deps: M6 merged
- Files: `features/dues/dues_entry.dart`, `ui/{fees_screen,collection_screen}.dart`, `widgets/{dues_row,dues_group_header,dues_filters,batch_fees_tab,reminder_walkthrough}.dart`, `controllers/*`, `reminder_text.dart`.
- Acceptance: severity-sorted groups (**3**), filters (all / overdue / this month / batch), grey collapsed "ছেড়ে যাওয়া / আর্কাইভ" group (**8, 9**), Call (`ContactActions`), Remind (`ShareService`, template, all Bangla digits / English Latin, **14**), "আজ মনে করানো হয়েছে" via `reminded:<date>`, bulk walk-through; desktop table ‖ `CollectPaymentPanel`; collection summary §3.7 both blocks + by method + other-income line (F22 if any) + outstanding → dues filtered to month; empty states. Scenarios **1–4, 8, 9, 14**.

### M8 — Features wave 3 (4 parallel)

**M8-A · Today (`home`, `today`)** — XL — deps: M7 merged
- Files: `features/home/ui/today_screen.dart`, `widgets/{hero_class_card,dues_card,timeline,collection_tile,attendance_today_tile,absence_alerts_tile,backup_nudge_tile,quick_actions,recent_payments_tile,conflict_banner}.dart`, `controllers/*`.
- Acceptance: hero next/current class + countdown + pill → roll call; empty/all-done/no-batches states; dues card with `EscalationBar` and level legend → `/fees`; day strip + timeline (states, ✓ x/y, cancelled struck, moved "→ …", extra tag) (**19, 25**); bento spans per UX §3b for expanded/large/XL, every row sums to 12; দিন/সপ্তাহ toggle → `WeekGrid` on ≥ 840; F16 alerts with Call + dismiss (**13**); F18 nudge rule; "সময়ের সংঘাত" banner from `legacyConflictsProvider` (**21**); reminders-window < 3 days hint; language chip বাং|EN.

**M8-B · Search (`search`)** — M — deps: M7 merged
- Acceptance: name / roll / phone / guardian phone with Bangla or ASCII digits, results as you type < 1 s for 300 students (Product §6 metric), grouped students/batches, recent searches (local meta `search_recent`), Ctrl+F/Ctrl+K.

**M8-C · Onboarding (`onboarding`, `onb`)** — M — deps: M7 merged
- Acceptance: 4 steps per UX §2a + center name (§1 #27); first batch uses `SlotEditorField`; quick-add loop keeps focus on name; step 4 priming via `showReminderPriming`; sets `onboardingDone`; one-time coach mark on Today. Contract DoD core flow reachable unaided.

**M8-D · Reminders (`reminders`, `remind`)** — L — deps: M7 merged
- Files: `lib/data/notifications/**`, `lib/app/services/reminder_bootstrap.dart` (body), `features/reminders/{reminders_entry.dart, ui/reminder_priming_screen.dart, reminder_service.dart, reminder_texts.dart}`.
```dart
abstract interface class NotificationGateway {
  Future<void> init({required void Function(String payload) onTap}); Future<String?> launchPayload();
  Future<ReminderPermission> permission(); Future<bool> requestPermission(); Future<bool> requestExact();
  Future<void> replaceAll(List<ScheduledNotice> notices); Future<void> cancelAll();
  Future<void> showNow({required String title, required String body}); }
class ScheduledNotice { const ScheduledNotice({required this.id, required this.fireAtUtc, required this.title,
  required this.body, required this.payload, required this.actionLabel}); final int id; final DateTime fireAtUtc;
  final String title, body, payload, actionLabel; }
final notificationGatewayProvider = Provider<NotificationGateway>((ref) => createNotificationGateway()); // conditional import io/web
final reminderServiceProvider = Provider<ReminderService>(...); // kept alive by initRemindersAndGetLaunchRoute via
// container.listen(reminderServiceProvider, (_, __) {}); listens to schedules/settings/lang; debounce 2 s replan; AppLifecycleListener onResume
```
- Acceptance: scenarios **22, 23** (tap → `/rollcall/<occ>` warm and cold; cancelled after fire → batch schedule with note), Product §3.11 texts in app language, recompute on language change (**16**), global off → none scheduled; exact/inexact fallback + Settings disclosure; Windows init constants from `app_info.dart`; web `ReminderTicker` in-app banner only; permission asked at most once per app version.

### M9 — Backup UI, SHOULDs, release (3 parallel)

**M9-A · Backup (`backup`)** — L — deps: M8 merged
- Acceptance: export one tap → save/share (`backupFileName`), "keep this file private" note, `lastExportAt`; import → `/more/backup/review` full screen: backup info, headline, entity table Added/Updated/Deleted + "আপনার নতুন তথ্য রাখা হবে: N", ≤ 3 samples per bucket, deletions red and first, merge-created conflicts red, older-backup banner, 0 changes → disabled apply, invalid file message; apply → result + "আগের অবস্থায় ফেরান"; safety copies list (3) in Backup screen; overfilled months flag; reminders replanned after import. Scenario **15** end-to-end in UI test with fakes.

**M9-B · SHOULD pack (`extras`, `extra`)** — L — deps: M8 merged. Build in this order; drop from the bottom if time runs short (Product §2): **F20** bulk quick-add (`BulkAddScreen`) · **F22** other income sheet (+ shows in collection & receipt) · **F28** holiday closure (`HolidayScreen`, `cancelRange`/undo, reminders replan) · **F23** CSV export (UTF-8 BOM, students/payments/attendance of a month, `ShareService`/`BackupFiles.save`). (F16/F18/F21 are already inside M7-A/M8-A.)

**M9-C · Release engineering** — S — deps: none (CI files only; Lead reviews)
- `release.yml` (tag `v*`, Arch §6.5), `pages.yml` (opt-in `ENABLE_PAGES`), `screens` job blocking on exceptions, `keystore.yml` run checklist, version `1.0.0+run_number`.

After M9: Lead-run **hardening** pass (QA/naive-tester fixes only, no new features).

---

## 6. Compile-safety checklist (self-check before every handback)

**Dart & imports**
1. Every symbol used is imported — scan each file top-down for types, extension getters (`context.l10n`, `context.fmt`, `context.aurora`), and provider names. Imports are `package:attendance_alamin/...` only.
2. No `dart:io` under `lib/` (except `*_native.dart`); use `kIsWeb` / `defaultTargetPlatform` from `package:flutter/foundation.dart`.
3. `const` only when every argument is const: never `const Text(context.l10n.x)`, never `const` around a widget taking a non-const field. Mark constructors `const` where all fields are final.
4. Null safety: no `!` on values that can legitimately be null (`state.pathParameters['id']!` is fine; repository `getById` results are not). Prefer `if (x case final v?)` or early returns.
5. `sealed` only when all subclasses are in the same file (that is why `AppException` is `abstract`). `switch` over sealed/enum types must be exhaustive — no missing cases, no unreachable `default` warnings.
6. Records: `(int, int)` positional access `.$1/.$2`; named records `({String studentId, …})` must match exactly at every call site.
7. Web ints: no 64-bit tricks; `fnv1a31` uses 16-bit partial products then `& 0xFFFFFFFF`; epoch ms fit in doubles.
8. No `DateTime.now()` outside `clock.dart`; no local `DateTime` conversion (`toLocal`) anywhere.
9. Flutter 3.47 APIs: `Color.withValues(alpha:)` (not `withOpacity`), `WidgetStateProperty` (not `MaterialStateProperty`), `PopScope(onPopInvokedWithResult:)` (not `WillPopScope`), `MediaQuery.textScalerOf` (not `textScaleFactor`), `ColorScheme.surface*` (no `background`), `DropdownButtonFormField(initialValue:)`. No `BackdropGroup`. Use only Material Icons (no Unicode `✓`, `⚠` glyphs in Text).

**drift**
10. `part 'app_database.g.dart';` in `app_database.dart` only; tables in `tables/*.dart` are imported, not `part`s. Class `AppDatabase extends _$AppDatabase`.
11. Use the generated names in M3-A's table (`SubjectRow`, `SubjectsCompanion`, `$SubjectsTable`, getter `subjects`). Check the `generated-sources` artifact before guessing.
12. Companions: `SubjectsCompanion(name: Value(n))` for updates; `SubjectsCompanion.insert(...)` takes non-nullable, no-default columns as **required named args without `Value`** and the rest as `Value(...)`. Nullable column set to null: `Value(null)`; leave untouched: omit / `Value.absent()`. `Value` and `Constant` come from `package:drift/drift.dart`.
13. Queries: `(select(t)..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull()`; `.watch()` for streams; `transaction(() async { … })` returns the inner future — `await` it. No joins (§2.6). `customSelect` returns `QueryRow`; read `row.data` or `row.read<int>('col')`.
14. CHECKs via `@override List<String> get customConstraints => ["CHECK (status IN ('P','A','L','E'))"];` (double-quoted Dart strings).

**Riverpod 3**
15. No `StateProvider`, `StateNotifier`, `AutoDisposeNotifier`, `FamilyNotifier`, `ProviderRef<T>`, `valueOrNull`. `Notifier`/`AsyncNotifier` + constructor arg for families. `ref.mounted` after awaits. `Override` from `package:flutter_riverpod/misc.dart`. Widgets: `ConsumerWidget` (`build(BuildContext context, WidgetRef ref)`) or `ConsumerStatefulWidget`/`ConsumerState`.
16. Do not call `ref.read(xProvider.notifier)` inside `build` to mutate; mutate from callbacks.

**go_router 18**
17. Top-level paths start with `/`; nested `GoRoute(path: 'edit')` has no leading slash. `state.pathParameters['batchId']!`. Navigate with `context.go(Routes.batch(id))` / `context.push(...)`; branch switch `navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex)`. Full-screen routes use `parentNavigatorKey: rootNavigatorKey`. Never put ids in query strings.

**l10n**
18. Every new string exists in **both** fragments of **your** prefix; bn has `@key` with `description` and String placeholders; en uses identical placeholder names; no `{`/`}` other than placeholders; keys match `^<prefix>[A-Z]`. Generated getter for a placeholder key is a **method**: `l10n.rollSaveButton(fmt.number(n))`.
19. No hard-coded user-visible text, including `Semantics(label:)`, `Tooltip`, snackbars and share texts.

**Tests & CI**
20. Every new screen in `testScreenMatrix`; every engine rule has a table case; widget tests use fakes, not drift; no real timers left pending (`await tester.pumpAndSettle()` or explicit `pump(Duration)`).
21. Ran mentally: `check_domain_purity.sh` rules, `merge_arb.py` rules, no colour literals, no `print`.
22. PR description lists files, scenarios covered, contract deviations (or "none").

---

## 7. Evaluation-panel focus per milestone

| Milestone | Panel looks at |
|---|---|
| M0 | All four CI jobs green; web artifact runs from `localhost:8080` with Bangla shaping; APK installs; `apply.py --verify` idempotence; fonts hashes |
| M1 | Contract fidelity (names/types exactly as §5); `AppFormat` outputs vs Product §5 strings; purity script |
| M2 | Scenario tables 1–13, 15, 17–22, 25 pass at engine level; edge cases (rollover, half-open intervals, LWW ties); no Flutter imports |
| M3 | Schema vs Arch §3.2 + §1 amendments; CHECKs; web DB opens (storage report not `inMemory` on Chromium); contrast test thresholds; ARB merge failures are actionable |
| M4 | Sync stamping on every write; clash checks inside repos; transactionality (roll call, receipt, import); widget legibility law, OD/L5 shapes, reduced-effects path |
| M5 | Route table completeness; adaptive breakpoints (no centred phone column ≥ 840); instant theme/language; harness reliability (8-case matrix) |
| M6 | Flows M7 and setup: subject→batch→student in Bangla; conflict UX (17–21) never feels like a bug; desktop list‖detail density |
| M7 | Flows M1/M2/M3: roll call ≤ 6 taps/20 s; payment ≤ 30 s; dues sorted/grey group; share texts digits per language (14) |
| M8 | Today cockpit both themes × sizes, bento alignment; reminders 22/23 on Android (app closed, reboot), Windows toast; onboarding by naive tester |
| M9 | Backup 15 end-to-end on phone↔PC; change summary understood by naive tester; SHOULD items vs drop order; release artifacts signed with the real keystore |

---

## 8. Human / Lead steps (not builder work)

1. After M0 merge: dispatch `bootstrap.yml`; then dispatch `ci.yml` on `main` (bootstrap's push does not trigger it).
2. After M3 merge: dispatch `commit-generated.yml` to commit `drift_schemas/drift_schema_v1.json`; from then on any schema change without a `schemaVersion` bump fails `check`.
3. Before the first APK reaches the teacher (latest M8): run `keystore.yml`, copy the four secrets, keep an offline copy, delete the artifact (Arch §6.3).
4. Optional: set repo variable `ENABLE_PAGES=true` (paid plan) or use the local `python -m http.server` recipe (Arch §6.4) for web checks.
5. Confirm or replace the app display name (§1 #36) before M9 release.
