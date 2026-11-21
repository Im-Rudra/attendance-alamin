# 08 - Naive "Dumb User" Tester Report (Round 2)

Persona: Al-Amin, tuition teacher, 40s, Bangla reader, impatient, no help, taps the most obvious thing.
App: https://im-rudra.github.io/attendance-alamin/ (fresh wipe; phone 375x812 = `?r=naive3b`, desktop pane 774x862 = `?r=naive4`).
Method: screenshots + coordinate clicks only. Accessibility tree not used for decisions (only attempted as a diagnostic, it gave nothing).

## Round-2 goal table

| # | Goal | Phone: unaided? | Phone: taps | Desktop: unaided? | Desktop: taps | Notes |
|---|------|-----------------|-------------|-------------------|---------------|-------|
| 1 | Physics / Class 9 / 4 pm Sat+Mon+Wed / 800 taka / start of month | YES | ~14 (Next, Physics chip, Class 9 chip, scroll, Mon, Wed, time field, afternoon, hour 4, OK, fee field + type, Create) | YES | ~13 | Subject auto-fills "পদার্থবিজ্ঞান — নবম শ্রেণি"; batch name auto-renames to "বিকাল ৪টার ব্যাচ"; end time auto = +1h; "start of month (advance)" is pre-selected so he never had to think. Disabled Create shows a one-line reason ("বিষয়/শ্রেণি লিখুন", then "মাসিক ফি লিখুন") - excellent. |
| 2 | Add Rahim, Karim, Sumaiya (+Rahim phone) | YES | ~9 (3 x name, 1 phone, 3 x "যোগ করুন, তারপর পরেরজন", Next) | YES | ~9 | Roll numbers auto-assigned; green "X যোগ হয়েছে" confirmation, focus returns to name field so typing continues. Rahim's phone is not echoed in the added list (could not verify it saved). |
| 3 | Mark Karim absent, Sumaiya late, save | YES | 4 (open attendance, tap Karim, tap দেরি on Sumaiya, save) | YES | 4 | Hint banner explains "everyone present by default - tap only the absent". Counter bar "উপস্থিত ১ · অনুপস্থিত ১ · দেরি ১" confirms. Phone: after save the button turns into "হয়ে গেছে" and a second tap is needed; that second tap landed on the Students tab (see C-1). Desktop: single save returns to Today with "হাজিরা সেভ হয়েছে" toast. |
| 4 | Record Rahim's 800 taka | YES | 4 (Fees tab, "টাকা নিন", pick Rahim, confirm) | YES | 4 | Student picker with "৳৮০০ বাকি" per name; the sheet pre-fills November + 800 + cash, so he only presses the big button "নভেম্বরের ৳ ৮০০ জমা করুন". "টাকা নিন" button not hidden by the bottom bar on phone (floats above it) and the confirm button sits above the keyboard-free area on both sizes. Snackbar "৳৮০০ জমা হয়েছে · রসিদ পাঠান · ফিরিয়ে নিন"; total owed drops to ৳১,৬০০. |
| 5 | Who hasn't paid? Send reminder to one | YES (phone) | 3 (already on Fees; scroll, "মনে করান" on Karim) | not repeated | - | The Fees screen's default "বকেয়া" list with a red "মেয়াদোত্তীর্ণ" group answers "who hasn't paid" at a glance. On web "মনে করান" copies text; he gets toast "লেখা কপি হয়েছে — যেকোনো জায়গায় পেস্ট করুন" and the button changes to "আজ মনে করানো হয়েছে" - he understood that something was copied and must be pasted (minor: he may not know where; no WhatsApp deep link on web). Karim has no phone saved yet the button still works (copies text). |
| 6a | Move "tomorrow's" class to 5 pm, tomorrow only | PARTIAL / premise problem | - | not repeated | - | Tomorrow (Sun 22) has no class on a Sat/Mon/Wed schedule; tapping 22 shows "এই দিনে কোনো ক্লাস নেই" - correct, but there is no "move/add" hint there. I used Monday 23 (next class) instead: tap day, tap ⋮, sheet header "শুধু সোমবার, ২৩ নভেম্বর" (clearly "only this day"), "সময় বদলান", tap time field -> friendly picker, 5, OK, Save = 8 taps. Result card shows "বদলেছে · আগে বিকাল ৪:০০". Duration auto-kept (5-6 pm). |
| 6b | Extra class Friday 10 am | YES | 9 ("+ অতিরিক্ত ক্লাস", date field, 27, OK, time field, 10, OK, Add) | not repeated | - | Date defaults to the selected day, so he must change it to Friday. Friday gets a dot in the week strip afterwards. |
| 7 | English and back; make it dark | YES | EN toggle 1 tap + back 1 tap; dark = More, scroll, Dark = 4 taps | not repeated | - | Instant language switch with a bilingual "বাং / EN" pill on Today. Dark: app was already dark (system theme) so "make it dark" looked like a no-op until he set "ডার্ক" explicitly; the three theme preview tiles above the segmented control are NOT tappable (first tap on the dark tile did nothing) - see C-4. |

