# Phase 2: Architecture (Architect)

> **Rev 2 (Gate 1, 2026-11-20).** Adds contract items 8–11: theming (4C), schedule engine (4A), reminders (4B), settings scope (3.8), new tables, CI patches and risks 7–10. `batches.weekdays/start_min/end_min` are replaced by `batch_slots`. **Rev 3:** multiple classes per batch per date are allowed, and attendance, reminders and routes are keyed by **occurrence id** (3.2a), not (batch, date).

Binding input: `00-contract.md`. This document records decisions. Every version below was checked on **2026-11-20** against pub.dev, the Flutter release feed and GitHub. Builders treat it as law. Changing it needs a written amendment here.

---

## 0. Decisions at a glance

| Area | Decision |
|---|---|
| Flutter | **3.47.9 stable (Dart 3.13.7)**, pinned in CI. 3.50.x is not used yet (see 1.1). |
| State | **flutter_riverpod 3.5.0**, hand-written providers, **no riverpod_generator** |
| Routing | **go_router 18.1.4** |
| DB | **drift 2.35.4 (exact pin) + drift_flutter 0.3.1**. sqlite3 3.x native via build hooks. Web via `sqlite3.wasm` + `drift_worker.js` from the drift-2.35.4 GitHub release, downloaded and checksum-verified in CI. |
| Web storage | No COOP/COEP headers. drift picks IndexedDB (`sharedIndexedDb`, or `unsafeIndexedDb` on Android Chrome). This works on GitHub Pages and any static server. |
| Codegen | drift_dev + build_runner and `flutter gen-l10n`, all **run in CI**. Generated files are **not committed** and are uploaded as a CI artifact for inspection. |
| i18n | gen-l10n with ARB, **`app_bn.arb` is the template**. All digits, months and money go through our own `AppFormat`; intl is not used for display. |
| Snapshot | **Gzipped canonical JSON** (`*.ambackup`), with SHA-256 and schema version. Merge is record-level LWW with tombstones. |
| Dues | Pure-Dart `lib/domain/dues/` with no Flutter or drift imports. A CI grep enforces this. |
| Font | Hind Siliguri fork @ `247a09f`. **TTFs committed** under `assets/fonts/hind_siliguri/` with OFL. |
| CI | `ci.yml` (codegen, analyze, test, then build web/apk/windows), `pages.yml` (opt-in), `bootstrap.yml`, `keystore.yml`, `release.yml` |
| Android signing | Generate a **real release keystore once** (CI one-shot, then repo secrets). Never ship debug-signed APKs to the teacher. |
| Schedule | Recurring weekly `batch_slots` plus per-date `schedule_exceptions` (cancel / reschedule / extra). A pure-Dart `lib/domain/schedule/` engine expands them into effective occurrences and checks conflicts. |
| Reminders | **flutter_local_notifications 23.0.3** + **timezone 0.11.2**. Times are computed in a fixed center offset (UTC+6) and scheduled as UTC instants. A **rolling 14-day window** is re-planned on start, on resume and on change. |
| Reminders by platform | Android: OS alarms that fire with the app closed, exact if the user grants it, otherwise inexact. Windows: OS-scheduled toasts that fire with the app closed, but tapping one only navigates if the app is running. **Web: no scheduling; in-app only while the tab is open.** |
| Android build | AGP **9.1.1**, compileSdk **37**, core library desugaring `desugar_jdk_libs:2.1.4`. Applied by an idempotent patch script that CI also verifies. |
| Theme | `ThemeMode` system / light / dusk, stored device-local. Tokens live in `lib/app/theme/`, with 3 `ThemeExtension`s (gradients, severity, attendance). CI runs a WCAG contrast unit test, both-theme widget tests and a screenshot artifact. |

---

## 1. Stack

### 1.1 Flutter pin
- `subosito/flutter-action@v2` with `flutter-version: 3.47.9`, `channel: stable`, `cache: true`.
- **Why not 3.50.1:** 3.50.0 shipped 2026-11-11 and 3.50.1 today. 3.50 **deprecates `package:flutter/material.dart` in favour of `package:material_ui`**. Every doc, sample and model prior uses the old import. With no local compiler, the boring and documented API wins. After v1 ships, upgrade to 3.50.x using `dart fix --apply --code=migrate_design_widgets` in a dedicated PR.
- All chosen packages support 3.47.9. go_router needs Flutter >=3.44 and riverpod needs Dart ^3.12.
- `pubspec.yaml`: `environment: sdk: ^3.13.0`, `flutter: ">=3.47.0"`.
- `pubspec.lock` **is committed**. It is created by `bootstrap.yml`, see section 6.
- Dart package name `attendance_alamin`, org `com.imrudra`, applicationId `com.imrudra.attendance_alamin`. **Never change these after the first install.** Changing them breaks upgrades and orphans the data.

### 1.2 Dependencies (exact constraints)
```yaml
dependencies:
  flutter: {sdk: flutter}
  flutter_localizations: {sdk: flutter}
  intl: any                 # version is pinned by flutter_localizations; never pin it ourselves
  flutter_riverpod: ^3.5.0
  go_router: ^18.1.4
  drift: 2.35.4             # EXACT: must match web/sqlite3.wasm + web/drift_worker.js
  drift_flutter: ^0.3.1
  path_provider: ^2.1.6
  uuid: ^4.6.0
  archive: ^4.7.1           # pure-Dart gzip (works on web)
  crypto: ^3.0.8            # sha256
  file_picker: ^13.4.0      # pickFiles + saveFile(bytes:) on android/windows/web
  share_plus: ^13.3.1       # share reminder text / backup file
  url_launcher: ^6.3.3      # tel: links
  image_picker: ^1.2.4      # optional student photo
  package_info_plus: ^10.2.2
  flutter_local_notifications: ^23.0.3  # android+windows scheduling; web = show() only
  timezone: ^0.11.2                    # TZDateTime for zonedSchedule (we pass UTC instants)
dev_dependencies:
  flutter_test: {sdk: flutter}
  flutter_lints: ^6.0.0
  drift_dev: 2.35.3         # latest drift_dev; same minor as drift
  build_runner: ^2.17.1
```
Do **not** add `flutter_timezone`, `tray_manager` or `window_manager`. We use a fixed center offset (see 3.1), and the latest `tray_manager` / `window_manager` (0.9.0 / 0.7.0) require Flutter 3.50. Do **not** add `sqlite3_flutter_libs`. It is `0.6.0+eol`, and sqlite3 3.x bundles SQLite through build hooks. Do not add freezed, json_serializable, riverpod_generator or equatable. Each adds codegen or magic we cannot debug locally.

### 1.3 State management: Riverpod 3 without codegen
- Use `Provider` for singletons (db, repositories, clock, deviceId), `StreamProvider` / `StreamProvider.family` for drift `watch()` queries, and `NotifierProvider` / `AsyncNotifierProvider` for screen controllers and forms.
- Riverpod 3 family notifier pattern: `NotifierProvider.family<C, S, Arg>(C.new)`. The argument goes in the constructor, and `build()` takes no arguments.
- Legacy `StateProvider` / `StateNotifierProvider` are banned. They only exist in `package:riverpod/legacy.dart`.
- Use `ProviderScope(retry: (_, __) => null, ...)`. This turns off Riverpod 3's automatic retry, so DB and import errors surface once and are not retried silently.
- Check `ref.mounted` after every `await` before setting state.
- Tests use `ProviderContainer(overrides: [...])` with an in-memory DB and a fixed `Clock`.

### 1.4 Routing: go_router 18
- One `GoRouter` in `lib/app/router.dart`, using a `StatefulShellRoute.indexedStack` with 4 tabs: Home, Batches, Students, More. Detail routes are nested.
- IDs go in path params (`/students/:id`) and never in query strings.
- No redirects or guards are needed, because there is no auth.
- Web uses the default path URL strategy. Deep reload works on GitHub Pages because `404.html` is a copy of `index.html` (see 6.4).

