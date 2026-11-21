# 14 — Visual QA of the fluid redesign (live build, 2026-11-21)

Build tested: `https://im-rudra.github.io/attendance-alamin/?r=vq7` (fresh IndexedDB + localStorage).
Test data: 2 subjects (গণিত, ইংরেজি), 3 batches (বিকাল ৪টার ব্যাচ advance, সকালের ব্যাচ **postpaid**, সন্ধ্যা ব্যাচ), 7 students, one with fees starting August (৩ মাস বাকি), 2 roll calls, 2 payments (one from Fees, one from the Today dues row), 1 other-income entry (ভর্তি ফি ৳৫০০).
Viewports: phone 375×812 and desktop 1366×860, light and dark.
Measured against `13-fluid-ui-spec.md` (the target) and `12-ux-review.md` (§3 navigation, §4 motion).

> Caveat on motion: the Browser pane was reported **hidden** for most of the session. Flutter's canvas is throttled while hidden, so I did not judge durations or easing curves. Motion findings below cover only what was clear from frames: wrong layering, overlaps, missing morphs, and containers that are wrong at rest.

---

## 1. Verdict

**Premium at rest, not yet fluid in motion. About 75% of the way to the bar.**

What lands:
- The token palette, soft filled fields with floating labels, pill chips with a sliding ✓, the switch, the segmented thumb (with a spring overshoot), Phosphor icons and the floating phone nav pill all match the mock and look expensive in both themes.
- The hero card is right (the only gradient; near-white CTA; "আজকের সব ক্লাস শেষ" done state).
- The adaptive container works where it is wired: desktop side panels for edit student, new/edit batch, slot editor, payment, payment methods and templates; centred dialogs for add-to-batch and backup.
- The success ✓ pop in sheets and the toasts with undo are good.

What breaks the "fluid, never boring" promise:
1. **Transitions double-expose.** Onboarding steps, phone push/pop and the roll-call dismiss all cross-fade two fully opaque-text pages over each other. For roughly 200–400 ms you see both screens' text on top of each other, which reads as a glitch, not motion.
2. **Wrong container on desktop for every small menu or picker.** The date picker opens as a phone bottom sheet, clipped at the bottom of the window. The time picker, the ⋮ menus and the roll-call row menu are centred dialogs instead of anchored popovers.
3. **Two competing "overdue" languages.** A solid raspberry pill (`BhorTag.severity`) shows on Today, Students, Batches and profile, and a tinted pill shows on Fees. On the profile the solid pill repeats 4–5× and dominates the screen.
4. **Long forms in short phone sheets.** New batch, add student and collect payment open at about 55% height and never expand. The key input (amount) or the save button starts off-screen.
5. **Leftover outlined styling.** Nested outlined boxes in the batch form, outlined quick actions, an accent-outlined day pill, outlined selected select-item, outlined week-view events and the left status stripe on roll-call rows all fight the "soft, filled, hairlines only" rule.
6. **Missing success morphs.** The roll-call save shows a spinner on top of the label, with no ✓ morph. Toasts from full-screen routes land on top of the phone nav pill.

Fix the six Blocker/Major clusters (tables below) and this will clear the bar.

---

## 2. Defects

Severity: **B** = Blocker, **M** = Major, **m** = Minor. Platform: P = phone, D = desktop. Theme: L = light, D = dark, both = both.

### 2.1 Shell, transitions, global (lib/app/shell, lib/app/ds)

