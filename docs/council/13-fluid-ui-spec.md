# Fluid ভোর UI — user-approved spec (2026-11-22)

Source of truth: the user approved the "bhor_fluid_components_v4" component gallery and the "bhor_fluid_screens_mobile_desktop" screen mocks. This doc transcribes them. Functionality is final — this is a UI/UX-only overhaul. Also apply `12-ux-review.md` (per-screen fixes, navigation table §3, motion spec §4) wherever it does not contradict this doc. Bar: premium, fluid, dynamic, never boring, effortless to use.

## Hard rules
- No glow / coloured shadow under buttons or cards. No gradients except: the hero (next-class) card, and nowhere else. No Material widgets (CI enforces).
- Soft, filled controls (no outlined boxes). Hairlines only to separate list rows and to edge cards/panels.
- Every interaction animates (press, select, open, close, insert, count). Reduced motion → 120 ms cross-fades.
- Bangla text never below 12.5 px; body 14.5–15.5; titles 17–26 (700); numbers tabular.

## Tokens
Light: bg #F6F5F1 · surface #FFFFFF · soft (control fill) #EFEDE8 · soft2 (hover/pressed) #E3E0D8 · line #E7E4DD · text #17181C · text2 #55585F · text3 #74777F · accent #5B4FE0 · accentHover #5045D2 · accentTint #EDEBFC · focusRing accent@14% (4 px) · hero 140° #4C42C9→#6A5BE0 · ok #0F7A58/#E2F3EC · warn #8A4A00/#FCEBD5 · overdue #A3153F/#FBE3E8 · absent #3F4660/#E6E8EE · late #0B6A80/#DDF0F4 · error #C23A52.
Dark: bg #0F1014 · surface #191B21 · soft #21242C · soft2 #2E323C · line #262932 · text #EDEEF2 · text2 #B0B4BF · text3 #8D92A0 · accent #7B72F6 (white text) · accentHover #877EF8 · accentTint accent@16% · focusRing accent@22% · hero #3B3399→#5A4BC4 · ok #5CD3A6/@15% · warn #F2B866/@15% · overdue #FF8FA6/rgba(224,82,111,.18) · absent #D0D5E4/@20% · late #8FDCEC/@16% · error #F07C8F.
(Keep AA contrast; adjust a hex minimally if a test fails and note it.)
Radii: controls 14 · chips/tags/toast/attendance pill 999 · cards & lists 18–20 · hero 22 · bottom sheet 28 (top) · side panel 20 (floating, 10 px inset) · phone nav pill 20 · avatars circle.
Spacing 4-pt grid; screen padding 16 phone / 18–24 desktop.

## Motion tokens
spring = cubic-bezier(.34,1.4,.64,1) (≈ SpringDescription mass 1, stiffness 420, damping 26) for thumbs, indicators, sheets, chips, toasts, press-release · ease = cubic-bezier(.2,0,0,1) for fades/colour · durations: instant 80 (press), fast 150–200, base 250–300, slow 400–500 (sheets, panels, indicators), count-up 260–480.

## Components (lib/app/ds) — exact behaviour from the mock
- **Button**: h46 (sm 36–42), r14, solid. Primary accent + white text + 1 px inner top highlight rgba(255,255,255,.16); Secondary = soft fill, text colour; Ghost = accent text, accentTint on hover; Icon = 46×46 soft. Press scale .96 (80 ms) → spring back; hover colour shift 200 ms; trailing arrow nudges +3 px on hover; loading = spinner → ✓ "হয়েছে" morph.
- **TextField**: h56, r14, soft fill, NO border. Floating label inside (15 px at rest → 12 px at top on focus/filled, 220 ms ease). Hover → soft2. Focus → surface fill + 1.5 px accent inset ring + 4 px focus ring, label turns accent. Error → 1.5 px error ring + message slides down 4 px + fade.
- **Select**: field-styled; chevron rotates 180° with spring; menu drops from the field (scale .96→1, y −4→0, fade, 200 ms) as a surface popover with ✓ on the chosen item; on phone use a bottom sheet list instead.
- **Segmented**: soft track r14 p4; surface thumb with tiny shadow glides (left+width spring 400 ms); label colour cross-fade.
- **Chip** (filter/choice): pill h38, soft fill; selected = accentTint + accent text + ✓ icon that slides in (width 0→20, spring).
- **Switch**: 50×30, thumb spring-slides, stretches to 30 px while pressed; track colour fades.
- **Attendance toggle**: soft pill track; coloured thumb (ok/absent/late tint) glides between উপস্থিত / অনুপস্থিত / দেরি (labelled on wide; icon-only ✓ ✕ clock in dense phone rows), icon/text colour follows; counts update live.
- **Stepper**: soft track, surface ± buttons (press scale .9), value counts up/down.
- **List**: surface card r18–20 with 1 px line edge; rows separated by inset hairline; row hover/press → soft; circle avatar (accentTint bg, accent initials); pill status tags; money right-aligned bold tabular.
- **Toast**: floating pill (surface, line edge, soft neutral shadow allowed only here and on floating panels/menus), icon + text + pill action; enters with spring (y+14, scale .96→1); auto-dismiss; above the phone nav pill.
- **Bottom sheet (phone)**: r28 top, grab handle, spring up from bottom (500 ms), scrim fade; drag to dismiss; success state = circle ✓ that pops (spring) and draws its stroke, then sheet closes and toast appears.
- **Side panel (desktop)**: floating card inset 10 px from the right edge, r20, slides in from the right with spring; list behind stays visible and interactive-dim; Esc/✕ closes.
- **Dialog (desktop confirmations)**: centered card scale .96→1 + fade.
- **Phone nav**: floating pill bar (inset 10 px, r20, line edge); accentTint indicator glides between items (spring 450 ms); active icon switches regular→fill.
- **Desktop sidebar**: brand mark (solid accent rounded square + "হা"), items h40 r12; accentTint indicator glides vertically between items (spring); active icon fill.
- **Hero card**: the only gradient; white text; primary action = near-white solid button with hero-colour text.
- Icons: Phosphor (Regular; Fill for active/status), sizes 16/18/20/24 — add `phosphor_flutter` (pin a version ≥ 2 weeks old) and replace all icon usage.

## Adaptive container (one API, two renderings)
`showBhorPanel(context, ...)` → phone: bottom sheet (or expanding sheet for long forms); desktop (≥ 840): floating side panel (forms, payment, student/batch edit, slot editor, other income, filters) or centered dialog (confirmations, short choices). Apply the navigation table in `12-ux-review.md` §3 so edit/create flows no longer push full routes on desktop (and use sheets on phone where the table says so). Roll call, onboarding and batch/student detail stay full-screen.

## Screens (from the mock)
- Phone Today: greeting header (date small + "শুভ সকাল/বিকাল/সন্ধ্যা" 26/700) + round search button; hero next-class card with full-width "হাজিরা নিন"; "বকেয়া" list with tags and amounts, tapping a row opens the payment sheet; staggered first-load (30 ms/item, max 8) and number count-ups.
- Phone roll call: back button (soft r13), title + subtitle, live count tags (উপস্থিত/অনুপস্থিত/দেরি), list rows with the attendance toggle, full-width save button pinned bottom.
- Desktop Fees: title + subtitle, segmented বকেয়া/আদায়, primary "টাকা নিন"; three summary tiles (count-ups, progress bar animates); dues list rows with tag, amount, and a secondary "টাকা নিন" button that opens the side panel.
- Every other screen follows the same language; fix every per-screen issue from `12-ux-review.md`.
