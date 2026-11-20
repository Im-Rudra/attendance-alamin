# Phase 1 — Product Spec (Product Strategist)

> Binding inputs: `00-contract.md` (incl. Gate-1 items 8–11: theming, class schedule + conflicts, class reminders, Settings). Rev 2 after Gate 1. This spec turns it into decisions. Where this spec says "MUST", builders implement it exactly. Where a default is stated, it is the default; do not ask the user.

---

## 1. Persona & jobs-to-be-done

**Primary (and only) user: "Sir" — the owner-teacher.** 30-45, runs a coaching center alone (maybe one helper). 50-300 students across 3-8 subjects/classes, 2-5 batches each, 1-6 batches a day. Android phone in class (often one-handed, standing, noisy room, patchy data). Windows PC at home/desk for evening accounts. Reads Bangla comfortably, English partly. Has never used "backup". Hates typing. Fees are his livelihood; awkwardness about asking for money is real, so the app must do the asking politely for him.

**Jobs-to-be-done (ranked)**
1. Know who hasn't paid, how much, since when — and ask them without awkwardness.
2. Record a payment in seconds while the guardian is standing in front of him, and hand back proof (receipt text).
3. Take roll call fast at the start of a batch.
4. See which classes are today (after cancellations/reschedules) and whether anything needs attention; never double-book himself.
5. Get nudged before each class so he is never late.
6. Not lose data; move data between phone and PC.

**Moments that matter**

| # | Moment | When | What must happen | Target |
|---|---|---|---|---|
| M1 | Walking into the 4pm batch | Daily, start of each batch | Home → tap batch → everyone pre-marked present → tap the 2-3 absentees → Save | < 20 s for a 30-student batch |
| M2 | Guardian hands over cash | Any time | Search name → "টাকা নিন" → amount prefilled with oldest unpaid month → Save → share receipt | < 30 s |
| M3 | Fee-chasing week | Day 1-10 of each month | Home shows coloured dues count; dues list sorted worst-first; one tap call or share reminder per guardian | Find all unpaid in < 10 s; send a reminder in 2 taps |
| M4 | End-of-month accounts | Last/first days of month, on PC | Monthly summary: expected vs collected vs outstanding per batch, by method | One screen, no calculation by hand |
| M5 | Moving between phone and PC | Weekly-ish | Export backup on one device, import on the other, see "what will change", confirm | Understandable without help |
| M6 | 15 min before class | Each class | Phone buzzes "পদার্থবিজ্ঞান · ব্যাচ A — ৪:০০-এ ক্লাস, ১৫ মিনিট পর"; tapping it opens that class's roll call | Zero taps to be reminded; 1 tap to roll call |
| M7 | Moving a class (exam week, Eid, guest) | Few times a month | Reschedule/cancel one date or add an extra class; app blocks clashes and suggests a free time | < 30 s, never a silent double-booking |

---

## 2. Features

### MUST (v1)
| ID | Feature | Notes |
|---|---|---|
| F1 | Subjects/Classes CRUD | Name only (+ optional note). One level: "Class 9 Physics" is one subject/class. |
| F2 | Batches CRUD | Name, parent subject/class, **weekly slots** (F24), monthly fee, billing type (prepaid/postpaid; prefilled with the type of the last batch created, first ever = **prepaid**), class-reminder lead time (nullable = use Settings default; or Off), active/archived. |
| F3 | Students CRUD | Name (required), student ID (auto, editable), phone, guardian name, guardian phone, photo (optional, compressed ≤ 200 KB), admission date (default today), notes, status active/left. |
| F4 | Enrollment (student ↔ batch, many-to-many) | Per enrollment: join date, first billable month (auto, editable), fee override (optional amount), end/last billable month (when left/removed). Add a student to a batch from either the student or the batch screen. |
| F5 | Roll call | Per class occurrence (batch + date + start time; a batch can have 2+ classes a day); default all present; tap to toggle; Late via long-press/chip; Save. Edit any past date. |
| F6 | Attendance history & % | Per student per batch (month calendar + %), per batch (per-date list + avg %). |
| F7 | Record payment | Amount, date (default today), method (Cash/bKash/Nagad/Rocket/Bank/Other, default Cash), note; allocated to month(s); partial allowed; multi-month in one go; advance months allowed. Edit/delete a payment. |
| F8 | Waive a month | Mark a billable month of an enrollment as waived (মাফ) with optional reason; reversible. |
| F9 | Dues engine + escalating warnings | Exactly per §3. Visible on Home, batch student list, student profile, dues list. |
| F10 | Dues list | All students with outstanding dues, worst severity first; filter by batch / severity; each row: name, batch, months count, total, severity colour, buttons **Call** (guardian phone, fallback student phone) and **Remind** (OS share sheet with Bangla/English template). |
| F11 | Payment receipt text | After saving a payment: "Share receipt" via OS share sheet (template §5). Also re-shareable from payment history. |
| F12 | Home / Today | Today's **effective class occurrences** (§3.9: slots after cancel/reschedule/extra) ordered by start time, each with time range, "বাতিল"/"সময় বদল"/"অতিরিক্ত" tag where relevant, and "হাজিরা নেওয়া হয়েছে ✓" state; cancelled ones shown struck-through (not tappable for roll call); next class highlighted; dues summary card (count per severity + total outstanding); absence alerts (F16); backup nudge (F18). |
| F13 | Quick search | Global, from Home: matches student name, ID, phone, guardian phone (Bangla or English digits). Results open the student profile. |
| F14 | Monthly collection summary | §3.7. Per billing month, per batch. |
| F15 | Batch archive & student "left" | §3.2. Archived batches hidden from Home/roll call, shown under "আর্কাইভ"; can unarchive. |
| F17 | Backup export/import with change summary | §4. |
| F19 | Settings | One screen, curated list exactly per §3.12. |
| F24 | Class schedule (রুটিন) | Per batch 1+ weekly slots (weekday, start, end; different days may differ). Per-date exceptions: cancel, reschedule (to another date/time), extra class. Weekly schedule view (all batches, week starts per Settings) + per-batch list. Rules §3.9. |
| F25 | Time-conflict detection | Hard block on save with clash details + nearest free slot suggestion. Rules §3.10. |
| F26 | Class reminders | Local notification N minutes before each effective occurrence; tap opens that class's roll call. Rules §3.11. |
| F27 | Theme | Light, dark ("dusk") and follow-system; every screen correct in both; soft low-saturation gradients used sparingly (UI Lead owns tokens). Default = follow system. |