| # | Screen | Plat | Theme | What's wrong | Exact fix | Sev | Owner |
|---|---|---|---|---|---|---|---|
| G1 | All phone pushes and pops (batch list ↔ detail, Fees ↔ collection) | P | both | The push/pop cross-fades two pages with full-opacity text. Mid-transition both lists are legible on top of each other (seen after creating সন্ধ্যা ব্যাচ). | Implement §4.2: the incoming page gets an opaque `bg` behind it and slides +32 px while fading in; the outgoing page goes to x −16 px and opacity 0.94, under the incoming page. Never cross-fade two transparent pages. Put the page background inside the transition child. | **M** | lib/app/shell (router `CustomTransitionPage`) |
| G2 | Roll call dismiss → Today | P | both | On save, roll call scales and fades **over** Today. Both screens are readable at once for about 300 ms. | Dismiss = drop 24 px + fade out over 220 ms (`exit` curve) with the roll-call page keeping its opaque background. Today should not render text through it. | **M** | lib/app/shell |
| G3 | Toast from a full-screen route (roll call save) | P | both | The toast lands on top of the floating nav pill (it covers the আজ/ব্যাচ/শিক্ষার্থী/বেতন items) and, on roll call, on the sticky save button. | Toast host must read the bottom obstruction (nav pill height + 10 inset + sticky CTA) from the shell, not the route. Lift by `navPill + 12` and by the CTA height when present (§4.9). | **M** | lib/app/ds (`bhor_overlays.dart` toast) + lib/app/shell |
| G4 | Toast vs FAB | P | L | The payment toast overlaps the "টাকা নিন" FAB on Fees. | When a toast shows, lift the FAB by the toast height (AnimatedSlide, `base`), or hide the FAB while a toast is up. | m | lib/app/ds |
| G5 | Toast anatomy | P/D | both | The roll-call / batch toasts have no leading semantic icon, and the payment toast is a 2-line rounded rectangle. | Use a leading `CheckCircle`/`ArrowCounterClockwise` icon on every toast. Keep it a single-line pill and move the second action into an overflow or the receipt sheet. | m | lib/app/ds |
| G6 | Phone large-title headers (Today, Students, More, Fees) | P | both | Content scrolls under a translucent header with no hairline or blur, so text shows half-cut under the title. | §4.11: after 4 px of scroll, fade in the bottom hairline plus bg 80% + blur(12) over `fast`. | m | lib/app/ds (`bhor_scaffold.dart`) |
| G7 | Hover state sticks after tap | P | both | On phone (touch emulation) the hovered chip, list row, select item or icon halo stays in its soft2 hover tint after the tap (day chips সোম/বুধ, month list, search halo, back button). | Gate hover visuals on `PointerDeviceKind.mouse`. Clear hover on pointer-up for touch. | m | lib/app/ds (`bhor_interaction.dart`) |
| G8 | Scrim strength | D | both | The side-panel scrim dims the list to about 45%. The spec says 20%, with the list behind "visible and interactive-dim". | Set the side-panel scrim to `black @ 0.20` (light) / `0.35` (dark). Leave the sidebar undimmed. | m | lib/app/ds (`bhor_overlays.dart`) |
| G9 | Digits in inputs | P/D | both | Numeric fields echo Latin digits (`800`, `1000`, roll `04`) while the rest of the app is Bangla (৮০০). The other-income amount field does show ৳৫০০, so the behaviour is inconsistent. | Apply one input formatter in `BhorTextField.money/number` that renders Bangla digits when the locale is bn. | m | lib/app/ds (`bhor_text_field.dart`) |
| G10 | Desktop page headers | D | both | Titles sit 8–10 px from the window top (Today "শুভ সন্ধ্যা", Fees "বেতন", More "আরও"). Cramped compared with the 18–24 px desktop padding. | Desktop screen top padding 20–24 px. Align the title baseline with the sidebar brand row. | m | lib/app/ds (`bhor_scaffold.dart`) |

### 2.2 Design-system components (lib/app/ds)

