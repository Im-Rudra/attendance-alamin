# 12 — UX / visual / motion review of the Bhor build

Reviewer stance: product + motion designer, bar = Linear / Things 3 / Arc / Revolut. No code changed.

**How this was reviewed.** Live web build (`?r=ux7`), data wiped (IndexedDB + localStorage), then built up through the real UI: onboarding (coaching name, batch "সন্ধ্যা ৭টার ব্যাচ" with Math, 4 students); new batches "ব্যাচ ২" (Physics, **postpaid**) and "ব্যাচ ৩" (Math, per-day slots, accepted a clash suggestion); Sadia added through the add-student sheet with fee start **May 2026**, which gave 7 overdue months; 3 students bulk-added. That makes 2 subjects, 3 batches and 8 students. Then 2 roll calls (one on desktop, one on phone, with absent and late), 3 payments (sheet, profile sheet, inline pane) and 1 other income. Every route in `routes.dart` was then visited at **phone 375×812** and **desktop 800×486 (pane width) and 1440×900**, in **light and dark**. The browser pane was reset to desktop at the end.
Not seen live: the DS gallery (`/more/design-system`, which needs a long-press), the reminder lead / effective-from / fee-change / waive / CSV-export sheets (reviewed from code; they share `sheet_frame` and `BhorSheet`), and real CSV/backup file picking.
Code evidence: features use `BhorSkeleton` **0** times. There are **6** implicit animations in all of `lib/features`. Every icon is Material `Icons.*`, about 70 distinct glyphs. Shell tab switches have no transition (indexed stack). `_detailPage` is instant on wide screens.

---

## 1. Global problems

### 1.1 Type scale and hierarchy — **Major**
- The scale is too flat. display 24 / title 18 / heading 15 / body 14 / label 12.5 / meta 12 / caption 11 puts five steps inside 3 px, and Hind Siliguri at 11–12 px is close to illegible: conjuncts like "ক্ষ", "ন্ত" and "ত্র" collapse. Meta lines ("শনিবার, ২১ নভেম্বর", "প্রাপ্য ৳…", "রোল ০৫") read as grey noise everywhere.
- Weight does all the hierarchy work, so every card title, row name and section header is 600–700 and nothing recedes. On Today (phone) the hero title, card titles, "৳ ১০,৫০০" and "৪ জন বাকি · ৪ জন মেয়াদোত্তীর্ণ" are all bold. That last line is a **bold sentence**, not meta.
- **Fix — new scale.** Bangla needs bigger minimums and more contrast between steps:
  - display 28/700 (-0.4)
  - title 20/700
  - heading 16/600
  - body 15/400
  - bodyStrong 15/600
  - label 13/600
  - meta 13/400 in text2
  - caption 12/500 in text3, used only for timestamps and units
  - stat 26/700 tabular
  - moneyHero 34/700
  - Keep line height 1.45 for body. Use 1.25 for display and title: Bangla headings at 1.45 look double-spaced. Cap screen titles at 1 line on phone and ellipsize with a full-title tooltip.
- **Rule:** at most two weights per card (a 600 title, plus 400 for everything else). Numbers get weight; sentences never do.

### 1.2 Spacing rhythm, alignment, density — **Major**
- There is no consistent page gutter.
  - Slot editor (phone): the batch subtitle sits flush at x=0 with no padding.
  - Holiday / bulk-add / backup-review (desktop): content floats 60–90 px below the header in a void.
  - Archived (desktop): the empty-state card hugs the top.
  - Left-students (desktop): the same kind of empty state sits in a full-height card.
- Bottom action bars ignore the content width. On desktop the save button is **780 px wide under a 450 px form** (batch form, student edit, holiday, bulk add, slot editor), and the bar spans under the right column it doesn't belong to.
- Dense screens are not dense where they should be, and the reverse.
  - Fees list (phone): about 450 px of controls (segmented, total, escalation bar, 3 chips, batch select, "remind all") before the first student row.
  - Each dues row has 3 buttons stacked in 2 rows.
  - Today at 1440 has huge empty interiors because grid rows are equal height: the dues card shows its number at the top and its bar at the bottom with 80 px of nothing between.
- **Layout shift is everywhere** and caused real misclicks during this review:
  - day chips widen when the ✓ appears
  - the "সাপ্তাহিক রুটিন" summary card pops in and pushes the fee field down
  - the disabled-reason line under the save button appears and disappears, changing the bar height
  - the "this month / next month" segmented control vanishes after a past fee month is picked
  - bulk add jumps from 1 to 2 columns after the first student
- **Fixes:**
  - Page gutter 16 (phone), 24 (tablet), 32 (desktop). Max reading width 720 for forms and 1200 for dashboards.
  - Bottom bars take the form's width, or go into the panel or dialog footer (see §3).
  - Reserve space for selection checkmarks (fixed chip width, or a leading slot that cross-fades).
  - Animate any inserted block with `AnimatedSize` + fade (see §4).
  - Use an 8-pt vertical rhythm between sections (24), cards (12) and rows (0, hairline).

### 1.3 Colour use — **Major**
- **Red overload.** Overdue is a solid #B4194A tag with white text, repeated per row, per month and in summaries. The student profile month strip is a wall of 6 identical red "মেয়াদোত্তীর্ণ" pills. The fees escalation bar is 10 identical red segments, so it says nothing. Red should mean "act now", once per item.
- **The absent state reads as "disabled/selected", not "absent".** The slate #3F4660 full-row fill plus a white "দেরি" box sticking out of the dark row is the ugliest moment in the app, and it sits in the most-used flow.
- **Segmented control selected state is ambiguous in light mode.** The thumb is white on #F1EFEA. In "দিন | সপ্তাহ" on Today at 1440 it is unclear which one is selected.
- In dark mode, primary buttons are lavender #8B83FF with **dark** text and danger buttons are pink with dark text. Both look washed out and "disabled". The disabled primary is the same hue at lower opacity, so enabled and disabled look alike at a glance (the onboarding "ব্যাচ তৈরি করুন").
- The Today hero "হাজিরা নিন" button flips between grey (hover) and white. On indigo, a grey pill looks disabled.
- The switch "off" state in dark mode is a grey knob on a near-black track, which is invisible.
- **Fixes:**
  - Overdue = a 3 px rose left-edge stripe on the row, plus one compact tag with the count ("৫ মাস"). Paid months = a quiet ✓ in text3. The month strip becomes dots: ● paid (ok), ● due (honey), ● overdue (rose), ○ future. The escalation bar uses the honey→rose ramp, with a ring on today.
  - Absent row: surface stays; a 3 px slate left stripe, a slate-tinted bg (absent @10%), and a struck-through "উপস্থিত"/"অনুপস্থিত" label in absent colour. The late button inside the row becomes a ghost icon button that inherits the row's tint.
  - Segmented: in light, thumb = surface + 1 px line + shadow-sm (y1 b3 @8%), label = text, unselected label = text3. In dark, thumb = #2A2E3A.
  - Dark primary: keep the indigo #6E63EE→#5B4FE0 gradient with **white** text (tested AA ≥ 4.5). Use lavender only for text-on-dark links. Danger in dark = #E5566F fill with white text.
  - Disabled = surface2 fill + text3 label, not a faded primary.
  - Switch-off track = line colour plus a 1 px text3 border.