### 1.5 DB layer decision: drift (chosen) vs sqflite family
| | drift 2.35.4 + drift_flutter | sqflite + sqflite_common_ffi + _web |
|---|---|---|
| Web | Official, documented fallbacks (OPFS, then IndexedDB, then memory). `onResult` reports the chosen storage. | Separate tekartik web package, needs its own `setup` step, less documented |
| Windows | Same API through sqlite3 hooks | Needs a separate ffi init path |
| Reactive UI | `watch()` streams, built in | Manual |
| Typed queries / migrations | Yes, and `Migrator` helpers | Raw SQL maps |
| Cost | build_runner codegen | No codegen |

**Choice: drift.** It has one API on all three targets, reactive streams that suit Riverpod, and the best web story. Codegen runs only in CI, and the generated names are deterministic and documented (`Students` table → `Student` row class + `StudentsCompanion`).

### 1.6 drift web setup (exact)
1. `web/sqlite3.wasm` and `web/drift_worker.js` are **gitignored**. The CI step `tool/fetch_web_assets.sh` downloads them from the **same drift release as the pinned drift version** and verifies SHA-256:
   ```
   https://github.com/simolus3/drift/releases/download/drift-2.35.4/sqlite3.wasm     sha256 e7451780e78c56ff864fe9317a0fbcd6aeb2e8de3beba7f5efd963202f7ec3d9
   https://github.com/simolus3/drift/releases/download/drift-2.35.4/drift_worker.js  sha256 48c950cd8e3bc3cddb34816c860e228be8832bef07a297c27e9907c057ff8162
   ```
   The script fails the build if the version is not `2.35.4` in `pubspec.lock` or if a checksum mismatches. Bumping drift means updating the version, both URLs and both hashes in one PR.
2. Open the connection. This is the only place platform branches:
   ```dart
   QueryExecutor openConnection() => driftDatabase(
     name: 'attendance_alamin',
     native: DriftNativeOptions(
       databaseDirectory: getApplicationSupportDirectory, // NOT Documents (OneDrive on Windows)
     ),
     web: DriftWebOptions(
       sqlite3Wasm: Uri.parse('sqlite3.wasm'),      // relative → respects <base href>
       driftWorker: Uri.parse('drift_worker.js'),
       onResult: (r) => webStorageReport.value = r, // surface r.chosenImplementation + r.missingFeatures
     ),
   );
   ```
3. If `chosenImplementation` is `inMemory`, show a **red, permanent banner**: "এই ব্রাউজারে ডেটা সংরক্ষণ হবে না / Data will NOT be saved in this browser". A Settings, then Diagnostics screen shows the storage implementation name.
4. On web startup, call `navigator.storage.persist()` through `package:web` in a `web_only.dart` conditional import. This lowers the risk that the browser evicts the IndexedDB data.
5. **Headers: none required, none used.** Without COOP/COEP, drift falls back as follows:
   - Desktop Chrome, Edge and Firefox get `sharedIndexedDb`, which is persistent and safe across tabs.
   - Android Chrome has no SharedWorker, so it gets `unsafeIndexedDb`. This is persistent but must be used in one tab only, which is fine for verification.
   - OPFS would need COOP/COEP. **GitHub Pages cannot set headers**, so it is out of scope.
   - Do not add `coi-serviceworker` hacks.
   - Do not build with `--wasm`. The JS build with CanvasKit is the default and is what we ship.
6. Build web with `--no-web-resources-cdn`. CanvasKit is then served from our origin, not gstatic, so the app loads offline or on flaky networks.

---

## 2. Localization

- Set `flutter: generate: true` in pubspec. The `l10n.yaml` file:
  ```yaml
  arb-dir: lib/l10n/arb
  template-arb-file: app_bn.arb
  output-dir: lib/l10n/generated     # gitignored, produced by `flutter gen-l10n` in CI
  output-class: AppLocalizations
  nullable-getter: false
  required-resource-attributes: true # every key needs @description
  ```
- Supported locales are `[Locale('bn'), Locale('en')]`, with **default `bn`**. The chosen locale is device-local in `local_meta.locale` and is never synced. The delegates are `AppLocalizations`, `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations` and `GlobalCupertinoLocalizations`. Material ships `bn`.
- **Rule: ARB placeholders that carry numbers, dates or money are `String`.** They are pre-formatted by `AppFormat`. No ICU `plural` and no `NumberFormat` / `DateFormat` placeholders. The reason is that intl's `bn` data (digit and month spellings) is not something we control or can test locally.
- `lib/core/format/app_format.dart` is pure Dart and unit-tested:
  - `digits(String s, Lang l)` maps ASCII 0-9 to ০-৯ when `l == bn`. `toAsciiDigits()` does the reverse for **all input**: phone numbers, amounts and search typed with Bangla digits are normalized before validation and storage. **The DB always stores ASCII digits.**
  - `money(int taka, Lang l)` gives `৳` + South-Asian grouping (`1,50,000`) and then `digits()`. Examples: `৳১,৫০০` and `৳1,500`. Amounts are whole taka (INTEGER) with no paisa.
  - `monthName(int m, Lang l)` and `weekdayName(int isoWeekday, Lang l)` read **from ARB keys** (`month1`…`month12`, `weekday1`…`weekday7`), so the spelling is product-owned. The bn spellings are জানুয়ারি, ফেব্রুয়ারি, মার্চ, এপ্রিল, মে, জুন, জুলাই, আগস্ট, সেপ্টেম্বর, অক্টোবর, নভেম্বর, ডিসেম্বর.
  - `date(LocalDate d, Lang l)` gives "৫ নভেম্বর ২০২৬" or "5 Nov 2026". `monthYear(YearMonth)` gives "নভেম্বর ২০২৬". `time(int minutes, Lang l)` gives "বিকাল ৪:৩০" or "4:30 PM", with bn day-part words from ARB.
  - `ordinalDay` is not needed. Use "৫ তারিখ" via an ARB string with a `{day}` String placeholder.
- Material date pickers use `showDatePicker(locale: current)`. Their Bangla digit output comes from intl and is accepted as is. All our own text goes through `AppFormat`.
- A CI test asserts that `app_en.arb` and `app_bn.arb` have identical key sets.