| # | Component | Plat | Theme | What's wrong | Exact fix | Sev | Owner |
|---|---|---|---|---|---|---|---|
| C1 | `BhorTag.severity` vs `BhorTone.overdue` | P/D | both | Two "overdue" styles. Solid raspberry with white text (Today, Students list and table, Batch detail, Profile) vs tinted #FBE3E8/#A3153F (Fees list). On the profile the solid pill repeats 4–5 times in one card, so the screen shouts. | Per spec, tags are tint fill + coloured text. Make `.severity` use `overdueBg/overdue` for the overdue level. Reserve solid fill for one summary chip per screen at most (for example "মোট বকেয়া"). | **M** | lib/app/ds (`bhor_display.dart`) |
| C2 | Attendance toggle selected thumb | P/D | L (worst), D | The absent thumb `#E6E8EE` sits on a soft `#EFEDE8` track, so the selected state is nearly invisible. The present thumb `#E2F3EC` is also faint. | Thumb = surface (white / `#2E323C` dark) with a 1 px tone-coloured inner ring and a tone icon. Or raise to `okBg`→`ok@22%`, `absentBg`→`absent@24%`. Must reach 3:1 against the track. | **M** | lib/app/ds (`bhor_domain.dart` `BhorAttendanceToggle`) |
| C3 | Segmented thumb, dark | P/D | D | The dark thumb is barely lighter than the track (language, week-start, বকেয়া/আদায়). The selected segment is hard to read. | Dark thumb = `soft2 #2E323C` + 1 px line `#3A3F4B` + text `#EDEEF2`. The track stays `#21242C`. | **M** | lib/app/ds (`bhor_choice.dart`) |
| C4 | Button loading state | P/D | both | Roll-call save shows a spinner **on top of** the label text ("হাজিরা সেভ করুন" overlapped). There is no ✓ "হয়েছে" morph. | Cross-fade label → spinner (label opacity 0), then morph width to 48 → ✓ with `spring.pop`, then pulse the ring (§4.10). | **M** | lib/app/ds (`bhor_button.dart`) |
| C5 | Bottom sheet height | P | both | Sheets size to about 55% and never expand. Dragging the handle up does nothing. New batch, add student (new-student step) and collect payment hide their primary input or save below the fold. | Implement XS: detents at 60% and 100% with `spring.gentle`. Auto-expand to 100% when the content is taller than 60% or a field gains focus. Radius 28→0 at full. | **M** | lib/app/ds (`bhor_overlays.dart`) |
| C6 | Sticky footer in sheets | P | both | The "শিক্ষার্থী যোগ করুন → নতুন" sheet has its save button inside the scroll. "নতুন শিক্ষার্থী" from Students has it sticky. | Every form sheet uses the shared sticky footer slot. | m | lib/app/ds + lib/features/students |
| C7 | Sheet / panel horizontal padding | P/D | both | The title sits at x=20 while fields sit at x=36 (new batch sheet, edit panels at 525 vs 535). Edges are misaligned. | One 20 px inset for header, body and footer. Remove the extra inner card padding around form sections. | m | lib/app/ds |
| C8 | Select (phone) list | P | both | The selected item is an accent **outlined** box. The list doesn't scroll to the selected month (fee-start list opens at Nov 2025; the selection, Dec 2026, is off-screen). | Selected = accentTint fill + ✓. `initialScrollOffset` centres the selected item. | m | lib/app/ds (`bhor_select.dart`) |
| C9 | Chip ✓ insert reflows rows | P | both | Selecting a day chip grows it by about 20 px and re-wraps the row (মঙ্গল jumps to the next line). | §4.6: reserve the ✓ slot (fixed width), or animate the wrap with `AnimatedSize` plus positional spring. | m | lib/app/ds (`bhor_choice.dart`) |
| C10 | Field error placement | P | L | Onboarding phone validation shows a separate red banner under the card, with no error ring on the field. | Error ring on the field + message slide-down under the field (spec TextField error). Drop the banner. | m | lib/app/ds + lib/features/onboarding |
| C11 | Escalation bar | P/D | both | On Today it renders as 10 empty grey segments (dark: nearly invisible) for the same data that is all-red on Fees. It reads as a loading skeleton. | Feed the same severity data, or hide the bar when it has no fill. Fill segments left→right with the 18 ms stagger. | m | lib/app/ds (`BhorEscalationBar`) + lib/features/home |
| C12 | Coach mark pointer | P | L | The "আজকের ক্লাসে চাপ দিলেই…" coach mark uses a ⌄ chevron icon pointing **down** while its target is **above**. It looks like an accordion. | Replace it with a tail/notch on the card edge facing the target. No chevron. | m | lib/app/ds / lib/features/home |
| C13 | Toast and coach mark have outlined accent edges | P | L | The coach mark has a 1.5 px accent border plus shadow. | Surface + line edge + neutral shadow, per toast spec. | m | lib/app/ds |