### 1.4 Iconography — **Major** (the user's "not premium" verdict is mostly this)
- The icons are Material Icons, mixed `_outlined`, `_rounded` and filled (`check_circle` next to `check_circle_outline`, `warning_amber_rounded` next to `error_outline`). They are optically heavy at 20–24 px next to a 400-weight Bangla body. Several are wrong metaphors:
  - hamburger ≡ for "আরও"
  - a beach-umbrella-ish glyph for holidays
  - "touch_app" in onboarding and empty states
  - a wallet-in-box for "বেতন"
  - a filter-list glyph for search on Fees and Students
- **Pick: Phosphor Icons (`phosphor_flutter`), weight "Regular" (1.5 px stroke at 24) for UI, "Fill" for the active nav item and status glyphs, "Bold" never.** Phosphor has the widest set with consistent weights; its six weights give a clean active/inactive pair, and its rounded geometry suits Bangla letterforms. Lucide is the runner-up, but it has no fill weight for active states.
- **Sizes:** 20 in rows and buttons, 18 in chips and tags, 16 inline with meta, 24 in nav. Icons in text2 by default. Use the accent only for the active nav item or when the icon *is* the action.
- **Mapping (replace all `Icons.*`):**

  | Use | Phosphor |
  |---|---|
  | Today | `CalendarCheck` |
  | Batches | `UsersThree` |
  | Students | `Student` |
  | Fees | `Wallet` / `CurrencyCircleDollar`, or a custom ৳ glyph |
  | More | `DotsThreeCircle` (not ≡) |
  | Search | `MagnifyingGlass` |
  | Roll call | `ListChecks` |
  | Take money | `HandCoins` |
  | Remind | `BellRinging` |
  | Copy number | `Copy` |
  | Share receipt | `ShareNetwork` |
  | Holiday | `CalendarX` |
  | Archive | `Archive` |
  | Left students | `UserMinus` |
  | Backup | `CloudArrowUp` / `CloudArrowDown` |
  | Clock / time | `Clock` |
  | Late | `ClockCountdown` |
  | Absent | `X` |
  | Present | `Check` |
  | Leave | `AirplaneTilt` / `CalendarBlank` |
  | Notes | `NotePencil` |
  | Overflow | `DotsThree` (horizontal on desktop), `DotsThreeVertical` (phone) |
  | Edit | `PencilSimple` |
  | Delete | `Trash` |
  | Warning | `WarningCircle` |
  | Info | `Info` |
  | Close | `X` |
  | Back | `CaretLeft` (iOS-like) / `ArrowLeft` (desktop) |

- **The brand mark is a letter "হা" in a purple square.** Commission a simple monogram (a sunrise arc over a ledger line, matching "ভোর"), and use it in the sidebar, onboarding and favicon.

### 1.5 Buttons — **Major**
- Too many primaries per screen. Batch detail has 3 ways to add a student (header icon, empty-state button, FAB). Fees has 3 kinds of "টাকা নিন" (header button, row button, FAB on phone), and **the FAB overlaps the row button** on phone.
- Every button is 44 px with a large radius. Row actions should be 32–36 px ghost or icon buttons, not full secondary pills.
- Icon-only header actions with no labels or tooltips (Today at 1440: wallet, person+, ⊕) are "mystery meat" buttons.
- The phone FAB floats about 100 px above the nav bar (batches, students, batch detail), which looks like a layout bug.
- Copy is inconsistent: "সংরক্ষণ" (batch form) vs "সেভ করুন" (student form) vs "সেভ করুন" (onboarding). Use one word app-wide: **"সেভ করুন"**.
- **System:**
  - primary (filled, max 1 per view)
  - secondary (surface + hairline)
  - tonal (accentTint bg, accent text; for row-level "টাকা নিন")
  - ghost (text only)
  - danger
  - Sizes: lg 48 (phone sticky CTA), md 40, sm 32 (rows, toolbars), icon 36/32.
  - Radius 10 for md/sm and 12 for lg.
  - States: hover = +4% overlay with the cursor changed; pressed = scale 0.97 + 6% overlay; focus = 2 px accent ring with a 2 px offset (not a 4 px blur halo); loading = label cross-fades to a spinner, keeping the width; disabled = surface2 / text3 with a reason tooltip on hover.
  - Phone FAB: 56 px, 16 px above the nav, hidden on scroll-down and shown on scroll-up (§4).

### 1.6 Focus and hover — **Minor**
- The focus ring is a soft 4 px halo that looks like a glow, not a ring, and it is used on auto-focused fields. The roll-call search and the student list search auto-focus on open, which pops the phone keyboard over the roster.
- Hover states exist on some rows only (the date picker cell, sidebar), not on list rows and cards.
- **Fix:**
  - 2 px accent ring with a 2 px gap on `:focus-visible` only (keyboard), never on pointer focus.
  - Every clickable row/card gets a hover bg = surface2 at 60% plus cursor:pointer, and a 1 px accentLine border on cards.
  - Don't auto-focus search on phone. On desktop do auto-focus, with a "/" shortcut hint chip.

### 1.7 Empty states — **Minor**
- These are inconsistent: a small card at the top (archived), a full-height card (left students), two side-by-side empty states (search desktop), and a "—" plus text (attendance card).
- The empty icons are Material glyphs in a tinted square: generic.
- **Fix:** one `BhorEmptyState`: a 64 px duotone Phosphor icon in a 96 px soft circle (accentTint), a title (heading), one meta line, and at most one action. Vertically placed at 30% from the top of its container, no card around it. For search, show recent students plus shortcuts instead of an empty state.