### SHOULD (v1 if cheap — each is ≤ 1 day; drop in this order from the bottom if time runs short)
| ID | Feature | Why it earns its place |
|---|---|---|
| F16 | Absence streak alert | Student absent in the last **3 consecutive held sessions** of a batch → shows on Home ("রাহিম পরপর ৩ দিন অনুপস্থিত") with Call button. Dropouts usually stop paying next; this is early warning. Dismissible until next absence. |
| F18 | Backup nudge | Home banner if last export > 7 days ago (or never and ≥ 10 students). Data loss is the #1 catastrophic risk. |
| F20 | Quick-add students (bulk) | In a batch: "একসাথে অনেক যোগ করুন" — a repeating mini-form (name, guardian phone) with "Save & next". Setup day matters: 200 students must be enterable in one evening on the PC. |
| F21 | "Leave/ছুটি" attendance status | Informed absence; excluded from % denominator and does not break absence streak. |
| F22 | Other income (admission/exam/notes fee) | Record a one-off payment with a label; appears in receipt & collection summary as "অন্যান্য". **No due tracking, no warnings.** |
| F28 | Holiday / closure range | "ছুটি ঘোষণা": cancel all classes of all batches for a date range (Eid, exams, hartal) in one action; creates per-occurrence cancel exceptions; reversible. Saves 30+ taps around Eid. |
| F23 | CSV export | Students, payments, attendance of a chosen month → CSV (UTF-8 BOM so Excel shows Bangla). Share/save via OS. |

### LATER
Google Drive sync (two devices, shared folder, same LWW merge as v1 import) · CSV import · dues notifications (e.g. 9am "৫ জনের বেতন বাকি") · tracked one-off charges with dues · percentage discounts · sibling discounts · exam/result tracking · room/location per class · PDF receipts / printed ID cards · multi-teacher/helper roles.

### NON-GOALS (v1, firm)
Login/accounts/server · SMS gateway or WhatsApp API (share sheet only) · online fee collection · iOS/macOS/Linux · **fee proration** (never; month granularity only) · late-payment fines · guardian-facing app · multi-room/multi-teacher scheduling (conflicts are always "one teacher, one place") · classes crossing midnight · analytics charts beyond the numbers in F6/F14 · configurable warning thresholds, currency or date format (see §3.12).

---

## 3. Business rules (builders implement exactly)

### 3.0 Definitions
- **Month** = calendar month `YYYY-MM` in device local time (assume Asia/Dhaka). "Today" = device local date.
- **Enrollment** = one student in one batch. **All money and dues are per enrollment.** A student in 3 batches has 3 independent due streams; the student-level view sums them.
- **Billing month M** = the month the fee is *for* (the month of teaching).
- **Due month D(M)**: prepaid → `D = M`; postpaid → `D = M + 1`. **Due date** = day 1 of D.

### 3.1 Effective monthly fee for (enrollment, M)
1. If the enrollment has a fee override in effect for M → that amount (may be 0 = free student).
2. Else the batch fee in effect for M.
- Fee changes (batch fee or override) are stored with an **effective-from month**. The edit form asks "কোন মাস থেকে?" default = current month. Months before that keep the old fee.
- If a fee change makes an already-paid month under-paid, it becomes Partial; the form warns "N টি মাস আংশিক হয়ে যাবে" before saving.
- Discount in v1 = a fixed override amount (e.g. 1000 → 800). No percentages.
- Effective fee 0 → month is automatically **Settled (free)**, never a due.

### 3.2 Billable months for an enrollment
Billable months = every month from **first billable month (FBM)** to **last billable month (LBM)** inclusive, where LBM is open-ended while active.
- **FBM default** from join date: join day **1–C → join month**; join day **> C → next month**, where C = Settings "নতুন ভর্তির বেতন শুরু" cutoff, default **15** (so 1-15 → join month, 16-31 → next month). Changing C affects only enrollments created afterwards. Shown on the enrollment form as "বেতন শুরু: [মাস ▾]", editable to any month (earlier or later). **No proration ever.**
- **Student marked Left** (with left date, default today): for each active enrollment, LBM default = left month if left day ≥ 11, otherwise previous month. Shown and editable in the "ছেড়ে গেছে" dialog. Status changes to Left; student hidden from roll call and Home after left date.
- **Removed from one batch only** (student stays active elsewhere): same LBM rule on that enrollment.
- **Batch archived** (archive date, default today): every open enrollment gets LBM = archive month if archive day ≥ 11, else previous month (editable once in the archive dialog as a single value for the batch). No new billable months afterwards; no roll call.
- **Unarchive / rejoin** clears LBM (rejoin may instead create a new enrollment period; v1: rejoin = clear LBM and set student Active; months in the gap are billable unless waived — app shows "মাঝের N মাস মাফ করবেন?" with Yes default).
- A month outside [FBM, LBM] has status **Not billable** and never appears in dues.
- **Existing dues of Left students / archived batches remain owed** until paid or waived. They appear in the dues list under a separate collapsed group "ছেড়ে যাওয়া / আর্কাইভ" with neutral grey styling (no escalating colour, not counted in Home severity counts, but counted in "total outstanding" with a separate line).

### 3.3 Month status for (enrollment, M) — billable months only
`paid(M)` = sum of payment allocations to M. `fee(M)` from §3.1.

| Status | Bangla | Condition |
|---|---|---|
| Waived | মাফ | month marked waived (overrides everything; any allocations stay recorded but month needs nothing) |
| Settled (free) | ফ্রি | fee(M) = 0 |
| Paid | পরিশোধিত | paid(M) ≥ fee(M) |
| Partial | আংশিক | 0 < paid(M) < fee(M) — **counts as unpaid** for warnings; remaining = fee − paid |
| Unpaid | বাকি | paid(M) = 0 |

Only Unpaid and Partial months are **open**. An open month is **due** once today ≥ due date; before that it is **upcoming** (never a warning; shown on profile as "আগামী").