### 2.3 Feature screens

| # | Screen | Plat | Theme | What's wrong | Exact fix | Sev | Owner |
|---|---|---|---|---|---|---|---|
| F1 | Date picker from payment panel | D | both | It opens as a **phone bottom sheet** centred at the bottom of the window, with a drag handle. The last week row and the sheet bottom are **clipped off-screen**. 60 px stretched cells. | Desktop → anchored popover calendar (40 px cells) under the date field (§3). Never use a bottom sheet at ≥ 840. | **B** | lib/app/ds (`bhor_pickers.dart`) |
| F2 | Onboarding step change | P | both | The outgoing step (student form) and incoming step (reminder priming) are both fully visible on top of each other. Text overlaps text. | Shared-axis X: out −24 px with opacity to 0 over 90 ms, **then** in +24 px over 210 ms. Wrap each step in an opaque bg. | **M** | lib/features/onboarding |
| F3 | Onboarding footer jumps ahead of content | P | both | On "ব্যাচ তৈরি করুন" the footer swaps to "পরবর্তী / পরে যোগ করব" while the old batch form is still on screen. | Drive footer and body from the same step-transition animation. | m | lib/features/onboarding |
| F4 | Onboarding / batch form | P/D | both | Card → outlined card → outlined card → outlined time boxes → outlined routine card: 4 levels of outlines. The time fields `শুরু/শেষ` are outlined, not soft. | Flatten: one surface card per section. Sub-groups use soft fill without a border. Time fields = soft filled field style with a clock suffix. | **M** | lib/features/batches (shared form widget) |
| F5 | Onboarding / batch form suggestion chips | P | L | The horizontal chip rows run past the card's right edge (জীব…, নবম শ্রেণি clipped at the screen edge, not at the card). | Clip the scroll view to the card's inner padding and add a 16 px fade mask at the trailing edge. | m | lib/features/batches |
| F6 | Onboarding copy | P | both | "বিকাল ৪টার ব্যাচ **ব্যাচে** যোগ হচ্ছে" (doubled word). The meta icon is not aligned to the first text line. | Template "{batch}-এ যোগ হচ্ছে". Align the icon to the first baseline. | m | lib/features/onboarding |
| F7 | Onboarding light progress | P | L | The inactive step segments are almost invisible on `#F6F5F1`. | Inactive = `soft2 #E3E0D8`. | m | lib/features/onboarding |
| F8 | Today dues card (desktop bento) | D | both | The "বেতন বকেয়া" card clips its second row (নুসরাত জাহান cut at the card bottom). No "সব দেখুন". | Let the card size to 3 rows, or show 2 rows + a "আরও ২ জন →" row. Never clip mid-row. | **M** | lib/features/home |
| F9 | Today header (phone) | P | both | The বাং/EN language toggle sits in the Today header next to search. The spec header is greeting + round search only. | Remove the toggle from Today. It lives in More → চেহারা. | m | lib/features/home |
| F10 | Today quick actions | P | L | The 2×2 "দ্রুত কাজ" are white **outlined** boxes, leftover from the old style. | Soft filled tiles (soft bg, r14, no border), with soft2 on press. | m | lib/features/home |
| F11 | Today week strip selected day | P | both | The selected day is an accent-**outlined** pill. | accentTint fill, no border. Text accent. | m | lib/features/home |
| F12 | Today "আজকের হাজিরা" empty | P | L | A lone "—" glyph and an orphan grey dot before any roll call. | Use the shared empty state: one line + muted icon. Hide the dot row until there is data. | m | lib/features/home |
| F13 | Desktop Today header actions | D | both | 4 unlabeled icon buttons (pay, student, +, search) + segmented + language toggle. The meaning is unclear and there are no tooltips. | Keep search + one "নতুন…" menu button with labels. Show tooltips on all icon buttons. Drop the language toggle. | m | lib/features/home |
| F14 | Desktop week view | D | L | Event blocks are accent-outlined, their text wraps mid-name ("…৪টার / ব্যাচ"), and the half-hour gridlines are as heavy as the hour lines. | Events = accentTint fill + 3 px accent leading bar, single-line ellipsis + time. Half-hour lines at line@50%. | m | lib/features/schedule |
| F15 | Roll call rows | P/D | both | The status uses a 3 px left stripe drawn **outside** the rounded card (it misses the corner radius). Each row is a separate card rather than one list with hairlines. | Remove the stripe. The row tint (already applied) is the signal. Rows go inside one `BhorList` with inset hairlines (spec Phone roll call). | **M** | lib/features/attendance |
| F16 | Roll call header | P | both | Close is a bare ✕. The spec says a soft r13 back button. The header ⋮ opens a 1-item sheet ("ক্লাসের নোট"). | Soft 40×40 r13 back button. Replace ⋮ with a direct "নোট" icon button. | m | lib/features/attendance |
| F17 | Roll call counts | P | both | Counts appear twice (chips under the info banner **and** the line above save). | Keep the live count chips. Drop the footer line, or keep the footer and drop the chips. | m | lib/features/attendance |
| F18 | Roll call info banner | P | both | An accent-outlined banner. | Soft accentTint fill, no border. | m | lib/features/attendance |
| F19 | Desktop roll call | D | both | The sidebar is hidden entirely and there is no "← আজ" crumb (§3 says the sidebar is collapsed, not hidden). | Render inside the shell with the sidebar collapsed to its rail. Add a "← আজ" crumb before the title. | m | lib/features/attendance + lib/app/shell |
| F20 | Students table (desktop) | D | both | The "হাজিরা %/বকেয়া" column collides: "১০০%●মেয়াদোত্তীর্ণ", "০%—", "——". Headers truncate ("অভিভাবকের …"). The phone number truncates. | Split into two columns (হাজিরা right-aligned tabular, বকেয়া tag). Min widths: phone 128, roll 48. 12 px gap between value and tag. Ellipsis only on name. | **M** | lib/features/students |
| F21 | Students list (phone) | P | both | The list card stretches to the bottom with empty white space. The FAB overlaps the list card. The header search icon duplicates the search field. | The card hugs its rows. Add 88 px bottom padding for the FAB. Remove the header search icon on this screen. | m | lib/features/students |
| F22 | Student profile | P/D | both | Phone: the action buttons stack vertically with ragged widths. The month strip labels truncate ("আগ", "সেপ্টে", "অক্টো") and the strip clips at the card edge ("নভে"). | Actions in one row of equal soft buttons. Month cells min 64 px with full short names (আগস্ট), horizontal scroll with an edge fade. | **M** | lib/features/students |
| F23 | Batch list (desktop) | D | both | A **← back arrow** appears beside the root "ব্যাচ" title. The selected card is accent-**outlined**. Two FABs on desktop (list + detail). | Remove the back arrow on root tabs. Selected = soft2 fill + 3 px accent bar or accentTint, no outline. On desktop use header buttons, not FABs. | **M** | lib/features/batches |
| F24 | Batch detail (phone) | P | both | Three "add student" CTAs at once (header +, empty-state button, FAB). The amount column shows "—" while the tag says "৩ মাস বাকি". The long name truncates because of the long tag. | One CTA (FAB); the empty state just explains. Show the due amount (৳৩,০০০). Put the tag on the second line under the name on phone. | m | lib/features/batches |
| F25 | Batch avatars | P/D | both | সকালের ব্যাচ and সন্ধ্যা ব্যাচ both get the initials "সব্যা". | Initials from the distinguishing word (first word only: "সকা", "সন্ধ্যা"→"সন্"), or show the time (৪টা) as the avatar. | m | lib/features/batches |
| F26 | Batch overflow ⋮ (desktop) | D | both | It opens a centred dialog with plain rows. "ব্যাচ মুছুন" is not marked destructive. | Anchored popover from ⋮ (§3), with icons. The destructive item uses error colour, then a confirm DLG. | **M** | lib/features/batches |
| F27 | Slot editor (desktop SP) | D | both | Day chips wrap with a single orphan "শুক্র" on line 2 in a 560 px panel. | Use a 7-column equal grid. | m | lib/features/batches |
| F28 | Bulk add (desktop) | D | L | Full route, **sidebar gone**. The form card sits left-of-centre with the right half empty. The CTA bar spans 780 px. | DLG 720, 2-col (form left, added list right), footer inside the dialog (§3). | **M** | lib/features/batches |
| F29 | Fees dues rows (phone) | P | both | Each row is about 185 px tall (name, tag, meta, 2 text links, a separate button). The FAB covers the amount of the 2nd row. | Compact row: avatar · name/tag/meta · amount + "টাকা নিন" (sm). Move copy/remind into a swipe or long-press menu. Add FAB clearance padding. | **M** | lib/features/dues |
| F30 | Fees filter row (phone) | P | both | The "ব্যাচ: সব" select is cut off at the screen edge. | Put the select on its own row, or make it a chip that opens a sheet. Add an edge fade on the scroll row. | m | lib/features/dues |
| F31 | Fees ↔ Collection | P/D | both | "আদায়" pushes `/fees/collection` as a separate page with a ← back arrow, a different title ("মাসিক আদায়"), a different header and a differently sized segmented control. The segment swap is a page swap. | §3: one page and one header. The segmented control swaps the body in place (fade-through 90/210 ms). No back arrow. The URL can still change. | **M** | lib/features/dues + lib/features/payments |
| F32 | Collection header | P/D | both | ⋮ opens a sheet/dialog with one item (অন্যান্য আয়). The pencil icon opens **CSV export** (wrong glyph). | "+ অন্য আয়" header button. CSV export uses `FileCsv`/`DownloadSimple`. | m | lib/features/payments |
| F33 | Collect payment sheet (phone) | P | both | On open, the amount field is under the sticky footer. You see only month chips. After saving, the sheet briefly re-renders with the **next** month (সেপ্টেম্বর) selected under the success overlay. | XS at 100% (C5). Freeze the sheet content once submit starts. | **M** | lib/features/payments |
| F34 | Collect payment ⋮ | P/D | both | A one-item menu (এই মাস মাফ করুন): bottom sheet on phone, an untitled empty-header dialog on desktop. | Inline ghost button "মাফ করুন" in the sheet, or POP on desktop. | m | lib/features/payments |
| F35 | Payment panel (desktop) | D | both | The amount echo "৳১,০০০" is repeated in tiny text under the field. The "মাস ভাগ" accordion and the date row have no container. The date opens via a bare icon. | Drop the echo, or put it in the field suffix. Use a field-styled date (tap anywhere) that opens POP. | m | lib/features/payments |
| F36 | Time picker | P/D | both | Phone: the title sits on its own row below ✕, wasting about 40 px. Desktop: a centred dialog (should be POP), with no close. | Phone: title + ✕ on one row. Desktop: 3-column popover anchored to the field. | m | lib/app/ds (`bhor_pickers.dart`) |
| F37 | Class actions ⋮ (Today) | D | both | Centred dialog with a large empty band above the title. | POP anchored to ⋮; reschedule/extra → DLG (§3). | m | lib/features/classes |
| F38 | Roll-call row menu (desktop) | D | both | Centred dialog. | POP anchored to the row "…" (§3). | m | lib/features/attendance |
| F39 | Search palette (desktop) | D | both | About 95% of the window height. With no query, it shows two empty states side by side. Esc clears instead of closing when the query is empty. The avatar initials overflow the 28 px circle ("তাহো"). | 640×520 palette at 15% from the top. One empty state. Esc closes when the query is empty. 2-letter initials. | m | lib/features/search |
| F40 | More (phone) | P | both | The subtitle shows today's date (irrelevant). The coaching-centre info is split across two cards. Theme picker style ≠ onboarding segmented. | Drop the date. One card for centre info. Same theme control in both places. | m | lib/features/settings |
| F41 | More (desktop) theme cards | D | both | The preview cards are about 140×80, oversized for a settings row. | Max 120×72 and a 3-up grid at 12 px gap. | m | lib/features/settings |
| F42 | Holidays (desktop) | D | both | Leaves the settings layout as a full route. The form floats mid-screen with a 636 px wide bottom CTA bar. | DLG 560 (§3), CTA inside. | **M** | lib/features/settings |
| F43 | Archived / Left students (desktop) | D | both | Full route, with the empty-state card floating top-centre in a black void. | INL in the More right pane (§3). | m | lib/features/settings |
| F44 | Payment methods panel | D | both | The "নতুন মাধ্যমের নাম" field (56 px) and the "যোগ করুন" button (36 px) are mismatched heights side by side. | Use a 46 px button, or a suffix button inside the field. | m | lib/features/settings |
| F45 | CSV export sheet | P | D | Outlined inner cards with 2 buttons each. Heavy. | List rows (icon · title/sub · "সেভ" ghost + share icon). | m | lib/features/extras |
| F46 | Add-student 2-step (phone) | P | both | The "← back" chevron sits at the **right** end of the "নতুন শিক্ষার্থী" row. The fee-start info is shown three times (heading, segmented, select). | Back chevron on the left of the step title. Keep segmented + one helper line. Hide the select behind "অন্য মাস". | m | lib/features/students |
| F47 | Success state over forms | P | both | The ✓ pops over a 50%-faded form whose fields are still legible. | Fade the form to 0 (or blur), then pop the ✓ on a clean sheet, per spec. | m | lib/app/ds |
| F48 | Students "বকেয়া নেই" tag | P/D | both | An outline check + text with no pill, unlike the other tags. | `BhorTag(tone: ok)` pill. | m | lib/features/students + lib/features/batches |