### 1.8 Bangla typography — **Major**
- Inputs keep Latin digits while the display uses Bangla. You type "1500" and see "৳ 1500"; the roll edit field shows "05" while the list says "০৫". Either convert on blur to Bangla digits, or show Bangla digits live (accept both).
- The "৪" (4) vs "8" ambiguity at small sizes: Hind Siliguri's ৪ reads as 8 at 12 px ("৪ জন শিক্ষার্থী"). That is another reason for the 13 px minimum and tabular figures in stats.
- Truncation inside Bangla words: "জুলা", "সেপ্টে", "অক্টো", "আগ" in the month strip; "Sadi a Is…" (a per-character wrap in the batch student grid at 1440); the roll-call title "গণিত — দশম শ্রেণি — সন্ধ্যা ৭…". Use standard short forms ("জুলা." is wrong; use "জুল", "সেপ্ট", "অক্টো") from a lookup table, never character clipping.
- Mixed scripts: student names are Latin while all chrome is Bangla. Set Latin fallback to Inter at a 0.95 size factor so names don't look smaller or lighter than Bangla.
- "৳" sizing is fine in stats but inconsistent in rows ("৳৫,০০০" collides with the tag in the wide fees table).

---

## 2. Per-screen findings

Severity: **M** = Major, **m** = Minor, **P** = Polish.

### Onboarding (`/onboarding`)
- **M** Progress is shown twice on desktop: the left purple stepper and the top dots. Drop the dots on desktop. On phone, replace the dots with a thin 4-segment progress bar under the header.
- **M** The desktop left panel is a full-height saturated purple slab with a tiny tip card at the bottom. It feels heavy and template-like. Make it the hero gradient at 50% height with the brand mark plus a larger, 2-line illustration of the current step, or make it light (surface) with the accent only on the active step.
- **m** The "বিষয়/শ্রেণি" suggestions are two chip walls (subjects + classes, 15 chips). Collapse to one row each with horizontal scroll, or a combobox.
- **m** The primary button is 470 px wide on desktop. Cap it at 320 and right-align it with "পরে যোগ করব" as a ghost button to its left.
- **m** The time picker dialog's title touches the top edge (no top padding).
- **P** The reminder step uses a Material bell; swap to Phosphor `BellRinging` duotone in a 72 px circle, with a gentle ring wiggle on enter.
- **P** Step changes cut instantly; use a shared-axis horizontal transition (§4).

### Today (`/today`) — day view
- **M** **Phone order is wrong.** The order is hero → dues → week strip + routine → collection → attendance → quick actions. A teacher opens this to run today's classes, so it should be hero → routine → attendance → money cards. Quick actions belong at the top as a horizontal pill row, or in a FAB; currently they are the last thing on the page.
- **M** The hero CTA "হাজিরা নিন" is a white or grey pill sitting at mid-right; on phone it sits below the title in a separate row. Make it full-width white on phone (48 px, accent text, a `ListChecks` icon) and right-aligned on desktop. The grey hover state reads as disabled; use white with a 6% indigo overlay.
- **M** The "all done" hero (`আজকের সব ক্লাস শেষ`) is a big empty purple block at 1440. Shrink it to a compact success banner (ok tint, `CheckCircle` fill, "২/২ হাজিরা নেওয়া হয়েছে · কাল ৩টি ক্লাস"), or show tomorrow's first class.
- **M** At 1440 the grid rows are equal height, so cards have dead interiors. Use a masonry or content-height grid: 12 columns, hero 8 + attendance 4, routine 8 + money stack 4.
- **m** The dues card's 10-segment bar is all grey when nothing is "today"; hide it unless it carries information.
- **m** The language switch "বাং/EN" is in the Today header; it belongs in More → চেহারা only (it was already chosen in onboarding).
- **m** The coach mark "আজকের ক্লাসে চাপ দিলেই…" points down with a ↓ but sits *below* the button. Flip the arrow, anchor with a caret, and add a scrim cut-out around the target.
- **m** The routine row's ⋮ opens a bottom sheet even on desktop (see §3); the sheet's X is on its own row above the title.
- **P** Header icon actions at 1440 (wallet, person+, ⊕) have no labels. Use labelled `sm` buttons, or a single "+ নতুন" split button with a menu.

### Today — week view
- **m** All events are the same lavender; colour-code by batch (6 hue tokens) with a 3 px left stripe.
- **m** Event text wraps onto 3 lines and ellipsizes the time. Show the batch name only (the subject is in the tooltip), with the time on line 2.
- **m** Blocks don't fill the column (right gap); make them inset 2 px on both sides.
- **P** The now-line only spans today's column; extend it faintly across all columns, with a dot at today.

### Roll call (`/rollcall/:occ`, `/batches/:id/rollcall/:date`)
- **M** The absent row styling (slate fill + a white "দেরি" box) — see §1.3. This is the #1 visual fix.
- **M** The "দেরি" toggle is a box glued to the row's right edge, so it looks like a separate card. Make it a 32 px ghost icon button (`ClockCountdown`) inside the row padding, with a tooltip "দেরি".
- **M** The row ⋮ opens a full bottom sheet on desktop; use an anchored popover menu (§3).
- **m** The info banner "সবাই উপস্থিত ধরা হয়েছে…" is permanent. Show it once, then collapse it to a meta line under the date.
- **m** The search field auto-focuses on phone (keyboard covers the roster). Don't auto-focus.
- **m** The phone title is truncated. Use 2 lines: batch name (title) and subject · time (meta).
- **m** The desktop roster is 2 columns with empty space; at ≥1200 px use 3 columns. The right column's 4 stat tiles are huge for single digits; use one compact stacked bar (present/absent/late/leave) plus counts.
- **m** "হাজিরা সেভ করুন (৪ জন)": the count is ambiguous. Use "সেভ করুন · ৩ উপস্থিত, ১ অনুপস্থিত".
- **P** No feedback on toggle and none on save; see the motion spec §4.7 and §4.10.

### Batches list (`/batches`)
- **M** The desktop list pane shows a **back arrow** next to "ব্যাচ" whenever a detail is open. Top-level destinations never get a back arrow; the detail pane is a sibling, not a child.
- **M** The phone FAB floats about 100 px above the nav.
- **m** Subject group headers ("⌄ গণিত — দশম শ্রেণি · ২টি ব্যাচ") are bold 15 with a chevron; make them label-caps style (13/600 text2) with the count in text3.
- **m** Batch cards repeat the "অগ্রিম/মাস শেষে" tag on every card. Show only the exception (postpaid) as a tag.
- **P** The selected card uses a 2 px accent border plus a glow. Use a 1 px accent border plus an accentTint bg; drop the glow.