### 3.4 Payment allocation
- A payment is one record (amount, date, method, note) with one or more **allocations** (month, amount); allocations sum to the payment amount.
- Record-payment form: amount prefilled = remaining of the **oldest open month** (due or not). If teacher types more, auto-allocate **oldest open month first**, then forward into upcoming/future months (advance) up to 12 months ahead. Teacher can expand "মাস ভাগ" to adjust allocations manually.
- A month cannot receive more than its fee via auto-allocation; any amount that cannot be placed within 12 future months is rejected with a message (no "credit balance" concept in v1).
- Overpaying a specific month manually is blocked (allocation ≤ remaining).
- Deleting/editing a payment recomputes statuses immediately.
- Payments can be recorded against Left/archived enrollments' open months.

### 3.5 Warning escalation (per open, due month)
`d` = day-of-month of today **within the due month D**; if today is after the due month, the level is Overdue.

| Level | Key | When | Bangla label | English | Colour intent (UI Lead picks exact tokens) |
|---|---|---|---|---|---|
| 0 | upcoming | today < due date | আগামী | Upcoming | none (neutral) |
| 1 (L1) | justDue | D, day 1-2 | নতুন বকেয়া | Just due | pale yellow |
| 2 (L2) | remind | D, day 3-4 | মনে করান | Remind | yellow-amber |
| 3 (L3) | followUp | D, day 5-6 | তাগাদা দিন | Follow up | amber/orange |
| 4 (L4) | urgent | D, day 7-8 | জরুরি | Urgent | deep orange |
| 5 (L5) | finalDays | D, day 9-10 | শেষ সময় | Final days | solid red |
| 6 (OD) | overdue | D day ≥ 11, or any later month | মেয়াদোত্তীর্ণ | Overdue | solid deep crimson |

Labels are adopted verbatim from `03-ux.md` (UX Lead owns tokens/icons). Note: L2 "মনে করান" is the same word as the Remind (share) button; acceptable because the badge always carries its icon + colour and the button carries the share icon — builders must not render the badge as a tappable button. "মেয়াদোত্তীর্ণ" is formal but universally understood and short enough for a badge; in full sentences use plain words ("…বেতন এখনো দেয়নি, আজ ১২ তারিখ").

Colour is never the only signal: each level also shows its label, icon and "আজ ৫ তারিখ" style day text (accessibility + colour-blindness).

**Aggregation (student/enrollment level)**
- Enrollment severity = max level over its open due months. Student severity = max over active enrollments.
- Show **count of open due months and total remaining**, e.g. "৩ মাস বাকি · ৳৩,০০০ · মেয়াদোত্তীর্ণ".
- If ≥ 2 due months are open, the badge adds "৩ মাস" regardless of level; oldest due month shown ("মার্চ থেকে").
- Example message on Home/profile (matches contract): "জেসন মার্ক এখনো নভেম্বরের বেতন দেয়নি, আজ ৫ তারিখ।" / "Jason Mark hasn't paid November's fee — it's already the 5th."
- **Sorting in dues list:** severity desc → number of open months desc → total desc → name.
- Home dues card: count of students per level (levels 1-6), total outstanding (active), plus line for left/archived outstanding.

**Worked examples (today = 2026-11-05)**
- Prepaid, Nov unpaid → D = Nov, day 5 → Level 3 "তাগাদা দিন".
- Postpaid, Oct unpaid → D = Nov, day 5 → Level 3. Postpaid Nov → upcoming (due 1 Dec).
- Prepaid, Oct + Nov unpaid → Oct is overdue → enrollment Level 6, "২ মাস বাকি".
- Prepaid, Nov partial (500 of 1000) → Level 3, remaining ৳500.

