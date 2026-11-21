# 09 - Judge verdict

Build judged: `main` @ `978db30` (PR #40), CI run 44859676227. Date of judging: 2026-11-21.

## Verdict: **SHIP** (v1, with one delivery precondition)

No code blocker remains against the contract's Definition of done. Every DoD line I could check held up when I tested it myself. The rest depends on the real Android phone and Windows PC (listed below). No amount of web testing can settle those.

## Blockers

**Code blockers: none.**

**Delivery precondition (owner, not code). Do not hand the teacher the CI APK.** The latest `android apk` job says the APK is signed with the runner's DEBUG key (no keystore secrets). Run `keystore.yml` and set up the release secrets, then install **only** a release-signed APK on the teacher's phone, starting with the first install. If he starts on a debug-signed APK, moving to the release key later means uninstalling. That wipes his only copy of the local data, so the app would lose everything the first time it upgrades.

## Evidence

### What I personally verified
- **CI (latest main run, all green):** analyze + test, fast unit tests, web build, android apk, windows zip. The `flutter test` log says **2848 tests passed**. `flutter analyze` reports 70 issues, all info-level (no errors or warnings).
- **Live web build at 1280x800 (desktop) and 375x812 (phone):**
  - **Clash detection:** a new batch on Saturday 4:00 to 5:00 PM was flagged at once against the existing Sat 4:00 to 5:00 batch. So was 4:30 to 5:30. The panel names the clashing class and suggests other times, and Save stays disabled with the reason "সময়ের সংঘাত ঠিক করুন". The suggested touching slot (5:00 to 6:00) was accepted and saved.
  - **Back-dated dues on a postpaid batch:** I added a student whose fees start in September 2026, at ৳500 a month. He immediately showed Sep and Oct overdue (৳1,000) and Nov as "still time". That matches the postpaid rule (month M is due on the 1st of M+1). Warnings appeared on the batch list, the batch detail, the student list, the profile and the Fees tab badge.
  - **Payment updates dues:** recording ৳500 for September turned Sep to "paid" and the total to ৳500, live, with one payment recorded and no duplicate.
  - **Escalation ladder (days 1 to 10):** I moved the browser clock to 2026-12-05 without reloading, and the app's minute tick picked it up. A prepaid student with an unpaid December showed the orange "তাগাদা দিন · ৫ দিন" level. The ladder marked "Day 5 today", and older months stayed at the strongest red "মেয়াদোত্তীর্ণ" (overdue). The code (`DueLevel.forDay`: 1-2, 3-4, 5-6, 7-8, 9-10, then 11 and later overdue) matches contract item 5.
  - **Language and theme:** Bangla to English switched instantly, including dates ("Saturday, 5 Dec") and digits. Tapping the Light preview tile switched the theme (naive-tester C-4 is fixed). Both choices survived a reload.
  - **Persistence and routing:** after a full reload, all data, language and theme were still there. Opening `#/students` directly landed on that page (QA-11 is fixed). The phone Students screen now has a "New student" button (QA-03 is fixed).
  - **Bangla rendering:** Hind Siliguri renders cleanly. The taka sign now has a space before the number ("৳ ১,৬০০"), so it no longer reads as a ৬ (QA-02 is fixed).
  - **Desktop density:** Today is a full bento grid with no wasted width, and Fees and student profile use list and detail panes well.

### Taken on trust (reports and tests, not re-run by me)
- The roll-call flow, holidays, waive, receipts, CSV export, and backup export/import with its change summary (QA report "Verified working", plus #36 for QA-05 and QA-08).
- Fixes for QA-04 (a class with a saved roll call can't be moved into the future), QA-07, QA-12, QA-13, QA-14 and QA-16. I read the #36 change list, but I did not exercise these.
- The naive tester's round 2: 7 of 7 core goals done unaided on phone. I did not re-check the C-1 to C-12 polish from #40 beyond C-4.

### Residual issues (not blocking; fix in a polish pass)
- **Cut-off text on desktop (contract item 13 says tiles must fit perfectly):**
  - The Today hero title is cut off ("…বিকা…") and so is "This month's collect…".
  - On the Fees-due tile, the severity pills are clipped at the bottom edge.
  - In the Students table, the batch name runs into the phone column.
- **Blank areas on desktop:** with little data, the Batches overview pane and the Settings detail pane leave roughly half the window empty. The new-batch form is a centred column about 600 px wide on a 1280 px window.
- The floating label still overlaps the typed text, and amounts show ASCII digits while typing in Bangla (QA-19).
- On the live build, a few taps had to be repeated: "শিক্ষার্থী যোগ করুন" and the profile's "টাকা নিন" each needed 2 or 3 clicks before the sheet opened. Only one sheet or payment ever resulted. This is probably the hidden browser pane redrawing late, but **check it on a real device**.
- The browser console logged one uncaught `Null check operator used on a null value`. I could not tie it to a specific action, and nothing visible broke.
- Reminders are planned only 7 days ahead and re-planned when the app runs. If the teacher doesn't open the app for over a week, class reminders stop until he does.

## Must verify on real devices before the teacher relies on it
1. **Android reminders with the app closed or swiped away:**
   - The notification fires at the right lead time (the per-batch value, otherwise the default).
   - It still fires after a phone reboot.
   - Check with the exact-alarm permission both allowed and denied (denied means it can arrive a few minutes late).
   - Check under battery saver and the maker's battery restrictions (Xiaomi, Samsung and similar).
   - Tapping the notification opens that class's roll call.
2. **Release signing and install:** the release-signed APK installs, and a second release build installs over it **without losing data**.
3. **Windows zip on a clean PC:**
   - It starts without needing any extra installs (the VC++ DLLs are bundled), creates its SQLite database, and keeps data after a restart.
   - Scheduled class toasts appear when the app is closed. CI does no Windows launch test, so this is unverified.
   - Window resizing works at 1366 px, 1920 px and when snapped to half the screen.
   - The real file dialogs work for backup export and import.
4. **Real share sheet and calls on Android:** share a reminder through WhatsApp, share a receipt, tap to call a guardian, and pick a student photo.
5. **Backup round trip across devices:** export on the phone, import on the PC, and check that the change summary is accurate.
6. **Following the system dark mode** on both platforms (QA forced Light, and I tested the toggle, not the follow-system setting).