### Batch detail (`/batches/:id`)
- **M** **At 1440, the "শিক্ষার্থী" tab renders a 4-column card grid that wraps names per character ("Sadi / a Is… / রোল ০৫")**, which is broken. Use the phone-style list rows at every width, or a real table with min column widths.
- **M** There are 3 entry points to add a student (header icon, empty-state button, FAB). Keep one: the FAB on phone, a header "+ শিক্ষার্থী" sm button on desktop.
- **M** The overflow ⋮ (archive/delete) opens a centered bottom sheet far from the trigger on desktop; it should be an anchored menu.
- **m** The summary card shows "— আজকের হাজিরা" and "৳ ০ বকেয়া" as stats. A dash and a zero are not stats; hide them or show "আজ ক্লাস নেই".
- **m** Tabs are underline tabs with 4 short labels; on desktop at 1440 the right rail (সপ্তাহের ক্লাস / বকেয়া / হাজিরা) duplicates the tabs. Pick one.
- **m** The "রোল ০১ —" trailing em-dash in phone rows is an orphan separator with nothing after it.
- **P** The "হাজিরা নিন" button in the summary card is the only primary-coloured element; on a postpaid batch the tag should sit beside the fee, not the subject.

### Batch form (`/batches/new`, `/batches/:id/edit`)
- **M** It is a full route on desktop that hides the sidebar. It should be a right-hand panel; see §3.
- **M** Layout shifts (chip ✓ width, the summary card insert, the disabled-reason line), §1.2.
- **m** "সব দিনে একই সময়" is a switch that changes the whole editor below; use a segmented control ("একই সময় | দিনভেদে আলাদা") so both modes are discoverable.
- **m** "আরেকটি দিন" opens a bottom sheet with a 7-row list; use an inline day-chip row (the same as same-time mode) or an anchored menu.
- **m** The conflict card is good, but its pink filled suggestion button is loud; use a tonal button.
- **m** The edit form has "আর্কাইভ করুন" as a full-width secondary button above Save. Move it to the overflow menu or a "বিপজ্জনক অঞ্চল" footer section.
- **m** The disabled subject field ("বিষয় বদলানো যায় না") looks like a broken input; render it as read-only text with a lock icon.
- **P** The disabled-reason text appears under the button as a tooltip-like chip that overlaps the window edge on desktop.

### Slot editor (`/batches/:id/slots`)
- **M** The phone subtitle has no left padding (flush to the screen edge).
- **m** "এই সময় সরান" is an accent text link with a trash icon; use a neutral ghost icon button, and turn it danger on hover.
- **m** The "সপ্তাহের চিত্র" on desktop is a list of 7 rows with "ক্লাস নেই". Make it a mini week grid (7 columns × time) like the Today week view.
- **P** The bottom bar spans only the left column at 1440 while the right column is empty; put save in the header ("সেভ করুন" sm primary) on desktop.

### Bulk add (`/batches/:id/bulk-add`)
- **m** The single column jumps to two columns after the first add; start in two columns, with an empty "যোগ হওয়া শিক্ষার্থী" placeholder.
- **m** The form card floats with about 60 px of dead space above it; align it to the header.
- **m** Full-width bottom button + "শেষ করুন" in the header = two finish actions. Keep the header "শেষ করুন" and turn the bottom button into an inline "যোগ করুন ↵" next to the phone field.
- **P** A newly added row should slide into the right list (§4.5).

### Add-student sheet (from batch detail)
- **M** It is a bottom sheet on desktop. It expands from a search step to a full form with a nested back arrow and two titles ("শিক্ষার্থী যোগ করুন" / "নতুন শিক্ষার্থী"). Use one title that updates, with the back arrow in the title row.
- **m** The fee-start dropdown lists oldest-first, with the selected month not scrolled into view. Use newest-first, and scroll the selected item into view.

### Students list (`/students`)
- **M** Filters wrap: the batch select takes half the width, "বকেয়া আছে" fits beside it, and "চলে গেছে" drops to a second line. Use one horizontally scrolling chip row: [ব্যাচ ▾] [বকেয়া আছে] [চলে গেছে].
- **m** The search auto-focuses (keyboard on phone); the list card stretches to the bottom with an empty interior.
- **m** The FAB overlaps the last row (Arif); add 88 px bottom padding to the list.
- **m** "০১ · Rahim Uddin": the roll number is fused into the name line. Put the roll number in the avatar corner, or as meta.
- **P** The desktop "সারসংক্ষেপ" pane (stats, top dues, by-batch bars, recent admissions) is nice, but cards have no affordance for whether they are clickable; add hover and a chevron.

### Student profile (`/students/:id`)
- **M** **The month strip** clips at the right edge mid-tag, truncates month names, and repeats red tags. Replace it with a 12-dot year strip plus a legend, with a tooltip or tap per dot (§1.3).
- **M** Phone action buttons wrap unevenly ("অভিভাবক · নম্বর কপি করুন" on one line and "মনে করান" below). Use a 3-icon action row (Copy / Remind / Call) with labels under the icons, like contact apps, and a sticky "টাকা নিন" primary.
- **m** "মোট বকেয়া ৳৬,০০০" in its own card duplicates the batch card's "বাকি ৳৬,০০০". Merge them.
- **m** The avatar is a 64 px rounded square with initials and no colour variety; give it a deterministic hue from the name (6-hue set, tint bg + strong text).
- **P** The payment history row chevron leads to …? Make the row open the receipt preview in a sheet or panel.

### Student form (`/students/new`, `/students/:id/edit`)
- **M** It is a full route on desktop (the sidebar disappears) with a 780 px save bar under a 450 px form. Use a side panel (§3).
- **m** The photo picker is at the bottom of "আরও তথ্য"; put the avatar + "ছবি দিন" at the top of the form.
- **m** The date field puts its label inside the field while all other fields put labels above; unify on labels above.
- **m** Phone: wrapped in a card, while the batch form is not; pick one (no card on phone, card on desktop panel).

### Date picker (BhorDatePicker)
- **M** It is a bottom sheet on desktop with 60 px day cells; it should be an anchored popover (320 px, 40 px cells).
- **m** No "আজ" shortcut and no year/month quick jump; add a "আজ" ghost button and a tap-on-month-title → month grid.
- **P** Today has no ring when it isn't selected.

### Time picker (BhorTimePicker)
- **m** Every selected chip carries a ✓ *and* an accent fill (double signal) and changes width; drop the ✓.
- **m** The period/hour/minute rows are separate chip rows; on desktop, an anchored popover with 3 columns (period | hour | minute) is faster.
- **P** The big preview "সন্ধ্যা ৭:০০" should tick (number roll) when values change.