### 3.6 Attendance rules
- **Statuses:** Present (উপস্থিত), Absent (অনুপস্থিত), Late (দেরি); SHOULD: Leave (ছুটি).
- **Session = one class occurrence** = (batch, date, start time). A batch can meet more than once a day (e.g. exam-week morning + evening), so two classes in a day = **two roll calls = two held sessions**, each counted separately in %, streaks and history. A session exists only once its roll call is saved; an unsaved occurrence = class not held (not counted anywhere). The session is linked to its occurrence (slot or exception record), so if that occurrence's time is later corrected, the saved roll call moves with it.
- **Schedule drives the entry points:** Home/Today lists each of today's effective occurrences as its own row with its time (e.g. "Physics A · সকাল ৮:০০" and "Physics A · বিকাল ৫:০০"), each with its own ✓ state; the class-reminder notification opens that specific occurrence's roll call. A **rescheduled** class is taken on its new date; an **extra** class is a normal held class (counts in % once saved); a **cancelled** occurrence offers no roll call and never counts.
- Roll call opens with **all listed students = Present** (not configurable; a "সবাই অনুপস্থিত" header action covers the rare opposite case). Tap toggles Present ↔ Absent; long-press (or a chip row) chooses Late/Leave. Header shows live counts "উপস্থিত ২৮ · অনুপস্থিত ২".
- **Who is listed:** students whose enrollment in this batch covers the date (join date ≤ date, and not after left/end date), active student status as of that date. Sorted by student ID then name (stable order helps the teacher's memory).
- **Opening roll call from the batch's attendance tab by date:** one occurrence that date → open it; several → pick one from a list of times; none → "নতুন ক্লাস" with a start/end prefilled from the batch's most common slot time (editable).
- **Unscheduled date/time** (no occurrence matches): allowed, never blocked. Saving the roll call silently creates an **extra-class exception** for that date + start/end, i.e. a new occurrence (conflict check §3.10 runs, including against the batch's own other classes that day; if it clashes, the teacher must pick a time — the roll call is not lost). Note shown: "এই সময়ে রুটিনে ক্লাস নেই — অতিরিক্ত ক্লাস হিসেবে রাখা হবে". If the chosen occurrence was cancelled, the note is "এই ক্লাস বাতিল ছিল — হাজিরা নিলে বাতিল উঠে যাবে" and saving removes the cancel exception. Future dates blocked. Archived batches: read-only.
- **Editing past days:** any past session editable with no lock; deleting a session ("ক্লাস হয়নি") allowed with confirm.
- **Attendance %** for an enrollment over a period = (Present + Late) ÷ (sessions held in the period while enrolled − Leave) × 100, rounded to whole %. Shown for "this month" and "all time". Batch % = mean of its students' % for the period. No sessions → "—" not 0%.
- **Absence streak (F16):** last 3 held sessions (occurrences, so two absences on one double-class day count as two) of that batch (while enrolled) all Absent → alert. Late or Leave breaks/does not count.
- Attendance never affects fees.

### 3.7 Monthly collection summary (F14)
Month picker (default current month). Two blocks:
1. **Billing month M** (per batch + total): Expected (sum of fee(M) over billable, non-waived enrollments), Received (allocations to M), Waived (count + amount), Outstanding (Expected − Received, ≥ 0), Paid-students count / total. Tapping Outstanding opens dues list filtered to M.
2. **Cash in during calendar month M:** sum of payments whose *payment date* is in M (includes advance and arrears), broken down by method; plus Other income (F22) if built.

### 3.8 Data rules that support backup/sync
- Every record has a stable UUID, `createdAt`, `updatedAt`, `deletedAt` (soft delete / tombstone), `updatedByDevice`.
- Deleting a subject/batch/student with history is a soft delete with confirm showing what goes with it ("১২০টি হাজিরা ও ৩০টি পেমেন্ট সহ মুছে যাবে"). Prefer archive/left over delete; delete is behind a secondary menu.
- Schedule slots, schedule exceptions and synced settings (§3.12) are records like any other (UUID, timestamps, tombstones).

### 3.9 Class schedule (রুটিন)
- **Weekly slot** = (batch, weekday, start time, end time, effective-from date). A batch has **1+ slots**; different weekdays may have different times, and **one weekday may have several slots** (e.g. Fri 08:00–09:00 and Fri 17:00–18:00) as long as they don't overlap (§3.10 applies to the same batch). Both times required; end > start; same day (no midnight crossing); 5-minute granularity. New slot form prefills end = start + the batch's last-used duration (default 60 min).
- **Editing/removing a slot** takes effect from a chosen date ("কোন তারিখ থেকে?", default today): occurrences before it are unchanged (history and past sessions stay intact); implemented as end-dating the old slot and starting a new one.
- **Exceptions** (per occurrence; an occurrence is identified by batch + date + start time):
  - **Cancel** (ক্লাস বাতিল): removes that one occurrence (other classes of the batch that day are untouched). Optional reason. Reversible ("বাতিল তুলে নিন").
  - **Reschedule** (সময় বদল): moves one occurrence from its original date/time to a new date + start/end (same or different day, including a day that already has a class of this batch). The original date shows "→ ১২ নভে ৫:০০" on the schedule; the new date shows the class with a "সময় বদল" tag.
  - **Extra class** (অতিরিক্ত ক্লাস): adds a one-off occurrence (date, start, end).
- **Effective occurrences** for a date = each active batch's slot occurrences on that weekday (slot effective on that date, batch not archived, date on/after the batch's creation) − cancelled − rescheduled-away + rescheduled-in + extras.
- **Multiple occurrences per batch per date are allowed** (from several slots on a weekday and/or extras/reschedules onto a day that already has a class of this batch). The **only** limit is the `[start, end)` overlap rule (§3.10), which applies to the batch's own classes too.
- Exceptions on past dates are allowed (to record what actually happened); future slots/exceptions are the norm.
- Week starts on the Settings week-start day (default **Saturday**) in the weekly view and all weekday pickers.

### 3.10 Time-conflict detection (hard block)
- **Conflict (LOCKED):** two effective occurrences on the same date whose `[start, end)` intervals overlap, i.e. `a.start < b.end && b.start < a.end`. 10:00–11:00 vs 10:30–11:30 = conflict; 10:00–11:00 vs 11:00–12:00 = fine. Applies across **all active batches, including the same batch**. Cancelled occurrences free their time. **Archived batches are ignored.**
- **When checked:** on saving a weekly slot (new or edited), a reschedule, an extra class, an unarchive, and a cancel-removal ("বাতিল তুলে নিন"). Removing/cancelling never needs a check.
- **What a slot save is checked against:** every *other* effective occurrence that would fall on that weekday from the slot's effective-from date onward — i.e. other batches' recurring slots whose effective ranges overlap, **plus all future one-off occurrences (extras and rescheduled-in) on that weekday**. The occurrence being moved/replaced is excluded from its own check (moving 10:00–11:00 to 10:30–11:30 the same day is not a clash with itself). Occurrences that the same save makes disappear are excluded too.
- **Block UX:** save is refused; the dialog lists each clash as "{subject} · {batch} · {date or 'প্রতি শনিবার'} · {start}–{end}" (max 3 + "আরও N টি"), then **suggestions**: the nearest free start **earlier** and **later** on the same date (for a slot: free on every checked date of that weekday), same duration, starts on 5-minute steps, within the day window **06:00–23:00**; nearest by absolute shift, ties prefer later. Tapping a suggestion fills the form; teacher saves again. If none: "এই দিনে একই দৈর্ঘ্যের খালি সময় নেই".
- **A recurring slot clashing with a single future one-off** is still blocked; the dialog names the one-off date so the teacher can move or cancel it first (no auto-resolution).
- **Pre-existing conflicts** can only arrive via backup merge (§4) or unarchive. The app never changes a schedule silently. Instead: unarchive shows the clashes and offers "আর্কাইভ তুলুন ও রুটিন ঠিক করুন" (unarchives, then opens the batch's slot editor); merge reports them in the change summary. Until fixed, a red "সময়ের সংঘাত" banner shows on the schedule view and on Home for affected dates, with a "ঠিক করুন" link. Both conflicting occurrences still appear and still get reminders. Saving an edit to **either** party runs the normal check (must end conflict-free for the item saved); editing an unrelated item is not blocked by a legacy conflict it isn't part of.

### 3.11 Class reminders (notifications)
- **Lead time:** `batch.reminderLead` (nullable) → if null use Settings default (**15 min**). Batch picker offers: "ডিফল্ট (১৫ মিনিট)" · 5 · 10 · 15 · 20 · 30 · 60 · কাস্টম (1–180 min) · বন্ধ (off for this batch).
- **Global switch** in Settings (default **on**). Off = no class notifications at all; per-batch values are kept.
- **Fire time** = occurrence start − lead, for every effective occurrence (cancel/reschedule/extra respected). If fire time is already past when computed (e.g. extra class created 5 min before it starts), no notification.
- **Recompute** the scheduled set whenever a slot, exception, batch (archive, lead), global default or global switch changes, on app start, daily, and on device reboot (Android). Changing the Settings default immediately re-times all batches whose lead is null. Horizon: next **7 days** of occurrences (keeps under OS alarm limits; rolled forward on recompute).
- **Text** (language = app language at scheduling time; recompute on language change):
  - Title: `{subject} · {batch}`
  - Body bn: `{start}–{end} ক্লাস — {N} মিনিট পর` + suffix ` (অতিরিক্ত ক্লাস)` / ` (সময় বদলানো)` when applicable. Example: title "পদার্থবিজ্ঞান · ব্যাচ A", body "বিকাল ৪:০০–৫:০০ ক্লাস — ১৫ মিনিট পর".
  - Body en: `Class {start}–{end} — in {N} min` + ` (extra class)` / ` (rescheduled)`.
- **Tap → opens that specific occurrence's roll call** (batch + date + start time), straight into F5 (cold start included). If that occurrence was cancelled after the notification fired, open the batch's schedule with a "এই ক্লাস বাতিল" note instead.
- **Permissions:** Android 13+ notification permission is requested the first time a batch with a slot is saved (one-line Bangla rationale first). Exact alarms: request on the same moment; if denied, use inexact scheduling and show in Settings "রিমাইন্ডার কয়েক মিনিট দেরিতে আসতে পারে". Never nag more than once per app version.
- **Platforms:** Android must fire with the app closed. Windows: scheduled toast, best effort (must work while the app is running or minimised). Web: no notifications; Home shows "পরের ক্লাস: …" only.
- Conflicting (legacy) occurrences each get their own notification.

### 3.12 Settings (definitive list)
Business settings marked **(sync)** travel in backups/merge (LWW per key); the rest are **device-only**. Per-batch things (fee, billing type, slots, reminder lead) live on the batch, never here.

| Section | Item | Default | Why it's here |
|---|---|---|---|
| সাধারণ (General) | Language বাংলা / English | বাংলা | Contract; one tap. Device-only. |
| | Theme: সিস্টেম / লাইট / ডার্ক | সিস্টেম | Contract item 8; dark for evening PC work. Device-only. |
| | Week starts on: শনি / রবি / সোম | শনি | BD default Sat, but some think in Sun-weeks; affects weekly view + pickers only. (sync) |
| কোচিং সেন্টার | Center name | empty (asked in first-run) | Appears on receipts and reminders. (sync) |
| | Contact phone | empty | Same. (sync) |
| | Address (optional) | empty | Receipt footer; some guardians need it. (sync) |
| ক্লাস রিমাইন্ডার | Reminders on/off | on | Locked. Device-only (phone may want them, PC not). |
| | Default lead time (5/10/15/20/30/60/custom) | 15 min | Locked; batches without their own value use it. (sync) |
| বেতন ও পেমেন্ট | New-admission billing cutoff day (1–28) | 15 | Real policy difference between teachers ("after the 20th starts next month"). (sync) |
| | Payment methods (show/hide built-ins, add custom e.g. "উপায়") | ক্যাশ, বিকাশ, নগদ, রকেট, ব্যাংক on | Wallets differ by teacher; hiding unused ones speeds the payment form. (sync) |
| | Reminder message template (bn + en) | §5 | Teachers have their own tone. (sync) |
| | Receipt template (bn + en) | §5 | Same. (sync) |
| ব্যাকআপ | Export now / Import (merge) | — | §4. Shows "শেষ ব্যাকআপ: ৩ দিন আগে". |
| | Backup reminder: 3 / 7 / 14 / 30 days / off | 7 days | F18; data loss is the worst failure. Device-only. |
| | Restore a safety copy (last 3) | — | Undo for a bad import. |
| | This device's name | device model | Shown in backup info / change summary. Device-only. |
| সম্পর্কে (About) | Version, font credit, help | — | Support. |

**Deliberately excluded:** warning escalation thresholds (contract fixes day 1→10; configurable bands would break consistency and the acceptance tests) · currency (BDT only) · date format (follows language) · attendance default state (all-present is the contract; "সবাই অনুপস্থিত" action covers exceptions) · default billing type for new batches (smart default = last used, no setting needed) · absence-streak length (3 is fine) · last-billable-month cutoff (always shown and editable in the leave/archive dialog) · font size (follow OS accessibility scaling instead).

---

## 4. Backup & sync product rules

### v1 ships: local file export / import (import = per-record MERGE)
- **Export:** "ব্যাকআপ নিন" → single file `coaching-backup-YYYY-MM-DD-HHmm.<ext>` containing all records **including tombstones** and synced settings → OS save/share sheet (Drive app, WhatsApp-to-self, USB all work). Records `lastExportAt`.
- **Import:** pick file → app validates (format/version; newer-schema backups refused with "অ্যাপ আপডেট করুন") → computes the merge → shows **Change summary** → teacher confirms → app first keeps an automatic **safety copy** of the current data (last 3 kept, "সেফটি কপি থেকে ফেরত আনুন" in Settings) → applies the merge in one transaction (all or nothing).

### Merge rules (LWW per record)
Match by UUID, entity by entity (subjects, batches, slots, schedule exceptions, students, enrollments, fee history, attendance marks, payments + allocations, waivers, synced settings by key):

| Backup has | Device has | Result |
|---|---|---|
| record | nothing | **Add** |
| nothing | record | **Keep** device record (absence in a backup never deletes) |
| record | record | Newer `updatedAt` wins whole record (tie → lexicographically higher `updatedByDevice`); if backup wins and content differs → **Update** |
| tombstone | live record | Tombstone newer → **Delete** (soft); otherwise device record kept |
| live record | tombstone | Record newer → **Restore**; otherwise stays deleted |
- No field-level merge. Derived values (dues, %, statuses) are recomputed after merge, never imported.
- After merge, run conflict detection (§3.10) over future occurrences; any clashes are listed in the summary and raise the "সময়ের সংঘাত" banner. Payment allocations that would overfill a month after merge are kept as recorded (no data dropped) and the month shows as Paid; the summary flags "N টি মাসে বেশি টাকা জমা" for the teacher to review.
- Importing the same file twice → second time "কোনো পরিবর্তন নেই" (idempotent).

### Change summary screen (must show)
1. Backup info: created date/time, device name, app version, totals (subjects, batches, students, payments).
2. Headline: "এই ব্যাকআপ থেকে N টি পরিবর্তন আসবে" or "কোনো পরিবর্তন নেই — সব আগে থেকেই আছে" (apply disabled).
3. Table, per entity — Subjects, Batches, Schedule (slots + exceptions), Students, Enrollments, Attendance (count sessions, not individual marks), Payments, Settings: **Added / Updated / Deleted** counts, plus a small "আপনার নতুন তথ্য রাখা হবে: N" line (device records newer than the backup's copy).
4. Up to **3 sample names** per non-zero bucket (students/batches/subjects by name; payments as "নাম · ৳১০০০ · ৫ নভে"; sessions/schedule as "ব্যাচ · তারিখ"), "+N more".
5. **Deletions** shown in red and listed first; schedule conflicts that the merge would create listed after them in red.
6. Buttons: "প্রয়োগ করুন" (primary) / "বাতিল".

### Two-device expectations
- v1: phone and PC can both be used; move a backup file either way and import — nothing newer on the receiving device is lost; deletions only happen through tombstones. Last-writer-wins per record is acceptable for one teacher (rare same-record edits on both devices: newer edit wins, summary counts it under Updated).
- LATER (Drive sync): devices push versioned snapshots to a shared folder; pull runs the **same merge and change summary**. The v1 data model (§3.8) and merge code are reused unchanged.
- Tombstones are kept forever in v1 (small); purge is LATER.

---

## 5. Bangla copy guidance

**Tone:** respectful, plain, spoken-Bangla words a teacher uses daily; short. "আপনি" form. No officialese in sentences (avoid "অনুগ্রহপূর্বক"); the one sanctioned formal word is the OD badge label "মেয়াদোত্তীর্ণ" (§3.5). Times are 12-hour: Bangla prefixes the period word once per range — ভোর (4–6), সকাল (6–12), দুপুর (12–3), বিকাল (3–6), সন্ধ্যা (6–8), রাত (8–4) — e.g. "বিকাল ৪:০০–৫:০০"; English "4:00–5:00 PM". Common English loanwords are fine where they are the natural word (ব্যাচ, ব্যাকআপ, রোল). Money as "৳১,০০০" (Bangla digits, Indian grouping not required — use standard thousand separators). Dates "৫ নভেম্বর ২০২৬"; months in Bangla using Gregorian names (জানুয়ারি…ডিসেম্বর), not Bengali calendar. Weekdays: শনি রবি সোম মঙ্গল বুধ বৃহঃ শুক্র (week starts Saturday in pickers).

**Glossary (use these exact words everywhere)**

| English | Bangla | Note |
|---|---|---|
| Subject / Class | বিষয় / ক্লাস | Screen title "বিষয় ও ক্লাস" |
| Batch | ব্যাচ | |
| Student | শিক্ষার্থী | "ছাত্র" is gendered; use শিক্ষার্থী |
| Student ID / Roll | আইডি / রোল | |
| Guardian | অভিভাবক | |
| Admission | ভর্তি | Admission date = ভর্তির তারিখ |
| Attendance / Roll call | হাজিরা | "হাজিরা নিন" |
| Present / Absent / Late / Leave | উপস্থিত / অনুপস্থিত / দেরি / ছুটি | Short chips: উ / অ / দে / ছু |
| Monthly fee | মাসিক বেতন | "বেতন" for monthly; "ফি" for one-off (ভর্তি ফি) |
| Payment (received) | টাকা জমা / পেমেন্ট | Button: "টাকা নিন" |
| Due (outstanding) | বকেয়া / বাকি | "বকেয়া" for list title; "বাকি" in sentences |
| Prepaid | অগ্রিম (মাসের শুরুতে) | Selector helper text explains |
| Postpaid | মাস শেষে (পরের মাসের শুরুতে) | Avoid "পোস্টপেইড" |
| Paid / Partial / Unpaid | পরিশোধিত / আংশিক / বাকি | |
| Overdue | মেয়াদোত্তীর্ণ | Badge/filter label (UX); sentences use plain wording |
| Due levels L1–L5 | নতুন বকেয়া / মনে করান / তাগাদা দিন / জরুরি / শেষ সময় | Exact, from §3.5 |
| Waived | মাফ | |
| Discount / fee override | ছাড় / বিশেষ বেতন | |
| Cash / bKash / Nagad / Rocket / Bank | ক্যাশ / বিকাশ / নগদ / রকেট / ব্যাংক | **Cash = ক্যাশ**, never নগদ (clashes with Nagad) |
| Receipt | রসিদ | |
| Reminder (dues message) | মনে করান | Share button on dues rows/profile (matches UX) |
| Class reminder (notification) | ক্লাস রিমাইন্ডার | Never "মনে করান" — keeps the two features apart |
| Schedule / timetable | রুটিন | Screen title "ক্লাস রুটিন" |
| Slot (weekly) | সাপ্তাহিক ক্লাস | "প্রতি শনিবার ৪:০০–৫:০০" |
| Cancel class / Reschedule / Extra class | ক্লাস বাতিল / সময় বদল / অতিরিক্ত ক্লাস | |
| Time conflict | সময়ের সংঘাত | Message: "এই সময়ে আরেকটি ক্লাস আছে" |
| Holiday closure | ছুটি ঘোষণা | F28 |
| Theme / Light / Dark / System | থিম / লাইট / ডার্ক / সিস্টেম অনুযায়ী | |
| Settings | সেটিংস | |
| Left (student) | ছেড়ে গেছে | |
| Archive (batch) | আর্কাইভ (বন্ধ ব্যাচ) | |
| Collection summary | মাসিক আদায় | |
| Backup / Import / Safety copy | ব্যাকআপ / ব্যাকআপ যোগ করুন (ইম্পোর্ট) / সেফটি কপি | Import merges, so avoid "রিস্টোর" wording |
| Search | খুঁজুন | |
| Save / Cancel / Delete / Edit | সংরক্ষণ / বাতিল / মুছুন / এডিট | |

**Default templates** (editable in Settings; placeholders in `{}`)

Reminder (বাংলা):
```
সম্মানিত অভিভাবক,
{student}-এর {batch} ব্যাচের {months} মাসের বেতন মোট ৳{amount} এখনো বাকি আছে। অনুগ্রহ করে দ্রুত পরিশোধ করুন।
ধন্যবাদ — {center} ({teacher_phone})
```
Reminder (English): `Dear Guardian, {student}'s fee for {batch} for {months} (total ৳{amount}) is still due. Please pay at your earliest. Thank you — {center} ({teacher_phone})`

Receipt (বাংলা):
```
রসিদ — {center}
শিক্ষার্থী: {student} ({id})
ব্যাচ: {batch}
মাস: {months}
জমা: ৳{amount} ({method}), তারিখ {date}
{remaining_line}
ধন্যবাদ।
```
`{remaining_line}` = "বাকি: ৳X" if any open due months remain, else "সব বেতন পরিশোধিত ✓". `{months}` = Bangla month list, e.g. "অক্টোবর, নভেম্বর ২০২৬".
Template language follows the app language at the moment of sharing.

---

## 6. Success metrics & acceptance

### Teacher success metrics (measured by QA with a seeded 30-student batch)
| Metric | Target |
|---|---|
| Roll call, 30 students, 3 absent, from Home to saved | ≤ 20 s, ≤ 6 taps |
| Record a one-month payment from Home (search → save) | ≤ 30 s |
| See full list of who hasn't paid this month | ≤ 2 taps from Home, < 10 s |
| Send a reminder to one guardian | 2 taps from dues list (Remind → pick app) |
| Find a student by phone fragment | Results as you type, < 1 s with 300 students |
| Naive tester completes core flow (contract DoD) unaided | Yes, in Bangla |
| Backup → import on other device with summary understood | Naive tester explains what will change |
| Reschedule one class incl. resolving a clash via suggestion | ≤ 30 s |
| Class reminder accuracy (Android, exact alarms granted) | Fires within ±1 min of start − lead; 0 reminders for cancelled classes |

### Acceptance scenarios (QA & Judge test exactly these)
Seed unless stated: subject "Physics" → batch "Physics A" (prepaid, ৳1000, slots Sat/Mon/Wed 16:00–17:00, reminder lead = null); subject "Chemistry" → batch "Chem B" (postpaid, ৳800, slots Sun/Tue 10:00–11:00, reminder lead = 30). Settings default lead 15, reminders on. Dates are device dates (2026-11-21 is a Saturday).

1. **Prepaid escalation.** Given Rahim enrolled in Physics A with FBM = Oct 2026 and October paid, When today is 2026-11-01 / 11-03 / 11-05 / 11-07 / 11-09 / 11-11, Then Rahim's Nov due shows L1 / L2 / L3 / L4 / L5 / OD with labels নতুন বকেয়া / মনে করান / তাগাদা দিন / জরুরি / শেষ সময় / মেয়াদোত্তীর্ণ.
2. **Postpaid timing.** Given Karim in Chem B with FBM = Nov 2026, When today is 2026-11-20, Then Karim has no warning and his profile shows Nov as "আগামী" (due 1 Dec); When today is 2026-12-05, Then Nov shows Level 3.
3. **Multi-month.** Given Rahim (prepaid) has Sep, Oct, Nov unpaid, When today is 2026-11-02, Then he shows Level 6, "৩ মাস বাকি · ৳৩,০০০", "সেপ্টেম্বর থেকে", and sorts above Level-1..5 students in the dues list.
4. **Partial.** Given Nov unpaid for Rahim, When ৳600 is recorded for Nov on 11-04, Then Nov is আংশিক with ৳400 remaining and still Level 2; When ৳400 more is recorded, Then Nov is পরিশোধিত and Rahim disappears from the dues list.
5. **Multi-month payment auto-allocation.** Given Sep, Oct, Nov unpaid, When teacher records ৳2,500 without touching allocation, Then Sep and Oct are Paid, Nov is Partial ৳500 paid, and the receipt says "মাস: সেপ্টেম্বর, অক্টোবর, নভেম্বর (আংশিক)" and "বাকি: ৳৫০০".
6. **Mid-month admission.** Given Physics A, When a student joins on 2026-11-10, Then FBM defaults to Nov 2026; When a student joins on 2026-11-20, Then FBM defaults to Dec 2026; the teacher can change either; no prorated amounts appear anywhere.
7. **Multiple batches.** Given Sara is in Physics A and Chem B, When she pays Physics A for Nov, Then Physics A Nov is Paid and Chem B dues are unaffected; her profile shows dues per batch and a combined total.
8. **Left student.** Given Rahim owes Oct and Nov, When he is marked Left on 2026-11-05, Then LBM defaults to Oct 2026 (day < 11), Nov becomes Not billable, Oct stays owed and appears under "ছেড়ে যাওয়া / আর্কাইভ" in grey, he is excluded from Home severity counts and from Physics A roll call after 11-05.
9. **Archive.** Given Physics A archived on 2026-11-15, Then Nov is the LBM for all its students, Dec never becomes due, the batch disappears from Home/Today and roll call, existing dues remain visible in the grey group, and unarchive restores it.
10. **Waive & free.** Given Rahim owes Nov, When Nov is marked মাফ, Then it is not a due and the summary counts it under Waived; Given a student with fee override ৳0, Then no dues are ever generated for that enrollment.
11. **Fee change.** Given Physics A fee changes to ৳1,200 from Dec 2026, Then Nov expected stays ৳1,000 and Dec expected is ৳1,200 for students without overrides; a student with override ৳800 stays ৳800.
12. **Roll call.** Given Physics A has 30 active students on a Saturday, When teacher opens it from Home, Then all 30 are Present; When he taps 3 students and saves, Then counts read উপস্থিত ২৭ · অনুপস্থিত ৩, Home shows the batch ✓, and each student's month % updates. When he reopens the date and changes one to দেরি, Then it counts as attended in %.
13. **Absence streak (if F16 built).** Given Rahim was Absent in the last 3 held Physics A sessions, Then Home shows an alert with a Call button; one Present/Late resets it.
14. **Reminder & receipt sharing.** When teacher taps Remind on Rahim (Oct+Nov owed, Bangla mode), Then the OS share sheet opens with the Bangla template filled (student, batch, "অক্টোবর, নভেম্বর", ৳২,০০০, center name), all digits Bangla; in English mode the English template with Latin digits.
15. **Backup merge & change summary.** Given phone P and PC W share the same data; then on P the teacher adds student Nila, edits Rahim's phone, and deletes student Tuhin; meanwhile on W he adds 1 payment for Sara and later (after P's edit) edits Rahim's guardian name; P exports. When W imports P's backup, Then the summary shows Students: Added 1 (Nila), Deleted 1 (Tuhin, in red, listed first), Updated 0 for Rahim with "আপনার নতুন তথ্য রাখা হবে: 1"; nothing changes until "প্রয়োগ করুন"; after applying, W has Nila, no Tuhin, Sara's payment intact, and Rahim = W's version (newer whole record wins). Importing the same file again shows "কোনো পরিবর্তন নেই". Settings → safety copy restores W's pre-import state.
16. **Language.** When language is switched to English and back, Then every visible string, number, date, time and month name switches (incl. scheduled notification texts), with no restart and no mixed-script digits.
17. **Conflict — overlap blocked + suggestions.** Given Chem B's Sunday slot 10:00–11:00 and a Physics A extra class on Sun 2026-11-22 11:00–12:00, When the teacher saves an extra class for new batch "Math C" on 2026-11-22 10:30–11:30, Then save is refused citing "Chemistry · Chem B · ২২ নভে · সকাল ১০:০০–১১:০০" and "Physics · Physics A · ২২ নভে · সকাল ১১:০০–দুপুর ১২:০০", with suggestions earlier "সকাল ৯:০০–১০:০০" and later "দুপুর ১২:০০–১:০০"; tapping a suggestion and saving succeeds. Also: a Chem B extra on 11-22 10:30–11:30 is refused for overlapping Chem B's own 10:00–11:00 class, while a Chem B extra on 11-22 17:00–18:00 saves.
18. **Touching times allowed.** Given Chem B Sun 10:00–11:00, When a Math C weekly slot Sun 11:00–12:00 is saved, Then it saves without warning; When it is edited to Sun 10:55–11:55, Then it is refused citing "Chemistry · Chem B · প্রতি রবিবার · সকাল ১০:০০–১১:০০".
19. **Reschedule clash.** Given Physics A Mon 2026-11-23 16:00–17:00 and Chem B Tue 2026-11-24 10:00–11:00, When the teacher reschedules Physics A's 11-23 class to 11-24 10:30–11:30, Then it is refused citing Chem B 10:00–11:00 on 24 Nov with free suggestions; When rescheduled to 11-24 11:00–12:00 instead, Then it saves, 11-23 shows "→ ২৪ নভে সকাল ১১:০০", and 11-24's Today list shows Physics A with "সময় বদল".
20. **Slot vs future one-off.** Given Chem B has an extra class on Thu 2026-11-26 16:30–17:30, When the teacher adds a Physics A weekly slot Thu 16:00–17:00 effective today, Then it is refused naming Chem B's extra on ২৬ নভে (no other Thursdays clash); after that extra is moved to 17:00–18:00, the slot saves. Past Physics A sessions are unaffected by any slot edit.
21. **Archived ignored.** Given batch "Old Bio" archived with slot Sat 16:00–17:00, Then Physics A's Sat 16:00–17:00 does not conflict; When Old Bio is unarchived, Then the dialog lists the clash, unarchive proceeds only via "আর্কাইভ তুলুন ও রুটিন ঠিক করুন", and the "সময়ের সংঘাত" banner shows until one slot is changed.
22. **Reminder lead fallback.** Given Physics A lead = null and Chem B lead = 30, Then Saturday's Physics A 16:00 notification is scheduled for 15:45 and Sunday's Chem B 10:00 for 09:30; When the Settings default is changed to 10, Then Physics A's pending notifications move to 15:50 immediately and Chem B's stay at 09:30; When Physics A's 11-21 class is cancelled, Then its notification is removed; an extra Physics A class 11-26 18:00 gets one at 17:50.
23. **Notification → roll call.** When the teacher taps the Physics A notification, Then the app opens directly on the roll call of that exact occurrence (Physics A, that date, that start time) with all students Present; with global reminders off, no class notifications are scheduled.
24. **Theme.** Given theme = সিস্টেম, When the OS switches to dark, Then the app switches to dark without restart; When the teacher picks লাইট or ডার্ক in Settings, Then it applies instantly, persists across restarts, and ignores the OS; on every core screen (Home, roll call, dues list, profile, payment, schedule, settings, change summary) text and due badges remain legible (AA) in both modes.
25. **Two classes of one batch in a day.** Given batch Physics A has a 08:00–09:00 class on 2026-12-12, When the teacher adds an extra class for Physics A on 2026-12-12 17:00–18:00, Then it saves, Today on 12 Dec shows two Physics A rows ("সকাল ৮:০০–৯:০০" and "বিকাল ৫:০০–৬:০০"), each has its own roll call, reminder and ✓ state; saving both roll calls counts as 2 held sessions in each student's %; an extra Physics A class on 12 Dec 08:30–09:30 is refused (overlaps its own 08:00–09:00 class). Likewise, weekly slots Fri 08:00–09:00 and Fri 17:00–18:00 can coexist on one batch.

---

## 7. Defaults summary (for builders' quick reference)
Billing type: last used, first ever prepaid · FBM cutoff day 15 (Settings) · slot duration default 60 min, 5-min steps, multiple non-overlapping slots/occurrences per batch per day allowed; session/roll call = per occurrence (batch + date + start) · conflict = `a.start < b.end && b.start < a.end`, archived ignored, cancelled frees time · suggestion window 06:00–23:00 · reminder default lead 15 min, presets 5/10/15/20/30/60/custom 1–180/off, horizon 7 days · theme default system · import = per-record LWW merge, tombstones apply, safety copy first · LBM cutoff day 10 (left/archive on day ≥ 11 bills that month) · warning bands 1-2 / 3-4 / 5-6 / 7-8 / 9-10 / ≥11 · advance allocation ≤ 12 months · absence streak 3 sessions · backup nudge 7 days (Settings: 3/7/14/30/off) · safety copies kept 3 · week starts Saturday · payment method default Cash · language default Bangla.