### Font
- Source: fork `bdeshi/Hind-Siliguri`, commit **`247a09fb574ba113068300e7118baab0daa2ad21`**, folder `TTF/`. The fork fixes the malformed `১` glyph in Regular, Medium and SemiBold. Available weights are Light, Regular, Medium, SemiBold and Bold.
- **Decision: commit 4 TTFs** (Regular 400, Medium 500, SemiBold 600, Bold 700, about 1.1 MB) plus `OFL.txt` (copied from the fork's `LICENSE.md`) to `assets/fonts/hind_siliguri/`. Light is skipped because thin Bangla is hard to read.
- Commit, not a CI fetch, because the fonts are deterministic, small and license-compatible. A one-time `tool/fetch_fonts.sh`, kept for provenance, downloads `https://raw.githubusercontent.com/bdeshi/Hind-Siliguri/247a09fb574ba113068300e7118baab0daa2ad21/TTF/HindSiliguri-<Weight>.ttf` and verifies these SHA-256 hashes (measured 2026-11-20). CI re-checks them with `sha256sum -c`:
  - Regular `c6578418954aff5ea65e15249942eabac024fe7ec6a701787eb4940dd14660e6`
  - Medium `f95780e0f46f76dbae688ac117081a493876864984574c33529a681153cf4840`
  - SemiBold `87dfcce4ba4f9c7054ed475d8648828ef23327d8e497fae9f701292d292e9a72`
  - Bold `d135765781d1a4aebc7dd4a2af221427ec8689060121d8a48b19bca3eeb3977e`
- pubspec: `fonts: - family: HindSiliguri`, with the four assets at `weight: 400/500/600/700`. Keep `uses-material-design: true` so the icon font is bundled.
- Verified coverage (fontTools): Bengali block including `৳` U+09F3 and ০-৯, Latin, ZWJ/ZWNJ, `।`, `–` and `…`, with GSUB scripts `beng` and `bng2`. There is **no `✓`**, so use Material Icons, never Unicode symbols.
- Metrics: ascent 1116, descent 501, UPM 1000, so the natural line height is about 1.62.
- `ThemeData(fontFamily: 'HindSiliguri')` applies globally, for both English and Bangla. One family means identical shaping on Android, Windows and web, and **CanvasKit never needs to fetch Noto fallbacks from Google**.

---

## 3. Data model (SQLite via drift)

### 3.1 Conventions (all synced tables)
| Column | Type | Rule |
|---|---|---|
| `id` | TEXT PK | UUID v4. **Natural-key tables use UUID v5** (namespace `6f1c2b7e-1d0a-4c55-9b7e-2a4e1f0c9d31` + key string), so two devices that create "the same" row produce the same id. |
| `created_at` | INTEGER | UTC epoch ms |
| `updated_at` | INTEGER | UTC epoch ms, set on **every** write as `max(now, old.updated_at + 1)`. This makes it monotonic per row despite clock skew. |
| `deleted_at` | INTEGER NULL | Tombstone. **Rows are never hard-deleted.** All reads filter `deleted_at IS NULL`. |
| `device_id` | TEXT | Device of the last writer |
| `rev` | INTEGER | Starts at 1 and goes up on every write. It is the LWW tie-breaker. |

Other rules:
- Calendar dates are `TEXT 'YYYY-MM-DD'` (local date, no time zone).
- Months are `INTEGER yyyymm` (e.g. `202611`).
- Times are `INTEGER` minutes since midnight.
- Money is `INTEGER` whole taka.
- Enums are short `TEXT` with a `CHECK` constraint.
- Foreign keys are declared with **no `ON DELETE CASCADE`**. `PRAGMA foreign_keys = ON` is set in `beforeOpen`.
- Writes go only through repositories, which stamp the sync columns. Raw `update()` calls from the UI are forbidden.
- **Time zone is explicit.** Every wall-clock value (dates, `*_min`) is in **center local time**, defined as the fixed offset `center_utc_offset_min = 360` (Asia/Dhaka, UTC+6, no DST since 2009). The `Clock` provider gives `nowUtc`, and `today = LocalDate.fromUtc(nowUtc, offset)`. Conversion to an instant is `toUtc(date, minutes, offset)`. **Nothing reads `DateTime.now()` or the device or CI time zone.** This keeps tests identical on UTC CI runners and on phones set to a wrong zone.

### 3.2 Synced tables
| Table | Columns (plus sync columns) | Keys / indexes |
|---|---|---|
| `subjects` | `name TEXT NOT NULL`, `sort_order INT DEFAULT 0`, `archived_at INT NULL`, `notes TEXT NULL` | idx(`deleted_at`,`sort_order`) |
| `batches` | `subject_id TEXT FK→subjects`, `name TEXT`, `billing_type TEXT CHECK IN('prepaid','postpaid')`, `reminder_lead_min INT NULL CHECK(reminder_lead_min BETWEEN 0 AND 720)` (NULL means use the global default), `archived_at INT NULL`, `sort_order INT`, `notes TEXT NULL` | idx(`subject_id`). The schedule lives in the next two tables. |
| `batch_slots` | `batch_id FK`, `weekday INT CHECK 1..7` (ISO, Mon=1, Fri=5, Sat=6), `start_min INT`, `end_min INT`, `CHECK(0 <= start_min AND start_min < end_min AND end_min <= 1440)`, `valid_from TEXT NULL`, `valid_to TEXT NULL` (inclusive dates). id is UUID v4. | idx(`weekday`), idx(`batch_id`). Each slot is one weekly recurring class. A batch has 1 or more, and **any number per weekday** (e.g. morning + evening in exam season). There is **no uniqueness on (batch, weekday)**. The only constraint is the engine's `[start,end)` no-overlap rule, which also applies between slots of the same batch. A class may not cross midnight. **Editing a slot "from date D"** closes the old row (`valid_to = D-1`) and inserts a new one (`valid_from = D`), so past occurrences and attendance stay true. An edit with no history (`valid_from` ≥ today) updates in place. A split edit also moves any live exceptions of the old slot with `original_date ≥ D` to the new slot: the old row is tombstoned and a new row created, because ids derive from the slot. |
| `schedule_exceptions` | `batch_id FK`, `kind TEXT CHECK IN('cancel','reschedule','extra')`, `slot_id FK NULL`, `original_date TEXT NULL`, `new_date TEXT NULL`, `new_start_min INT NULL`, `new_end_min INT NULL`, `note TEXT NULL`, with CHECK constraints per kind (cancel needs slot+original; reschedule needs slot+original+new_*; extra needs new_* only). **id = v5("exc:"+occ)**, where `occ` is the occurrence id (3.2a), for cancel and reschedule. That gives at most one exception per original occurrence, and both devices converge. For an extra class the id is v4, and the occurrence id is derived from it. | idx(`original_date`), idx(`new_date`), idx(`batch_id`). Undoing a cancel or reschedule tombstones the row. |
| `batch_fees` | `batch_id FK`, `effective_month INT`, `amount INT CHECK>=0`. **id = v5("fee:"+batch_id+":"+month)** | idx(`batch_id`,`effective_month`). A batch's fee for month M is the row with the greatest `effective_month <= M`. Changing a fee "from next month" adds a row, so history is never rewritten. The batch form shows the latest row as "monthly fee". |
| `students` | `name TEXT NOT NULL`, `roll TEXT NULL`, `phone TEXT NULL`, `guardian_name TEXT NULL`, `guardian_phone TEXT NULL`, `admission_date TEXT`, `status TEXT CHECK IN('active','left')`, `left_date TEXT NULL`, `notes TEXT NULL`, `has_photo INT DEFAULT 0` | idx(`status`), idx(`name`) |
| `student_photos` | **id = student_id**, `jpeg BLOB` (≤ 200 KB, max 512 px, rejected otherwise) | It is a separate table so list queries never load blobs |
| `enrollments` | `student_id FK`, `batch_id FK`, `start_month INT`, `end_month INT NULL`, `fee_override INT NULL` (per-enrollment fee; 0 = free), `notes TEXT NULL` | idx(`student_id`), idx(`batch_id`). There is no unique constraint because re-enrolling is allowed. The UI prevents two *open* enrollments in the same batch. |
| `attendance_sessions` | `occ TEXT NOT NULL` (occurrence id, 3.2a), `batch_id FK`, `slot_id FK NULL`, `original_date TEXT NULL`, `exception_id FK NULL` (set for extras), `date TEXT` (the date the class **actually** happened, i.e. `new_date` when rescheduled), `start_min INT`, `end_min INT` (actual time, snapshotted when taken), `note TEXT NULL`. **id = v5("ses:"+occ)** | idx(`occ`), idx(`batch_id`,`date`), idx(`date`). One row per **class occurrence**, so a batch can have several sessions on one date. It means "roll call was taken". |
| `attendance_records` | `session_id FK`, `batch_id FK`, `student_id FK`, `date TEXT` (denormalized from the session), `status TEXT CHECK IN('P','A','L')`. **id = v5("att:"+occ+":"+student_id)** | idx(`session_id`), idx(`student_id`,`batch_id`,`date`). (session, student) is unique by construction. Saving a roll call upserts the session and one record per student enrolled on that date, in **one transaction**. |
| `payments` | `student_id FK`, `enrollment_id FK`, `batch_id FK` (denormalized), `billing_month INT`, `amount INT CHECK>=0`, `paid_on TEXT`, `method TEXT CHECK IN('cash','bkash','nagad','rocket','bank','other')`, `note TEXT NULL`, `waived INT CHECK IN(0,1)` | idx(`enrollment_id`,`billing_month`), idx(`paid_on`), idx(`student_id`). Partial payments are multiple rows. Waived means a row with `waived=1, amount=0`. |
| `settings` | **id = key**, `value TEXT` (JSON-encoded scalar) | Synced settings only. See 3.8 for which keys. |

**"Occurrences on date D"**, the hot path for Home, roll call, conflicts and reminders, needs two indexed reads, then in-memory expansion. The data is tiny (fewer than 100 slots):
- `SELECT * FROM batch_slots WHERE deleted_at IS NULL AND weekday = :isoWeekday(D)`. For a range, read all live slots.
- `SELECT * FROM schedule_exceptions WHERE deleted_at IS NULL AND (original_date BETWEEN :a AND :b OR new_date BETWEEN :a AND :b)`.

Both are joined with live, non-archived batches.

### 3.2a Occurrence identity (used everywhere)
A class occurrence has **one stable string id, `occ`**. It is URL-safe (only `[0-9a-f.-]`):
- **Recurring:** `s.<slot_id>.<original_date yyyymmdd>`
- **Rescheduled:** it **keeps** the recurring identity `s.<slot_id>.<original_date>`. The roll call, reminders and links follow the moved class. The actual date and time come from the exception.
- **Extra class:** `x.<exception_id>`

Derived ids and uses:

| Use | Value |
|---|---|
| Exception id (cancel / reschedule) | `v5("exc:"+occ)` |
| Session id | `v5("ses:"+occ)` |
| Record id | `v5("att:"+occ+":"+student_id)` |
| Notification id | `fnv1a31(occ)` |
| Notification payload | `rollcall\|<occ>` |
| Deep-link / route | `/rollcall/:occ` |

Resolving an `occ` needs no range scan:
- `s.*` → read the slot, then the exception `v5("exc:"+occ)`. If it is a cancel, show "cancelled"; if a reschedule, use the new date and time.
- `x.*` → read the exception by id.

**Ad-hoc roll call:** saving a roll call for a batch on a date and time where it has no occurrence first creates an `extra` exception, with time defaulting to now rounded to 15 min and duration taken from the batch's most common slot or 60 min. This goes through the normal clash check, and the extra's `x.<id>` becomes the session's identity. All of this happens in the same transaction.

**Queries that used to assume one session per batch per date:**
- **Today and Home** take engine occurrences for D, left-joined on `attendance_sessions.occ`, which gives "taken ✓" per class.
- **Attendance %** counts classes, not days:
  - student in batch = `count(P or L) / count(records)` over `(student_id, batch_id)`
  - batch = the same summed over students

  Records exist for every student enrolled on the session date, so no denominator join is needed.
- **History lists** sort by (`date`, `start_min`).
- Dues are monthly and unaffected.

### 3.3 Local-only tables (never exported)
- `local_meta(key PK, value)` holds `device_id` (UUID v4, created on first launch), `device_name`, `locale`, `theme_mode`, `reminders_enabled`, `reminders_planned_until`, `last_export_at` and `last_import:<sourceDeviceId>`.
- `safety_snapshots(id, created_at, reason TEXT, bytes BLOB)` stores a gzip snapshot. One is written automatically **before every import and every schema migration**, and only the last 5 are kept. "Undo last import" restores from it. This works the same on web, where there are no file paths.
- `import_log(id, imported_at, snapshot_id, source_device_id, summary_json)`.

### 3.4 Snapshot format: gzipped JSON
JSON is chosen over a raw .sqlite file for four reasons:
- It is identical on web, where we cannot obtain an IndexedDB-backed file.
- It is schema-version tolerant.
- It is diffable in pure Dart.
- It is about 10× smaller after gzip.

File: `alamin-backup-YYYYMMDD-HHmm-<deviceShort>.ambackup` (gzip). The format is detected by content, not extension. Import uses `FileType.any`.
```json
{ "format":"attendance-alamin-backup", "formatVersion":1, "schemaVersion":1,
  "appVersion":"1.0.0+42", "snapshotId":"<uuid v4>", "deviceId":"…", "deviceName":"…",
  "createdAt":1795180000000,
  "counts":{"students":120,…},
  "sha256":"<hex of utf8(canonicalJson(tables))>",
  "tables":{"subjects":[{…column_name: value…}], …, "student_photos":[{"id":"…","jpeg":"<base64>",…}]} }
```
- Export is table-agnostic: `customSelect('SELECT * FROM $t')` produces `row.data` (column-named maps). Tables come from a single ordered registry `kSyncedTables` in parent-to-child order, and **tombstones are included**.
- Canonical JSON means sorted keys, no whitespace and rows sorted by id.
- Export I/O:
  - `FilePicker.saveFile(bytes:)` on Windows, web (browser download) and Android (SAF "create document").
  - On Android there is also a secondary "Share backup" via share_plus, for WhatsApp or the Drive app.
- Import I/O: `FilePicker.pickFiles()`, then `PlatformFile.readAsBytes()`. Note that `withData` was removed in file_picker 13.

### 3.5 Diff and change summary (pure Dart: `lib/domain/sync/`)
`ChangeSummary diff(Map<table, List<Row>> local, Snapshot incoming)`. For every table and every incoming row `r`, with local row `l` of the same id:
- **There is no `l`:** if `r.deleted_at == null`, count it as **added**. Otherwise skip it (an unknown tombstone).
- **`l` exists and incoming wins:** incoming wins when `(r.updated_at, r.rev, r.device_id) > (l.updated_at, l.rev, l.device_id)` compared lexicographically, and the content differs (all non-sync columns plus `deleted_at`). Then:
  - If `r` is deleted and `l` is not, count **deleted**.
  - If `l` is deleted and `r` is not, count **changed** ("restored").
  - Otherwise count **changed**.
- **Anything else:** keep local and count `keptLocal`, which shows as "your newer edits are kept".

Local rows absent from the snapshot are **untouched**. Import is a *merge*, never a mirror. Into an empty DB, merge equals full restore.

The summary has per-table `{added, changed, deleted, keptLocal}` and up to 5 sample display names per bucket. It is shown as "এই ব্যাকআপে ৩৪টি পরিবর্তন: শিক্ষার্থী +৩, ~২ …". Zero changes means "already up to date" and nothing is applied.

### 3.6 Apply
Apply happens in **one transaction**:
1. Write a safety snapshot first.
2. Run `PRAGMA defer_foreign_keys = ON`.
3. Walk tables in registry order and run `INSERT INTO t(cols) VALUES(…) ON CONFLICT(id) DO UPDATE SET …` for the winning rows only. **Never `INSERT OR REPLACE`**, because it deletes and then inserts.
4. Write `import_log`.
5. Run `PRAGMA foreign_key_check` and `PRAGMA quick_check`. Any failure rolls back the transaction.

The same `diff` + `apply` pipeline is reused unchanged by Drive sync.

### 3.7 Future Google Drive sync (designed, not built)
- There is one Drive folder (`appDataFolder` is not used, because the teacher must see the files).
- Each device uploads `snapshot-<deviceId>-<createdAt>.ambackup` after meaningful changes, or on demand.
- A pulling device lists the folder, takes the newest snapshot from *each other* device that is newer than `local_meta.last_import:<device>`, and runs diff, confirm, apply for each.
- LWW plus tombstones plus deterministic natural-key ids make this idempotent and order-independent. Tombstones are never purged in v1 because the data volume is tiny.

### 3.8 Settings mechanism and sync scope
The Strategist owns the list. The Architect owns the mechanism and the scope rule.

- One typed registry in `lib/core/settings/setting_keys.dart`: `SettingKey<T>(id, scope, defaultValue, codec, validator)`. `SettingsRepository.watch(key)` / `set(key, v)` routes by `scope`:
  - `synced` goes to the `settings` table and travels in backups.
  - `device` goes to `local_meta` and never leaves the device.
- **Rule:** facts about the *center* and the teacher's *working rules* are synced. Preferences about *this device's* look and behaviour stay on the device.
- **Synced keys:**
  - `center_name`, `center_phone`, `center_address`
  - `receipt_footer`
  - `dues_reminder_template_bn` / `_en` (share text)
  - `default_reminder_lead_min` (default **15**). Per-batch leads are batch data and therefore synced too.
  - `day_window_start_min` / `day_window_end_min` (default 360 / 1320). These are the hours searched for free slots.
  - `center_utc_offset_min` (default 360, not shown in the UI)
- **Device keys:**
  - `locale` (bn/en)
  - `theme_mode` (system/light/dark)
  - `reminders_enabled` (default **on**). It is device-local because the teacher may want alarms on the phone and not on the PC.
- Unknown keys found in a snapshot are kept, not dropped, so the format is forward-compatible.

---

## 4. Dues engine (`lib/domain/dues/`, pure Dart)

Inputs are plain value objects, so the engine has **no `DateTime.now()`, no DB and no Flutter**:
```dart
DuesReport computeDues({required LocalDate today, required List<EnrollmentTerms> enrollments,
                        required List<PaymentFact> payments});
// EnrollmentTerms: enrollmentId, studentId, batchId, BillingType billing, YearMonth start,
//                  YearMonth? end, int? feeOverride, List<FeePeriod> batchFees, bool batchArchived
// PaymentFact: enrollmentId, YearMonth billingMonth, int amount, bool waived  (non-deleted only)
```

Rules:
1. `dueDate(M)` is the **1st of M** for prepaid and the **1st of M+1** for postpaid.
2. Billable months are `M ∈ [start, end ?? ∞]` where `dueDate(M) <= today`. With today = 2026-11-05, prepaid bills through Nov and postpaid through Oct.
3. `fee(M) = feeOverride ?? batchFee(M)`. Here `batchFee` is the latest `FeePeriod.effective <= M`. If there is none, the fee is 0 and the result is flagged `feeMissing`, which is surfaced in the UI.
4. `paid(M)` is the sum of non-waived amounts. `waived(M)` is true if any waived row exists, and then the outstanding amount is 0.
5. `outstanding(M) = max(0, fee − paid)`. If `paid > fee`, the overpayment is reported as `overpaid` on that month only. There is no automatic carry-forward. Advance payments are recorded against future months and count once billable.
6. `day = today − dueDate(M) + 1` (the 1st is day 1).
7. `Severity` is one of:
   - `none` when outstanding == 0
   - `warning(level: day)` for days 1..10
   - `overdue` when day > 10

   Older unpaid months are therefore always overdue.
8. Per enrollment the engine reports the months list, `totalOutstanding`, `oldestUnpaid` and `worst`. Per student it reports the aggregate over enrollments, with `worst = max` and the batches involved. The report is sorted by severity rank descending, then outstanding descending, then name.
9. The UI maps `warning(1..10)` onto a 10-step amber-to-red ramp, plus `overdue` as deep red. It **always pairs the colour with text** (e.g. "৫ দিন", "বকেয়া") for accessibility. The engine does not know about colour.

Required tests (`test/domain/dues_test.dart`, table-driven, at least 30 cases):
- prepaid vs postpaid on the 1st, 10th, 11th and last day
- month and year rollover (Dec to Jan)
- start or end month in the middle of the range
- fee change mid-enrollment
- override 0 (free)
- partial, then full payment
- waived
- overpaid
- advance payment
- multiple enrollments per student
- left student (end month)
- no fee period
- leap-year Feb
- today before the start month

Value types `LocalDate` and `YearMonth` live in `lib/core/time/` with their own tests.

---

## 4A. Schedule engine (`lib/domain/schedule/`, pure Dart, same purity rules)

```dart
// Inputs (plain value objects, mapped from DB rows by data/)
BatchSchedule { batchId, subjectId, String label, bool archived, List<Slot> slots, List<ScheduleException> exceptions }
Slot { slotId, int weekday, int startMin, int endMin, LocalDate? validFrom, LocalDate? validTo }
// Output
Occurrence { String occ /* 3.2a identity */, batchId, LocalDate date, int startMin, int endMin,
             OccurrenceKind kind /* regular | rescheduled | extra */,
             String? slotId, String? exceptionId, LocalDate? originalDate, int? originalStartMin }
// occ is the ONLY identity used by sessions, reminders, payloads and routes (never batch+date or batch+date+start)
static String occOf({String? slotId, LocalDate? originalDate, String? extraExceptionId});

ExpandResult expand({required DateRange range, required List<BatchSchedule> batches});
//   -> occurrences (sorted by date, start, batch) + cancelled (for "বাতিল" chips)
List<Clash> findClashes({required List<Occurrence> candidates, required List<Occurrence> existing});
FreeSlot? nearestFree({required LocalDate date, required int preferredStartMin, required int durationMin,
                       required List<Occurrence> busy, required int dayStartMin, required int dayEndMin,
                       int stepMin = 15, int searchDays = 7});
List<Clash> checkBatchEdit({required BatchSchedule proposed, required List<BatchSchedule> others,
                            required LocalDate today, int horizonWeeks = 12});
```

Rules:
1. **Regular occurrences.** For each date d in the range and each slot with `weekday == d.isoWeekday` and `validFrom <= d <= validTo` (nulls mean unbounded), the batch is live (not archived). Then:
   - If a `cancel` exception exists for (slot, d), the occurrence is dropped and listed in `cancelled`.
   - If a `reschedule` exists, the occurrence is replaced by one at (`new_date`, `new_start`, `new_end`). It is included if `new_date` is in the range, even when the original date is not. To guarantee this, read exceptions by `original_date` OR `new_date`, as the index pair in 3.2 does.
2. **Extra classes** are added as is.
3. **Overlap** uses half-open intervals on the same date: `a.start < b.end && b.start < a.end`. Touching times (10:00–11:00 and 11:00–12:00) **do not** clash. Different dates never clash. Midnight cannot be crossed (DB CHECK, `end_min <= 1440`), so 23:00–24:00 never clashes with 00:00–01:00 next day.
4. **Scope of the check:** all live, non-archived batches **including other batches of the same subject**. The **old version** of the batch being edited is excluded from `existing`. The **proposed slots of that batch are checked against each other too**: two classes of one batch on the same date are fine, but they must not overlap. A reschedule of occurrence X removes only X before checking, so moving 10:00→10:30 on the same day does not clash with itself. It **does** clash with the same batch's other class at 10:30 that day.
5. **Save-time checks (hard block):**
   - **Slot add or edit:** `checkBatchEdit` expands the proposed schedule over `[today, today + 12 weeks]` ∪ the dates of all future one-off exceptions, then compares with the others. The result is deduplicated to "clashes with *Batch B*, every Saturday 10:30–11:30".
   - **Reschedule or extra:** the single candidate occurrence is compared with that date's occurrences.
   - **Un-archiving a batch:** the same check as a slot edit.
6. **`nearestFree`:** first the same date, then candidates spiralling outward from the preferred start (±15, ±30 …) within `[dayStart, dayEnd − duration]`. Then the next dates up to 7 days, starting at the preferred start. It returns the first gap that fits, or null. The UI offers the result as a one-tap fix.
7. **Time zone:** the engine works only in center wall-clock (`LocalDate` + minutes). It never touches `DateTime`, so there is no DST or time-zone ambiguity inside. Conversion to instants happens only in the reminder planner (4B), via the fixed offset.

Required tests (`test/domain/schedule_test.dart`, at least 30 cases):
- touching times (no clash) and a 1-minute overlap (clash)
- the same batch with 2 non-overlapping slots on one weekday (OK, yielding 2 distinct `occ` values and 2 sessions)
- the same batch with overlapping slots (clash)
- rescheduling one of a batch's two same-day classes onto the other (clash)
- a rescheduled occurrence keeps its `occ`
- an ad-hoc roll call creates an extra and its `x.` occ
- `occ` round-trips (format and parse)
- identical slots
- containment (one slot inside another)
- end at 1440 vs next day 00:00
- start at 0
- a slot whose `valid_to` ends before the horizon, and `valid_from` in the future
- an archived batch ignored
- a cancelled occurrence does not block
- reschedule into a clash, reschedule into its own original slot (no clash), reschedule across dates (range edges)
- an extra class clashing with a regular one
- two exceptions for the same occurrence (deterministic id, so last-writer-wins upstream)
- a range spanning a month or year boundary
- weekday mapping for Sat and Fri (ISO 6 and 5)
- `nearestFree`: same-day gap, no gap so next day, the day-window edge, and a duration longer than any gap (null)
- `checkBatchEdit` deduplication output

---

## 4B. Reminders and notifications

**Pure planner** (`lib/domain/reminders/reminder_planner.dart`):
```dart
List<PlannedReminder> plan({required List<Occurrence> occurrences, required Map<String,int?> leadByBatch,
  required int defaultLeadMin, required int centerOffsetMin, required DateTime nowUtc,
  int windowDays = 14, int maxCount = 200});
// PlannedReminder { int id /* fnv1a31(occ) */, DateTime fireAtUtc, String occ, batchId, LocalDate date,
//                   int startMin, String payload /* 'rollcall|<occ>' */ }
```
- `fireAtUtc = toUtc(date, startMin, offset) − lead`.
- Reminders in the past are skipped, and the result is sorted and capped at `maxCount`.
- A lead of 0 means "at start time".
- Title and body are localized in the gateway, not the planner. Example: "১৫ মিনিট পর: গণিত — ব্যাচ ক (৪:৩০)".

**Gateway** (`lib/data/notifications/notification_gateway.dart`) wraps the plugin. Its `replan()` does the following:
1. If `reminders_enabled` is false, run `cancelAll()` and return.
2. Otherwise run `cancelAll()`, then `zonedSchedule` each planned reminder with `tz.TZDateTime.from(fireAtUtc, tz.UTC)`, then store `reminders_planned_until`.

`replan()` is **debounced 2 s** and called:
- on app start
- on `AppLifecycleListener.onResume`
- on any write to slots, exceptions, batches or reminder settings
- after a backup import

cancelAll followed by a full reschedule is idempotent and cheap at ≤ 200 items.

**Tap handling:**
- `onDidReceiveNotificationResponse` parses the payload and calls `router.go('/rollcall/<occ>')`. The roll-call screen resolves `occ` as in 3.2a.
- On cold start, `getNotificationAppLaunchDetails()` is read in `bootstrap.dart` and sets the router's `initialLocation` after the DB opens.

### Android (works with the app closed)
- **Permissions:**
  - `POST_NOTIFICATIONS` (Android 13+ runtime) is requested with `requestNotificationsPermission()` **when the user first enables reminders or opens Reminder settings**, never on cold start.
  - **Exact alarms:** declare `SCHEDULE_EXACT_ALARM`. Do **not** declare `USE_EXACT_ALARM`. Google Play restricts it to alarm-clock and calendar apps, and we may publish later.
  - On Android 14+ exact alarms are denied by default for new installs. Settings shows "Exact-time reminders: Off (tap to allow)", which calls `requestExactAlarmsPermission()`.
  - Before scheduling, `canScheduleExactNotifications()` chooses `AndroidScheduleMode.exactAllowWhileIdle` if allowed and **`inexactAllowWhileIdle` as the fallback**. In the fallback the OS may delay a reminder by several minutes, and the UI says so.
- **Reboot:** `ScheduledNotificationBootReceiver` (BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT_POWERON) restores pending alarms, so no app launch is needed.
- **Alarm cap:** some OEMs (notably Samsung) cap an app at about 500 alarms. The rolling window (14 days, ≤ 200) stays well under it. Reminders stop after `reminders_planned_until` if the app is never opened. Home shows a hint when fewer than 3 days remain.
- **OEM battery killers** (Xiaomi and others) can block the boot receiver. The About/Help screen links to the "allow autostart" guidance. This is a known limitation, not a bug.
- **Manifest** additions (inside `<manifest>` / `<application>`):
  ```xml
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
  <!-- POST_NOTIFICATIONS + VIBRATE are merged in by the plugin (>=16) -->
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
      <action android:name="android.intent.action.BOOT_COMPLETED"/>
      <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
      <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
      <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
  </receiver>
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"/>
  ```
- **Gradle:** plugin 23.x requires **AGP ≥ 9.1.1 and compileSdk ≥ 37**. The Flutter 3.47.9 template generates AGP 9.1.0 and compileSdk 36. Flutter 3.47.9 supports AGP up to 9.2. So:
  - `settings.gradle.kts`: `id("com.android.application") version "9.1.1"`
  - `app/build.gradle.kts`: `compileSdk = 37`, keeping targetSdk at `flutter.targetSdkVersion` (36)
  - `compileOptions { isCoreLibraryDesugaringEnabled = true }`, keeping Java 17
  - `defaultConfig { multiDexEnabled = true }`
  - `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`
  - A notification icon `res/drawable/ic_stat_class.png` (white-on-transparent)
- **How these are applied:** `tool/platform_patches/apply.py` is an **idempotent** patcher that edits by anchored regex and XML insert and fails loudly if an anchor is missing. `bootstrap.yml` runs it right after `flutter create`. `ci.yml` runs `apply.py --verify`, which fails the build if any committed platform file has drifted. The same script owns the release-signing block, the app label and the Windows window title.

### Windows (OS-scheduled toasts; read the limits)
- Verified from the plugin source (flutter_local_notifications_windows 4.0.1): `zonedSchedule` creates a WinRT **`ScheduledToastNotification`** and calls `ToastNotifier.AddToSchedule`. Windows itself holds the schedule, so **the toast is delivered at the time even if the app is closed**.
- Unpackaged apps work. The plugin registers the AUMID and display name under HKCU on every `initialize`.
- Persistence across a reboot is OS behaviour, and **QA must verify it** on the zip build.
- Initialize with:
  ```dart
  WindowsInitializationSettings(appName: kAppDisplayName /* product name from 01-product.md */, appUserModelId: 'ImRudra.AttendanceAlamin',
                                guid: '1e797322-5c87-4fef-8348-609333181532')
  ```
  These three values are constants and must never change.
- **Limits (honest):**
  1. **Tapping a toast while the app is closed does not open it.** The plugin registers a `CustomActivator` CLSID but no COM `LocalServer32` launcher, so taps only reach the app while it is running. Teacher flow: the toast says what is coming, and Home's "next class" card opens the roll call in one tap.
  2. Without MSIX identity, notification *history* APIs (`getActiveNotifications`, cancel of already-shown toasts) do nothing. Cancelling **pending scheduled** toasts works (the source iterates `GetScheduledToastNotifications()`), so replanning is safe.
  3. Focus Assist / Do Not Disturb suppresses toasts.
  4. The window expires if the PC app is not opened for 14 days.
- **Not in v1:** tray icon or run-at-login (needs Flutter-3.50-only packages), MSIX packaging, and click-to-launch through `LocalServer32` registration. These are v1.1 candidates.
- No duplicate in-app timer runs on Windows.

### Web (verification only)
- `zonedSchedule` **throws `UnsupportedError` on web** (flutter_local_notifications_web 2.0.0). There is **no background or closed-tab reminder on web.**
- While the tab is open, an in-app `ReminderTicker` (`Timer` re-armed to the next planned reminder) shows an in-app banner. If the user has granted browser permission (requested only from a button tap, which the browser requires, on https or localhost), it also calls `show()`.
- Background tabs throttle timers to about once a minute, which is acceptable.
- Settings on web labels reminders "only while this tab is open".

---

## 4C. Theming mechanism (UX Lead owns the values, Architect owns the plumbing)
- `lib/app/theme/tokens.dart` holds raw palette constants only (no Flutter widgets): `LightTokens` and `DuskTokens`, each with surfaces, text, accent, a 3-stop **low-saturation adjacent-hue gradient** set, a 10-step severity ramp plus overdue, and attendance P/A/L colours.
- `lib/app/theme/app_theme.dart` defines `ThemeData buildTheme(Brightness b)`:
  - an explicit `ColorScheme` built from tokens (not `fromSeed`, so values are exact)
  - `fontFamily: 'HindSiliguri'`
  - `useMaterial3: true`
  - component themes
  - `extensions: [AppGradients, SeverityColors, AttendanceColors]`
- Each extension implements `copyWith` and `lerp`, so theme switches animate. The `lerp` uses `Gradient.lerp` / `Color.lerp`.
- Access goes through `context.gradients`, `context.severity.forLevel(n)` and `context.attendance`, which are extension getters. Widgets **never** use literal colours. CI enforces this with a grep for `Color(0x` outside `lib/app/theme/`.
- `MaterialApp.router(theme: buildTheme(light), darkTheme: buildTheme(dark), themeMode: ref.watch(themeModeProvider))`. The provider reads and writes `local_meta.theme_mode`, with values system, light and dark. "Dusk" is the dark theme's display name.
- **Testing in CI:**
  1. `test/app/theme_contrast_test.dart` is pure Dart. It computes the WCAG contrast of every token text/background pair, including text over each gradient stop and the severity chips, in both themes. The thresholds are ≥ 4.5 for body text and ≥ 3.0 for large text and icons.
  2. `pumpInBothThemes(tester, widget)` runs the key screens under light and dusk in bn and en, asserting no exceptions and no `RenderFlex` overflow at 360×640 and 1280×800.
  3. The `screens` job runs tests tagged `screenshot` with **real fonts loaded** via `FontLoader` in `test/flutter_test_config.dart` (Hind Siliguri plus MaterialIcons). It writes PNGs for {Home, Batch, Roll call, Student, Dues, Settings} × {light, dusk} × {bn, en} with `matchesGoldenFile` + `--update-goldens`, and **uploads them as an artifact for UX/QA review**. They are not compared as a gate, because there is no reviewed baseline yet and Linux-only rendering would be flaky against one. The same images double as the Bangla-shaping check.

---

## 5. Module boundaries

```
lib/
  main.dart                      # ProviderScope + App
  app/                           # app.dart, router.dart, bootstrap.dart (DB open, launch-from-notification route)
    theme/                       # tokens.dart, app_theme.dart, extensions/ (AppGradients, SeverityColors, AttendanceColors)
  core/                          # PURE DART: time/ (LocalDate, YearMonth, DateRange, Clock, center offset), format/,
                                 #   ids/ (uuid v4/v5, fnv31), validation/, settings/ (SettingKey registry), result.dart
  domain/                        # PURE DART: dues/, schedule/ (expand, clashes, nearestFree), reminders/ (planner),
                                 #   sync/ (snapshot model, canonical json, diff), attendance_stats/
  data/
    db/                          # app_database.dart, tables/*.dart, connection/ (open_connection + web_only), migrations.dart
    repositories/                # one per aggregate; stamps sync columns; maps drift rows -> domain models
    backup/                      # snapshot export/import I/O (gzip, sha256, file_picker)
    notifications/               # notification_gateway.dart (+ _web.dart in-app ticker via conditional import)
  features/                      # UI + controllers, feature-first
    home/  subjects/  batches/  schedule/  students/  attendance/  payments/  dues/  backup/  settings/
      <feature>/ui/*.dart  <feature>/controllers/*.dart (Riverpod notifiers)  <feature>/widgets/
  l10n/arb/app_bn.arb, app_en.arb   (generated/ is gitignored)
test/  (mirrors lib/: core/, domain/, data/ (in-memory drift), features/ (widget tests))
tool/  fetch_web_assets.sh, fetch_fonts.sh, check_domain_purity.sh, check_arb_keys.dart,
       platform_patches/apply.py (+ --verify)
```

Dependency rules, enforced by `tool/check_domain_purity.sh` in CI with grep:
- `core/` and `domain/` import only `dart:*`, `package:meta`, `uuid`, `crypto`, `archive` and each other. They **never** import `package:flutter`, `drift` or `riverpod`.
- `data/` may import core, domain and drift. It never imports `features/`.
- `features/` may import core, domain, the repository interfaces (`data/repositories`) and `app/`. They **never** import `data/db/` directly or construct queries.
- Cross-feature imports go only through `app/router.dart` routes or shared widgets in `app/widgets/`.
- Only `data/notifications/` imports `flutter_local_notifications` or `timezone`. Features call `ReminderService.replan()` through a provider.
- No literal colours outside `app/theme/`.
- Domain models are hand-written immutable classes. Drift row classes never leave `data/`.

---

## 6. CI/CD (GitHub Actions, private repo `Im-Rudra/attendance-alamin`, branch `main`)

Shared setup: `actions/checkout@v7` and `subosito/flutter-action@v2` (3.47.9, cache). `concurrency: {group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true}`.

### 6.1 `bootstrap.yml` (manual `workflow_dispatch`, run once and again only when needed)
- Runs `flutter create --org com.imrudra --project-name attendance_alamin --platforms=android,windows,web .`. Existing `lib/` and `pubspec.yaml` are kept.
- Then runs `python tool/platform_patches/apply.py`, which applies the AGP 9.1.1, compileSdk 37, desugaring, manifest receivers and permissions, signing block, app label and Windows title changes (4B).
- Then runs `flutter pub get`.
- It **commits** `android/`, `windows/`, `web/` (minus the drift assets) and `pubspec.lock` back to `main` with `permissions: contents: write`.
- After that, the platform folders are hand-edited and committed normally: Android label, Windows window title, `web/index.html` title and theme colour.

### 6.2 `ci.yml` (every push and PR)
**Job `check` (ubuntu-latest):**
1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs`
3. `flutter gen-l10n`
4. `tool/check_domain_purity.sh` (no flutter, drift, riverpod or notifications imports in core/domain, and no `Color(0x` or `DateTime.now(` outside `app/theme/` and `core/time/clock.dart`), `dart run tool/check_arb_keys.dart` and `python tool/platform_patches/apply.py --verify`
5. `flutter analyze --no-fatal-infos`. Warnings and errors fail the job.
6. `flutter test --coverage`
7. Upload artifact `generated-sources` (`**/*.g.dart`, `lib/l10n/generated/`, 7 days), so builders can read generated APIs.

`dart format` is reported but **not enforced**, since there is no local formatter.

**Job `screens`** (ubuntu, needs `check`) runs `flutter test --tags screenshot --update-goldens` and uploads `screens-<sha>` (PNG matrix, 4C). It is non-blocking for the first 2 weeks, then blocking on exceptions only.

**Build jobs, which need `check`:**
- **`web`** (ubuntu):
  1. `tool/fetch_web_assets.sh`
  2. `flutter build web --release --no-web-resources-cdn --base-href /attendance-alamin/ --build-number=${{ github.run_number }}`
  3. `cp build/web/index.html build/web/404.html`
  4. Restage as `site/attendance-alamin/`
  5. Upload artifact `web-<sha>`
- **`android`** (ubuntu):
  1. `actions/setup-java@v6` with temurin 17
  2. If the `ANDROID_KEYSTORE_B64` secret exists, decode it to `android/app/upload.jks` and write `key.properties` from secrets. `android/app/build.gradle.kts` uses the release signingConfig when `key.properties` exists and debug otherwise.
  3. `flutter build apk --release --build-number=${{ github.run_number }}` (one universal APK)
  4. Upload `app-release.apk`. The artifact name says `UNSIGNED-DEBUGKEY` when no secrets are set.
- **`windows`** (windows-latest):
  1. `flutter build windows --release --build-number=…`
  2. Copy `msvcp140.dll`, `vcruntime140.dll` and `vcruntime140_1.dll` from `C:\Windows\System32` into `build\windows\x64\runner\Release\`, so the zip runs on PCs without the VC++ redistributable.
  3. `Compress-Archive` to `attendance-alamin-windows-<ver>.zip`
  4. Upload it.

`--build-number=run_number` guarantees a monotonically increasing Android `versionCode`, so upgrades install over the top and data survives.

### 6.3 `keystore.yml` (manual, once)
1. Runs `keytool -genkeypair` with a random 32-char password and 10000-day validity.
2. Uploads `{jks base64, passwords, alias}` as an artifact with **retention 1 day**.
3. The owner copies these into the repo secrets `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`, stores an offline copy (losing it means the teacher can never upgrade), and deletes the artifact.

**This must happen before the first APK reaches the teacher.** Each CI runner has its own debug key, and a key change forces an uninstall, which wipes local data.

### 6.4 Viewing the web build
- **Option A, GitHub Pages (`pages.yml`):**
  - Runs on push to main only if the repo variable `ENABLE_PAGES == 'true'`.
  - Uses `actions/upload-pages-artifact@v5` with `site/attendance-alamin` and `actions/deploy-pages@v5`, with `permissions: pages: write, id-token: write`.
  - The URL is `https://im-rudra.github.io/attendance-alamin/`.
  - **Pages for a private repo needs a paid plan (Pro, Team or Enterprise), and the published site is public.** It holds no data because the data lives only in each visitor's browser.
  - It works without headers, as explained in 1.6.
- **Option B, free (default recommendation until Pages is enabled):**
  1. Download the `web-<sha>` artifact and unzip it. It contains the folder `attendance-alamin/`.
  2. Run this from the unzip root. It forces the wasm MIME type, because the Windows registry can override Python's mimetypes:
     ```
     python -c "import http.server as h; h.SimpleHTTPRequestHandler.extensions_map['.wasm']='application/wasm'; h.test(h.SimpleHTTPRequestHandler, port=8080)"
     ```
  3. Open `http://localhost:8080/attendance-alamin/`.

  No COOP/COEP headers are needed. The data persists per origin (`localhost:8080`), separately from Pages.
- Never open `index.html` via `file://`. Workers and wasm will not load.

### 6.5 `release.yml` (tag `v*`)
Runs the same build jobs, then `gh release create` with the APK, the Windows zip and the web zip attached.

### 6.6 Later (not v1)
- A web smoke job using Playwright: load the page, check that Diagnostics reports a non-`inMemory` storage, add a subject, reload and assert it is still there. This needs `SemanticsBinding.instance.ensureSemantics()` behind a `--dart-define=E2E=true`.

---

## 7. Security and data safety

1. **No data loss on upgrade:**
   - The applicationId and keystore are fixed, and versionCode is monotonic.
   - Windows data lives in `%APPDATA%` (`getApplicationSupportDirectory`), not the unzip folder, so replacing the zip is safe.
   - Web data lives in IndexedDB per origin.
2. **Schema migrations:**
   - `schemaVersion` starts at 1.
   - `MigrationStrategy.onUpgrade` uses explicit `if (from < N)` steps, and each step is additive: `addColumn` or `createTable`. Destructive changes need a copy-table migration plus an Architect amendment.
   - **Before any migration, write a safety snapshot** (raw-SQL JSON dump into `safety_snapshots`). On native, also copy the DB file to `attendance_alamin.pre-v<from>.sqlite`.
   - `beforeOpen` runs `PRAGMA foreign_keys=ON`. In debug it also runs `PRAGMA quick_check`.
   - CI test `migration_test.dart` creates a v1 DB from a committed raw-SQL fixture, opens it with the current schema and asserts that all rows survive.
   - A CI step runs `dart run drift_dev schema dump` and compares the output with the committed `drift_schemas/drift_schema_v<N>.json`. A difference without a `schemaVersion` bump fails the build.
3. **Backup integrity:**
   - The import pipeline is: gunzip, check format and formatVersion, check SHA-256, check `schemaVersion`. A snapshot newer than local is refused with "update the app first". An older one goes through pure-Dart `upgradeSnapshot(vFrom→vTo)` transforms.
   - Row validation checks types, enums and FK presence (missing parents mean the import is refused).
   - Only then does it run diff, confirm, safety snapshot, apply in a transaction, then integrity checks.
   - Every failure mode leaves the DB untouched.
4. **Backup hygiene in the UX:**
   - A "Last backup: N days ago" nudge on Home appears after 7 days.
   - Export is one tap.
   - The Android uninstall-wipes-data warning appears in the About screen.
5. **Input validation** in `core/validation`, applied in repositories and not only in forms:
   - Trim and normalize digits.
   - BD phone pattern `^01[3-9]\d{8}$` after stripping `+88`, spaces and dashes. The field is optional.
   - Name 1..80 chars.
   - Amounts 0..1,000,000.
   - Dates must be valid and not after today+1y.
   - Fee-change months must be at or after the enrollment start.
6. **Privacy:**
   - There are no network calls in v1 (no analytics). The only network access is opening `tel:` and share intents.
   - Backup files contain minors' phone numbers, so the UI says "keep this file private".
   - Passphrase encryption of snapshots is a Drive-phase item.

---

## 8. Top risks and mitigations

| # | Risk | Mitigation |
|---|---|---|
| 1 | **Code written blind (no local compiler)**: API drift, codegen naming and analyzer errors arrive in CI late | Pin Flutter 3.47.9 and avoid 3.50's material_ui churn. Use the boring APIs listed here. Keep codegen minimal (drift + gen-l10n only). The `generated-sources` artifact lets builders read the real generated API. Build in small PRs, keep CI green per PR, and fix the first red job before writing more code. Logic sits in pure-Dart modules that are covered by plain unit tests. |
| 2 | **Web DB**: asset/version mismatch, `inMemory` fallback (private windows, some Safari), eviction | Exact drift pin plus checksum-verified assets from the same release. The `onResult` diagnostics show a red banner on `inMemory`. Call `navigator.storage.persist()`. No reliance on COOP/COEP. Verification is on Chromium desktop, and Android Chrome is single-tab. |
| 3 | **Android signing / data wipe**: a debug key per runner forces an uninstall, which loses all data | Generate the release keystore once (6.3) before the first hand-off. Back up the keystore offline. Make the export nudge prominent. |
| 4 | **Bangla shaping and font**: Flutter shapes through HarfBuzz/SkParagraph on all 3 targets, so conjuncts are correct **only if our font is used everywhere**. CanvasKit otherwise fetches Noto fallbacks from Google (online only) and mixes glyphs. Hind Siliguri's tall metrics clip in fixed-height boxes. Upstream Regular/Medium/SemiBold had a broken `১`. | Use the fork with the fixed `১`. Apply it globally via `fontFamily`, including English. Use `--no-web-resources-cdn`. Avoid fixed-height text containers and let lines size naturally (about 1.6). Use only Material Icons. Add a dedicated "font check" widget test that pumps a Bangla string with conjuncts and Bangla digits. The council QA screenshots the web build in bn mode on Chromium. Windows Bangla typing via IMEs such as Avro goes through Flutter's TSF support and is verified by QA on the Windows zip. |
| 5 | **sqlite3 build hooks on CI hosts** (`flutter test` on Linux, Android NDK, Windows) | All 3 are run in CI from the first PR. If the Linux host tests can't load SQLite, install `libsqlite3-dev` and use the sqlite3 hook option to use the system library for tests only. |
| 6 | **Merge semantics surprise** (a "deleted" row reappears, or wrong-clock devices win) | Tombstones, monotonic `updated_at` and the `(updated_at, rev, device_id)` tie-break. The change summary is shown before applying, with "your newer edits kept". A safety snapshot plus "Undo last import". |
| 7 | **Reminder reliability differs by platform**: Android exact alarms are denied by default on 14+, OEM battery killers interfere, Windows toast taps do nothing while the app is closed, the rolling window expires if the app is not opened, and web cannot schedule at all | Exact alarms are requested from Settings with an inexact fallback, and the delay is disclosed. The boot receiver restores alarms. Re-plan on start, resume and every change. Home warns when the plan covers fewer than 3 days. Windows limits are stated in Settings and Help. QA test matrix: app closed, reboot, permission denied, Focus Assist. |
| 8 | **New Android toolchain bump** (AGP 9.1.1 / compileSdk 37 required by flutter_local_notifications 23, released 2026-11-06) | Applied by the idempotent `apply.py` and verified in CI from the first PR. The APK is built on every push. **Fallback if the build breaks:** pin `flutter_local_notifications: 22.3.3` (compileSdk 36, template AGP), and expect at most small call-site edits. |
| 9 | **Schedule conflict false negatives / positives** (edge times, reschedules, validity windows) | All logic is in the pure engine, with at least 30 table-driven tests (4A). Half-open intervals. A single `expand()` is shared by Home, roll call, conflicts and reminders, so they can never disagree. |
| 10 | **Gradients hurting legibility in dusk mode** | Token-level WCAG contrast test in CI, a screenshot matrix artifact for UX review, and gradients only on headers and cards, never behind dense text. |

---

### Sources consulted (2026-11-20)
Flutter release feed (`releases_linux.json`), pub.dev API (drift 2.35.4, drift_dev 2.35.3, drift_flutter 0.3.1, sqlite3 3.9.1, sqlite3_flutter_libs 0.6.0+eol, flutter_riverpod 3.5.0, go_router 18.1.4, file_picker 13.4.0, build_runner 2.17.1, material_ui 1.11.1), drift web docs (drift.simonbinder.eu/platforms/web), drift-2.35.4 release assets (downloaded and hashed), riverpod.dev "what's new" (3.x), Flutter 3.50 coverage (VGV blog), github.com/bdeshi/Hind-Siliguri @ 247a09f (TTFs downloaded and inspected with fontTools), GitHub Action tag lists. Gate-1 revision: pub.dev API (flutter_local_notifications 23.0.3 / _windows 4.0.1 / _web 2.0.0, timezone 0.11.2, tray_manager 0.9.0 and window_manager 0.7.0, both needing Flutter ≥ 3.50), the flutter_local_notifications source @ bafca3b (Windows `ffi_api.cpp` / `plugin.cpp`, web `plugin.dart`, `AndroidScheduleMode`, example Gradle and manifest), and Flutter 3.47.9 `gradle_utils.dart` / `FlutterExtension.kt` (AGP 9.1.0, compileSdk 36, max AGP 9.2).