### Fees (`/fees`)
- **M** **The phone FAB "টাকা নিন" overlaps the first row's "টাকা নিন".** Remove the FAB on this screen; the header button is enough. Or keep the FAB and turn the row action into a tonal sm button.
- **M** The dues row is 3 actions + 2 lines + a tag + a month list, about 190 px per student on phone. Target 72 px: name + tag on line 1, months as meta on line 2, amount on the right, swipe-right = take money, swipe-left = remind, tap = student fees pane.
- **M** At 1440 the right "সারসংক্ষেপ" pane **duplicates** the left list (the বকেয়া list appears twice), and the amount collides with the tag in the table. Put the summary on top and the table full-width. The right pane is for the *selected* student (as `/fees/s/:id` already does at 800).
- **m** The top "টাকা নিন" primary sits in the middle of the list header at 1440; right-align it to the content edge.
- **m** The segmented "বকেয়া | আদায়" is actually route navigation (`/fees` ↔ `/fees/collection`); the back arrow appears and the list/detail layout disappears. Make it a real in-page segmented control with a cross-fade.
- **m** The escalation bar is all red (§1.3).

### Fees student pane (`/fees/s/:id`)
- **M** The dues-row "টাকা নিন" opens a **bottom sheet** while the same action via a row tap opens this **inline pane**. Pick the pane on desktop and the sheet on phone (§3).
- **M** On phone this route renders the **student profile** page (title "শিক্ষার্থীর প্রোফাইল") inside the Fees tab. It should be a payment-focused sheet; or, if the profile is intended, the Fees tab highlight is confusing.
- **m** The selected month is echoed as a bold heading under the chips ("জুন"); redundant.
- **m** The amount is echoed under the field ("৳১,০০০"); redundant once Bangla digits show in the field.

### Collect payment sheet (CollectPaymentSheet / form)
- **M** **Two close (X) buttons** (sheet header + form header) on phone and desktop. Remove the form's X when hosted in a sheet.
- **M** Month selection is single-select chips in arbitrary visual order. Paying June before May is allowed silently. Use multi-select with "পুরো বকেয়া" (all due) as the default, oldest first, and show the total live.
- **m** The 6 payment-method chips wrap to 2 lines; use a single-row scroller or a select with icons (cash/bKash/Nagad/Rocket/bank).
- **m** The date row looks like static text with a stray icon at the far right; make it a field.
- **m** "মাস ভাগ" is a link-styled expander with a chevron; label it "আংশিক টাকা?" and use a disclosure row.
- **m** Student picker step → form step swaps content with no transition, and the sheet height jumps; use a shared-axis X transition plus `AnimatedSize` (§4).
- **P** The success state is only a toast (see §4.10).

### Collection (`/fees/collection`)
- **m** 4 stat tiles (প্রাপ্য, আদায়, মাফ, বাকি) are separate cards; use one card with 4 columns and dividers, plus the progress bar inside it (it currently floats under the tiles, unlabelled).
- **m** The overflow ⋮ opens a sheet with **one item** ("অন্যান্য আয়"). Make it a visible secondary button "+ অন্যান্য আয়" in the header.
- **m** The share icon on every payment row is the only action; make the row tappable → receipt preview.
- **P** The month switcher's "‹ নভেম্বর ২০২৬ ›" next arrow is disabled grey but still looks tappable.

### Other income sheet
- **M** Validation helper text inserts and pushes the Save button below the sheet's visible area (the sheet doesn't keep its footer sticky). All sheets need a sticky footer.
- **m** "তারিখ: ২১ নভেম্বর ২০২৬" is a full-width secondary button; make it a field like the others.

### More (`/more`)
- **M** On desktop there are **two sidebars**: the app rail plus the settings category list. That is acceptable only if the settings list looks like a sub-nav: lighter, no card, 13/600 labels, an active pill. At 800 px, collapse it into a top segmented scroller.
- **m** "সাহায্য" sits under "সংরক্ষণাগার" (archive); move it to "সম্পর্কে".
- **m** The settings content uses two independent columns of cards with mismatched heights (masonry by accident); use one column, max 720.
- **m** The theme picker shows 3 preview tiles **and** a segmented control below them; make the tiles themselves the selector (selected = 2 px accent ring + ✓ badge).
- **P** The "কোচিং সেন্টার" fields save silently on blur; add an inline "সেভ হয়েছে ✓" micro-toast at the field.

### Holidays (`/more/holidays`)
- **m** About 90 px dead space above the card on desktop; the bottom bar spans full width under the card. On phone the CTA bar stacks on the nav (two bottom bars).
- **m** It is a full route; it should be a dialog (desktop) or a sheet (phone), §3.

### Payment methods (`/more/payment-methods`)
- **m** 6 switches all on with "দেখানো হচ্ছে" under each; noise. Use a reorderable list with switches only, and no sublabel unless hidden ("লুকানো").
- **P** The "নিজের যোগ করা" card has the add field and button side by side; fine. Use an inline chip list for custom ones.

### Message templates (`/more/templates/:kind`)
- **m** Raw `{student}` / `{amount}` placeholders in the editor; render them as non-editable inline chips (token pills) and let the chip row insert them at the cursor.
- **P** The live preview is good; highlight the substituted values in accent.

### Backup (`/more/backup`, `/more/backup/review`)
- **m** 3 tall equal cards with content at different vertical positions (icons at y≈180, 175, 100); top-align them, equal heights by content.
- **m** The review route with no file is an empty card with "ফাইল বেছে নিন"; it should be a dialog or step inside Backup, not a route (§3).

### Archived / Left students (`/more/archived`, `/more/left`)
- **m** Inconsistent empty-state containers (§1.7).

### Diagnostics / Help
- **P** Diagnostics is fine for a dev screen; the warning card's danger tint is good.
- **P** Help is two columns of accordions at desktop; one column reads better. Animate expansion (§4).

### Search (`/search`)
- **M** It is a full-screen route with **two empty states side by side** on desktop. On desktop it should be a ⌘K / "/" command palette dialog (640 px, results + preview). On phone, a full-screen search with recents.
- **m** Typing lagged the first keystroke after the route opened (focus race); autofocus after the transition completes.
- **m** The preview pane at 1440 is sparse (name, batch, phone); add the dues summary, last attendance, and quick actions (টাকা নিন, কল, মনে করান).

### Reminder priming (`/reminders/priming`)
- **m** It is a full route with an X for a single yes/no; use a dialog (desktop) or a sheet (phone).

### Shell (sidebar / bottom nav / toasts)
- **M** **Tab switches have no transition at all** (§4.3).
- **M** **Toasts cover the primary CTA and the bottom nav on phone**, and they sit over open sheets on desktop. Toasts must stack above the bottom nav / sticky CTA (an offset computed from the bottom bar height) and above sheets.
- **m** The collapsed rail tooltip is a white chip with black text in dark mode (inverted); use the surface-inverse token pair consistently, with a 300 ms delay.
- **m** The rail shows a "হা" letter tile as the brand; see §1.4.
- **m** The bottom nav's active pill is fine, but icons are Material and the badge "৪" overlaps the icon's top-right; offset it to −4/−6.
- **P** The search lives at the bottom of the rail; put it at the top of the sidebar as a "খুঁজুন  /" field.