Overall: 7/7 goals completable on phone, 4/4 on desktop. No Blocker.

## Confusion log (severity)

Blocker: none.

Major: none.

Minor:
- C-1 (Attendance, phone): After "সেভ করুন" the primary button becomes "হয়ে গেছে" and the screen stays open; tapping it closed the screen and he ended up on the **Students** tab, not Today (looks like the tap fell through to the bottom bar item under the button, or the pop target is wrong). Desktop closes straight to Today after one save, so behaviour is inconsistent. Expected: return to Today, or close automatically. Saw: extra tap, wrong tab.
- C-2 (Attendance, desktop 2-column grid): status labels truncate to a single letter ("উ", "অ", "দে") because the rows are too narrow; colour and icon still carry the meaning, but it looks cramped/broken. Same on the fees top bar: "টাকা নিন" touches the filter icon in the app bar on desktop.
- C-3 (Fees, phone): the floating "টাকা নিন" button sits on top of the last visible card's own inline "টাকা নিন" button (Sumaiya's card), hiding it; two identical buttons on screen at once. Not hidden by the bottom bar, but overlapping content.
- C-4 (More > Theme): three theme preview thumbnails look like buttons but do nothing when tapped; the real control is the segmented control below them. Also with system theme = dark, "make it dark" gives no visible change at first.
- C-5 (Today): "tomorrow's class" - when there is no class tomorrow the empty state says only "এই দিনে কোনো ক্লাস নেই" with no suggestion (e.g. add an extra class). He has to guess the next class's day.
- C-6 (Time sheet in "সময় বদলান"): the time field has "-" and "+" stepper icons whose step size is unknown; he ignored them and tapped the text. Fine, but the stepper is ambiguous.
- C-7 (Payment sheet): immediately after confirming, the still-open sheet briefly re-renders pre-selected on "ডিসেম্বর · অগ্রিম" (advance) with a faded button before closing; a fast second tap could record an advance payment by mistake. Visual only in my run (closed by itself), but alarming.
- C-8 (Today, after moving class): the card shows two rows for the same class (new time "বদলেছে" plus a greyed "সরানো হয়েছে: ২৩ নভে বিকাল ৫:০০" row). The second line reads as a duplicate/ghost.
- C-9 (Onboarding, student step): after adding Rahim with a phone, the list shows only "রোল ০১ · Rahim" - no phone icon, so he cannot confirm the number was kept.
- C-10 (Language switch): auto-generated batch names stay in Bangla ("পদার্থবিজ্ঞান — নবম শ্রেণি · বিকাল ৪টার ব্যাচ") in the English UI; digits in them stay Bangla numerals while the rest of the English UI shows Latin digits. Acceptable for user data but looks partly untranslated.
- C-11 (Desktop Today): the next-class hero card truncates with an ellipsis ("৭ ঘণ্টা ১৮ মিনি…", batch title cut).
- C-12 (Overdue on day one): all three newly added students are immediately "মেয়াদোত্তীর্ণ" (overdue) because fee is due at start of month and it is the 21st. Correct by the rules, but he may think "I just added them, why overdue?".

Test-harness caveats (not counted as app defects): the very first run on phone showed content clipped on the right after a resize + same-URL reload (Flutter canvas size stale in the emulator); a clean navigation at 375x812 rendered everything correctly. Screenshots lag by 1-2 s, and sheet close animations were sometimes caught mid-animation.

## Improved vs round 1

- Everything the naive user needed was reachable by tapping the obvious button; no goal needed a retry or guesswork except the "tomorrow has no class" premise.
- Setup is now one guided sequence (language -> batch -> students -> notifications) with disabled-button reasons, auto-names, auto end time and the advance/arrears choice pre-answered; round-1 style confusion about "what do I fill first" did not recur.
- Pickers for time are chip-based (সকাল/বিকাল + hour) instead of a clock dial; faster and in Bangla.
- Payment flow is 4 taps with pre-filled month and amount; "who owes" is the default Fees view; reminder gives a clear "copied - paste anywhere" explanation.
- Coach mark on Today ("tap today's class to start attendance") and the attendance hint banner removed hesitation at the first attendance.
- Remaining polish is cosmetic (C-1..C-4 are the ones most worth fixing: tap-through after attendance save, non-interactive theme tiles, overlapping floating button, truncated desktop labels).