**Counts:** Blocker 1 · Major 21 · Minor 49 (71 total).

---

## 3. Flows still not matching the §3 navigation table

| Flow | §3 target | Observed | Platform |
|---|---|---|---|
| Fees ↔ Collection | in-page segmented, no back arrow | separate route `/fees/collection` with ← and a different header | P + D |
| Collection ⋮ (single item) | header button | ⋮ → sheet (P) / dialog (D) with one item | P + D |
| Date picker | POP anchored calendar | bottom sheet, clipped | D |
| Time picker | POP 3-column | centred dialog | D |
| Batch overflow ⋮ | POP → confirm DLG | centred dialog | D |
| Roll-call row ⋮ | POP | centred dialog | D |
| Class actions ⋮ (Today) | POP → DLG for forms | centred dialog | D |
| Collect-payment ⋮ (waive) | inline/POP | sheet (P) / untitled dialog (D) | P + D |
| Bulk add | DLG 720 2-col | full route, sidebar hidden | D |
| Holidays | DLG | full route | D |
| Archived batches / Left students | INL in More pane | full route | D |
| Roll call | FR with sidebar collapsed + "← আজ" crumb | FR with the sidebar hidden, no crumb | D |
| New batch (phone) | FS or XS | 55% fixed bottom sheet (not expandable) | P |
| Collect payment (phone) | XS | 55% fixed bottom sheet; amount below the fold | P |

Already correct (keep): edit student SP (D) / sheet (P), new/edit batch SP, slot editor wide SP, add-to-batch DLG, collect payment SP, payment methods SP, templates SP, backup INL + backup DLG, search as a desktop overlay, batch and student detail INL.

Not exercised: backup review, reminder priming as a standalone route, diagnostics/help, desktop onboarding, waive/fee-change dialogs.