---

## 3. Navigation pattern table

Legend — Phone: **FS** full screen, **BS** bottom sheet (fits content), **XS** expanding sheet (opens at about 60%, drags to full). Desktop: **SP** side panel (right drawer, 440–520 px, scrim 20%, list stays visible), **DLG** centered dialog (480–640 px), **INL** inline pane (list–detail), **POP** anchored popover/menu, **FR** full route.

| Flow (current) | Now | Phone | Desktop | Reason |
|---|---|---|---|---|
| New batch `/batches/new` | FR (both) | **FS** | **SP** | Long multi-section form; keeping the batch list visible gives context, and on phone the keyboard needs the full height. |
| Edit batch `/batches/:id/edit` | FR | **FS** | **SP** | Same form; editing beside the detail you're editing. |
| Slot editor `/batches/:id/slots` | FR | **FS** | **SP (wide, 560)** | Week editing needs width but not the whole window. |
| Bulk add `/batches/:id/bulk-add` | FR | **FS** | **DLG (720, 2-col)** | Focused rapid-entry mode; a modal dialog makes "শেষ করুন" an obvious exit. |
| Batch detail `/batches/:id` | INL (wide) / FR (phone) | **FS (push)** | **INL** ✓ keep | Primary navigation, not an edit. |
| Roll call (both routes) | FR | **FS** | **FR (focused mode)** ✓ keep, but add a "← আজ" crumb and keep the sidebar collapsed, not hidden | The teacher's core task; full focus is right. |
| Add student to batch (sheet) | BS (both) | **XS** | **DLG (search → form)** | The 2-step picker needs a stable centered container on desktop. |
| New student `/students/new` | FR | **FS** | **SP** | A form next to the list keeps your place. |
| Edit student `/students/:id/edit` | FR | **XS** | **SP** | Mostly 2–3 fields edited; doesn't deserve a page on phone. |
| Student profile `/students/:id` | INL / FR | **FS (push)** | **INL** ✓ keep | Primary navigation. |
| Collect payment (sheet from Fees, Today, profile) | BS (both) | **XS** | **SP** (or INL when already on `/fees/s/:id`) | Money entry deserves a stable, roomy container; the list behind shows who's next. |
| Fees student `/fees/s/:id` | INL / FR showing profile | **XS (payment)** | **INL** ✓ | Make it consistent with the row action. |
| Fees ↔ Collection `/fees/collection` | FR push via segmented | **in-page segmented** | **in-page segmented** | It's a view toggle, not navigation; no back arrow. |
| Other income (sheet) | BS | **BS** | **DLG (480)** | Short form. |
| Waive / fee change / effective-from sheets | BS | **BS** | **DLG** | Short confirmations with 1–3 fields. |
| Reschedule / extra class / class actions | BS | **BS** | **POP (actions) → DLG (reschedule/extra form)** | Menus anchor to the ⋮; forms centre. |
| Roll-call row ⋮ (status / leave / note) | BS | **BS** | **POP** | A 5-item menu shouldn't travel across the screen. |
| Batch overflow ⋮ (archive / delete) | BS | **BS** | **POP** → confirm **DLG** | Same. |
| Collection ⋮ (single item) | BS | header button | header button | A one-item menu is not a menu. |
| "আরেকটি দিন" day picker | BS | **BS** | **POP** | A 7-item list. |
| Date picker | BS | **BS** | **POP (anchored calendar)** | Desktop convention; 40 px cells. |
| Time picker | DLG | **BS** | **POP (3-column)** | Same. |
| BhorSelect dropdown | overlay | **BS when >7 items**, else overlay | **POP** ✓ | Long month lists are thumb-unfriendly as overlays. |
| Search `/search` | FR | **FS** | **DLG (⌘K palette)** | Desktop users expect a palette; it keeps context. |
| Settings sub-pages: templates, payment methods, holidays, archived, left, diagnostics, help | FR | **FS (push)** | **INL in the More right pane** (templates **SP**, holidays **DLG**) | Settings on desktop should never leave the settings layout. |
| Backup `/more/backup` | FR | **FS** | **INL (More pane)** | Same. |
| Backup review `/more/backup/review` | FR | **FS** | **DLG (720)** | A one-off, focused restore decision. |
| CSV export / backup export sheets | BS | **BS** | **DLG** | Short options. |
| Reminder priming `/reminders/priming` | FR | **BS** | **DLG** | A single yes/no. |
| Onboarding | FR | **FS** ✓ | **FR** ✓ (redesigned split) | First-run takeover is right. |

**Count moving off full routes.**
- **Phone:** 6 flows leave FR. Edit student → XS; collect-payment-via-`/fees/s` → XS; fees↔collection → in-page; reminder priming → BS; plus holiday → BS and backup review → BS if pushed from settings. 4 more change container type: sheet → expanding sheet.
- **Desktop:** 17 flows leave FR. Batch new/edit, slots, bulk add, student new/edit, fees↔collection, search, templates, payment methods, holidays, archived, left, diagnostics, help, backup, backup review, reminder priming.
- **Desktop also:** 9 bottom-sheet uses become popovers or dialogs. Roll-call row ⋮, batch ⋮, class actions, collection ⋮, day picker, date picker, time picker, add-student, payment.

Implementation note: add a `BhorAdaptive.present(context, phone: Container.xs, desktop: Container.sidePanel, builder:)` helper in `lib/app/ds/components/bhor_overlays.dart`, with `showBhorSidePanel` and `showBhorPopover` primitives. Keep URLs for deep links by rendering the panel over the parent route (go_router `pageBuilder` returns a `CustomTransitionPage` with `opaque: false` + panel chrome on wide screens).

---

## 4. Motion spec — "ভোর মোশন"

Principles: **motion explains spatial change; it never decorates.** Quick in, quicker out; exits are 20–30% shorter than entries. No bounce on content; a tiny overshoot is allowed only on confirmations (check, success). Everything respects reduced motion.

