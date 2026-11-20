# Phase 0 — Scope Contract (the bar everything is judged against)

## Who
A single tuition teacher who runs his own coaching center in Bangladesh. Not technical. Uses an Android phone in class and a Windows PC at the desk. Teaches several subjects/classes; each subject/class has several batches.

## Platform & delivery constraints (hard)
- **Flutter**, one codebase. Targets from day one: **Android** and **Windows desktop**. **Flutter Web** build is used for verification (and must actually work, including the database).
- **No toolchain on the dev PC.** All builds (web, Android APK, Windows) run in **GitHub Actions**. Repo: `git@github.com:Im-Rudra/attendance-alamin.git` (currently empty, branch `main`).
- **Offline-first.** All data lives locally in **SQLite**. The app works with no internet.
- **Bangla-first, fully bilingual.** Default language Bangla; one tap to switch to English; every string, number, date and month name localized (Bangla digits ০-৯ in Bangla mode). Font: **Hind Siliguri, fixed fork** from https://github.com/bdeshi/Hind-Siliguri, bundled as an app asset (no runtime font download).

## In scope (v1)
1. **Structure:** Subjects/Classes → Batches (one subject/class has many batches). Each batch has: name, schedule (weekdays + time), monthly fee, **billing type: prepaid or postpaid**, active/archived.
2. **Students:** name, roll/ID, phone, guardian name + phone, photo optional, admission date, which subject/class and **which batch** (a student may be in more than one batch), per-student fee override/discount, active/left status, notes.
3. **Attendance:** fast roll call per batch per date (present/absent/late; default-all-present with tap to toggle), edit past days, attendance history and % per student and per batch.
4. **Payments:** record a monthly payment per student per batch (amount, date, method e.g. cash/bKash/Nagad, note), partial payments, mark waived/free; see who has / hasn't paid for any month.
   - **Prepaid** batch: the fee for month M is due at the start of month M.
   - **Postpaid** batch: the fee for month M is due at the start of month M+1.
5. **Payment warnings with escalating color:** unpaid dues become warnings from day 1 of the due month; days 1→10 get progressively tighter/stronger in color; after day 10 = overdue (strongest). Example: "Jason Mark didn't pay, and it's already the 5th." Visible on home/dashboard, on batch lists, and on the student profile.
6. **Teacher-life-easier features** (Product Strategist decides the final list; must stay simple), e.g. today's batches on the home screen, dues list with one-tap call / share reminder message (via OS share sheet — no SMS gateway), payment receipt text to share, quick search, monthly collection summary.
7. **Backup/sync groundwork:** data model designed so a full-DB snapshot can be compared with another snapshot to produce a **change summary** (added / changed / deleted counts per entity) before applying. v1 ships **local export/import of a backup file with that change-summary confirmation**.

8. **Theming (added at Gate 1 by the user):** full **light and dark ("dusk") mode** from day one, plus follow-system. Aesthetically beautiful, not boring: **tasteful gradients** (soft, low-saturation, adjacent hues) used with restraint — explicitly **not "wedding-day lighting"** (no gaudy, glittery, rainbow or over-saturated looks). Every screen must look right in both modes.
9. **Class schedule (added at Gate 1):** which subject/class, which batch, when. Recurring weekly slots per batch, plus per-date **reschedule / cancel / extra class**. **Time-conflict detection across all batches**: e.g. a class tomorrow 10:00–11:00 and another scheduled 10:30–11:30 is a conflict and must be caught when saving (touching times like 10:00–11:00 and 11:00–12:00 are fine).
10. **Class reminders/alarms (added at Gate 1):** a local notification a fixed time before each class. Lead time (10/15/20/any minutes) can be set per batch; if not set, a default is used; that default is changeable in Settings.
11. **Settings (added at Gate 1):** most app behaviour is configurable from one Settings screen — but only what a teacher would genuinely change. Expert-curated, not exaggerated.

12. **Visual direction (user-chosen):** "Aurora Ink" — mesh-glow background, subtle film grain, frosted-glass cards, in light and dark.
13. **Desktop is first-class from day one (user, Gate 1):** the Windows layout ships with Android in v1, and uses the window efficiently — tiles fit perfectly (aligned edges, equal row heights, consistent gutters, no ragged ends) and there are **no eye-pinching blank areas** at any window size (no narrow centered phone column on a wide window; extra width becomes extra panes/columns, not empty margin).

## Later (designed-for, not built in v1 unless approved at Gate 1)
- **Google Drive sync:** two or more devices point to the same Drive folder; devices push backup versions; another device pulls the latest, sees "N changes in this backup" and confirms before applying.

## Explicit non-goals (v1)
- No server/backend, no user accounts/login, no multi-teacher roles.
- No SMS gateway / paid messaging; no online payment collection.
- No iOS/macOS/Linux builds.
- No local Flutter/Android SDK installs on the dev PC.

## Definition of done
Builds green in GitHub Actions for web + Android APK + Windows; the web build runs in a browser with working SQLite persistence; the core flows (set up subject → batch → add student → take attendance → record payment → see escalating dues warning) work in both Bangla and English; tests pass in CI; the naive tester completes the core flow unaided; the Judge returns SHIP.