### 4.1 Tokens (replace `BhorMotion`)
| Token | Value | Use |
|---|---|---|
| `instant` | 80 ms | press-in, hover bg, checkbox fill |
| `fast` | 140 ms | toggles, chips, tooltips, icon swaps |
| `base` | 220 ms | sheets out, popovers, list inserts, cross-fades |
| `slow` | 320 ms | page push, side panel, sheet in, dialog in |
| `slower` | 480 ms | count-up, success moments, progress fills |
| `stagger` | 30 ms per item, cap 8 items (max 240 ms total) | list load |
| `emphasized` | `Cubic(0.2, 0.0, 0, 1.0)` | entries (M3 emphasized-decelerate feel) |
| `standard` | `Cubic(0.2, 0.0, 0.0, 1.0)` | most state changes |
| `exit` | `Cubic(0.3, 0.0, 1.0, 1.0)` | exits (accelerate) |
| `spring.gentle` | SpringDescription(mass 1, stiffness 380, damping 32) | sheets, drag release, thumb slides |
| `spring.snappy` | (mass 1, stiffness 600, damping 30) | toggles, the segmented thumb |
| `spring.pop` | (mass 1, stiffness 500, damping 18) | success check (a ~4% overshoot) |
| `distance.sm/md/lg` | 6 / 16 / 32 px | rise/slide offsets |

**Reduced motion** (`MediaQuery.disableAnimations`, plus an in-app toggle "অ্যানিমেশন কম"): every transform becomes a 120 ms opacity cross-fade. Count-ups show the final value. Stagger = 0. Shimmer is replaced by static surface2 blocks. No haptic changes. Wire this through the existing `effects_mode.dart`.

### 4.2 Page / route transitions
- **Phone push** (detail, full-screen forms): the incoming page slides in from x +32 px and fades 0→1 over `slow`/emphasized. The outgoing page slides to x −16 px and dims to 0.94 opacity (parallax). Pop is the reverse over `base`/exit. Support the iOS back-swipe gesture on all platforms (an interactive drag controlling the animation).
- **Phone full-screen modal** (roll call, new batch): rise from y +24 px + fade, `slow`; dismiss = drop 24 px + fade, `base`.
- **Desktop list → detail (INL)**: no page transition. The detail pane content does a **shared-axis cross-fade** (old content fades 0 over 90 ms while new content fades in and rises 6 px over 180 ms). The selected list row's highlight slides between rows (an animated indicator, `base`/standard).
- **Desktop full route** (roll call, onboarding): fade + scale 0.985→1, `slow`.
- **Tab / branch switch (shell)**: fade-through. The old page fades out over 90 ms, then the new page fades in and scales 0.98→1 over 210 ms. The nav active pill **slides** between items with `spring.snappy`; the icon swaps outline→fill with a 140 ms cross-fade + scale 0.9→1.
- **Onboarding steps**: shared-axis X (out −24 px/fade, in +24 px/fade), `slow`. The stepper check draws in (§4.8).

### 4.3 Sheets, panels, dialogs, popovers
- **Bottom sheet enter**: physics-driven `spring.gentle` from off-screen; the scrim fades 0→scrim over `base`. Content inside fades in with a 40 ms delay so it doesn't ride the spring visibly. **Exit**: a 200 ms exit curve, with the scrim fading faster (140 ms). Drag: rubber-band past full height (resistance 0.35); release velocity > 700 px/s dismisses. The handle widens 36→44 px while dragging.
- **Expanding sheet (XS)**: snaps at 60% and 100% (`spring.gentle`). Under the drag, the top radius interpolates 20→0 and the status-bar scrim fades in at 100%.
- **Sheet content change** (picker → form, validation text): `AnimatedSize` (`base`/standard), with the content swap as a shared-axis X. **Footer stays sticky.**
- **Side panel (desktop)**: slides from x +24 px + fades over `slow`/emphasized. The scrim goes to 20% black over `base`. The underlying page scales 1→0.995 (barely perceptible depth). Exit: x +16 px + fade over `base`/exit. Esc closes; focus returns to the trigger.
- **Dialog**: scale 0.96→1 + fade + y 8→0 over `slow`/emphasized; exit is fade + scale 0.98 over 160 ms. Destructive dialogs: the danger button fades in 60 ms after the body (prevents an instant accidental Enter).
- **Popover / menu**: scales from the anchor corner 0.95→1 + fade, `fast`. Items stagger 15 ms each. Exit 100 ms fade.
- **Tooltip**: 300 ms hover delay, then 120 ms fade + 4 px rise. Close immediately on pointer exit.

### 4.4 Lists and loading
- **First load stagger**: rows and cards fade in and rise 8 px, `base`/emphasized, 30 ms stagger, first 8 only; the rest appear together. Only on first paint of a route, never on tab return (the state is cached).
- **Skeletons**: `BhorSkeleton` exists but is used 0 times. Show it for any query taking > 150 ms (Drift on web takes about 400 ms on cold start). Shimmer = a 1.2 s linear sweep, a 20°-angled gradient band (surface2 → surface2+6% → surface2), with a 200 ms cross-fade into real content. Skeleton shapes must match the real row heights (no layout jump).
- **Insert / remove**: `SliverAnimatedList`. Insert = height grows 0→h + fade (`base`). Remove = fade + slide x −12 px (140 ms), then collapse the height (`base`). Reorder = a positional `spring.gentle`.
- **Filter change**: the list cross-fades (`fast`); counts in chips tick (4.5).

### 4.5 Numbers
- **Count-up** for stats and money: ৳, totals, percentages, counts. On first appearance, tween from 0 (or the previous value) with `slower` + `Cubic(0.16,1,0.3,1)`. Bangla digits are rendered per frame with tabular figures so width is stable. On change (e.g. after a payment), roll from old to new: digits that change slide vertically by 60% of the line height (an odometer feel), `base`. Respect reduced motion.
- **Progress bars**: fill animates from 0 on appear, and from old→new on change, `slower`/standard. The escalation bar's segments fill left-to-right with an 18 ms stagger.

### 4.6 Micro-interactions
- **Press**: scale 0.97 over `instant` with standard easing; release springs back with `spring.snappy`. Overlay +6%.
- **Hover**: bg overlay 0→4% over `instant`; card border line→accentLine over `fast`; cursor changes. Icon buttons get a 32 px round surface2 halo.
- **Focus-visible**: the ring grows 0→2 px (offset 2) over `fast`. No glow.
- **Chips (filter/day)**: selection fills the bg over `fast`; the ✓ icon slides in from the left inside a **reserved slot** (no width change).
- **Text field**: focus = the border colours to accent over `fast`, and the label shifts to accent. Errors slide down 4 px + fade (`fast`) with a 2-cycle, 4 px horizontal shake (240 ms total) on submit only.

### 4.7 Toggles and choice controls
- **BhorSwitch**: the thumb travels with `spring.snappy`; the track colour cross-fades over `fast`; the thumb squashes to 1.15× width while the press is held.
- **BhorSegmented**: the thumb slides with `spring.snappy`; labels cross-fade text2↔text over `fast`. Same for the bottom-nav pill and the tabs underline (the underline also stretches toward the destination, then settles).
- **BhorCheckbox / radio card**: the check path draws in (stroke-dash 0→100%) over `fast`; the box fill grows from the centre (scale 0.6→1). The radio card border goes line→accent and the inner dot scales 0→1 with `spring.pop`.
- **Accordion (Help, "আরও তথ্য", "মাস ভাগ")**: height via `AnimatedSize` (`base`); the chevron rotates 180° (`base`); content fades in with a 60 ms delay.

### 4.8 Attendance toggle feedback (the most-repeated interaction in the app)
- Tapping a row to switch present → absent:
  1. Press scale 0.98.
  2. A colour wash expands as a circular reveal from the tap point across the row over `base`, so the row "fills" from the finger.
  3. The status icon morphs ✓→✕ (a rotate 90° + cross-fade, `fast`).
  4. The label text cross-fades.
  5. **Light haptic** (`HapticFeedback.selectionClick`) on mobile.
- Late: the clock icon does one 25° tick-tock rotation (180 ms); the row tint fades in.
- "সবাই উপস্থিত / সবাই অনুপস্থিত": the changes ripple down the list with a 20 ms stagger (top to bottom), so the bulk action is legible.
- The side summary or bottom count line updates with the odometer (4.5). Undo restores in reverse order.

### 4.9 Toasts
- Enter: from below, y +16 px → 0 + fade, `spring.gentle`, **above** the bottom nav / sticky CTA / open sheet. Desktop: bottom-centre of the *content area* (excluding the sidebar), above any bottom bar.
- Stack up to 3 (scale 0.96 and 8 px offset for older ones). Hover pauses the timer. Swipe down or right to dismiss.
- A countdown hairline at the bottom shrinks over the toast's lifetime (4 s, or 6 s when it has an action). The leading icon is semantic: `CheckCircle` (ok), `ArrowCounterClockwise` (undo available), `WarningCircle`.
- Exit: fade + y +8 px, 160 ms exit.

### 4.10 Success moments (subtle, premium — no confetti)
- **Payment saved**:
  1. The sheet's primary button morphs into a ✓ circle: the width collapses to 48 px over `base`, then the label becomes a check drawn in with `spring.pop`.
  2. 200 ms hold, then the sheet dismisses.
  3. On the screen behind, the affected student row's tag cross-fades overdue → paid (`fast`), and the row background flashes okBg at 0→40%→0 over 600 ms.
  4. The dues total and "এই মাসের আদায়" roll to their new values (odometer).
  5. A toast "৳১,০০০ জমা হয়েছে · রসিদ পাঠান".
  6. Medium haptic.
- **Roll call saved**:
  1. The save button morphs to a ✓ as above, with a small ring that expands 1→1.6× and fades (one pulse, 400 ms).
  2. The full-screen page dismisses.
  3. On Today, the routine row's clock icon morphs into the ✓ circle and the "হাজিরা ৩/৪" chip pops in (scale 0.9→1, `spring.pop`).
  4. The attendance-card percentage counts up.
  5. When it was the last class, the hero cross-fades to the done banner and the check draws in.
- **Batch / student created**: the new card is inserted with height-grow + fade and gets a 1.2 s accentTint highlight that fades out. The list auto-scrolls it into view (`slow`).
- **Backup created**: the cloud icon's arrow travels up and out (240 ms), then the ✓ draws.

### 4.11 Scroll behaviours
- **Header**: on scroll > 4 px, the hairline bottom border fades in and the bg gains 80% opacity + blur(12) over `fast`. On phone, the large title collapses into the compact app-bar title (scroll-linked, not timed).
- **Phone FAB**: hides on scroll-down (y +80 px, `base`) and shows on scroll-up; it shrinks from extended to icon-only after 120 px of scroll (the label width animates).
- **Pull-to-refresh**: not needed (local data).

### 4.12 Where *not* to animate
Typing, number entry, timers (the "৪২ মিনিট পর" countdown updates in place), list scroll, anything repeating more than once per second, and any data refresh without user cause.

---

## 5. Top-20 fix list (prioritised)

1. **Adaptive containers** (§3): side panels / dialogs / popovers on desktop for every form and menu; `BhorAdaptive.present` helper. Kills the "edit opens a whole page" complaint (17 desktop flows).
2. **Motion foundation** (§4.1–4.3): new tokens, fade-through tab switches, phone push with parallax + back-swipe, spring sheets, side panel / dialog / popover motion, reduced-motion path.
3. **Icon swap to Phosphor Regular/Fill** (§1.4) app-wide, plus a real brand mark.
4. **Roll-call row redesign**: absent styling, inline ghost "দেরি" button, a popover menu, and attendance toggle feedback with a haptic (§2, §4.8).
5. **Fees list density + FAB overlap**: 72 px swipeable rows, remove the duplicate CTA, fix the overlap, drop the duplicated summary pane at 1440.
6. **Toast placement**: always above the bottom nav / CTA / sheets; stacking, countdown hairline (§4.9).
7. **Success moments** for payment saved and roll call saved, plus odometer count-ups for money and stats (§4.5, §4.10).
8. **Type scale** to a 13 px minimum, a larger display, a two-weight-per-card rule; Bangla digits in inputs (§1.1, §1.8).
9. **Red de-escalation**: the month-dot strip, edge stripes instead of repeated tags, a meaningful honey→rose escalation bar (§1.3).
10. **Kill layout shift**: reserved check slots, `AnimatedSize` for inserted blocks, a stable bottom bar height, sticky sheet footers (§1.2).
11. **Button system**: primary/secondary/tonal/ghost/danger at 48/40/32; one primary per view; dark-mode primary with white text; real disabled state (§1.5).
12. **Batch detail student grid bug at ≥1200 px** (per-character wrap), and a single add-student entry point.
13. **Collect payment sheet**: one close button, multi-month selection with a live total, method scroller, date field.
14. **Today phone order** (routine first), quick actions at the top, a compact done-state hero, content-height desktop grid.
15. **Skeletons + list stagger** on first load (`BhorSkeleton` is currently unused).
16. **Search → ⌘K palette on desktop**, recents on phone, no double empty state, no auto-focus race.
17. **Segmented / tab controls**: a clear selected state in light mode; Fees↔Collection becomes an in-page segment, not a route push; a sliding indicator on nav, tabs and segments.
18. **Phone FAB position** (100 px float) and hide-on-scroll; list bottom padding so the FAB never covers a row.
19. **Date and time pickers as anchored popovers on desktop**, with "আজ" and a month jump; no ✓-plus-fill double signal.
20. **Settings polish**: one-column content, a lighter sub-nav, theme tiles as the selector, token chips in templates, consistent empty states, "সেভ করুন" wording everywhere.
