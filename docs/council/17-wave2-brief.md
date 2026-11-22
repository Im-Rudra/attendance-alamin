# Wave 2 — common brief for feature builders

You are a world-class Flutter product engineer rebuilding ONE feature area of Hajira Khata on the new desktop foundation. The bar: premium, calm, effortless, no wasted space, no clipping, nothing surprising. The owner reviewed the real Windows app and was unhappy. Every finding ID assigned to you must be visibly fixed.

## Read
- `docs/council/15-windows-ux-review.md`: the findings (your IDs are in the plan).
- `docs/council/16-windows-rebuild-plan.md`, section "Wave 2": your module's scope and folders.
- `docs/council/11-ds-migration-guide.md` §5 (selection style and template usage), plus `lib/app/shell/templates/templates.dart` and `lib/app/ds/ds.dart` for the wave-1 APIs:
  - containers and menus: `showBhorPanel(kind:, dirty:)`, `BhorPanelKind.choice`, `showBhorMenu` / `BhorMenuItem`, `BhorDirtyScope`, `showBhorConfirm`;
  - page templates: `BhorDashboardPage`, `BhorMasterDetailPage` (+ `foldedRailOf`), `BhorSettingsPage`, `BhorFocusPage`;
  - components: `BhorTabs`, `BhorEmptyState(size:)`, `BhorMasonry`, `BhorCard(selected:)`, `BhorListRow(selected:)`, `BhorPickerField`, `BhorTextField(localDigits:, readOnly:)`, `BhorDigits`.
- `docs/council/13-fluid-ui-spec.md`: the look (unchanged).
- `docs/council/05-builder-protocol.md`: the workflow (branch from origin/main, PR, full CI green, hand back ONCE).

## Rules
- Touch only your folders (listed in the plan). If you truly need a DS change, keep it tiny and additive, and say so in the handback.
- Containers:
  - Desktop: every create/edit form opens in a side panel (`showBhorPanel` form); confirmations go in `showBhorConfirm`; ⋮/row menus use `showBhorMenu`; short choices use `BhorPanelKind.choice`.
  - Never use full-page forms. Never call `showBhorSheet` / `showBhorDialog` directly. Delete your lines from `tool/containers_allowlist.txt` (run `bash tool/check_containers.sh` locally; `--write` regenerates).
- Every form or editor passes `dirty:` (true once the user changed something) so closing asks before discarding.
- Use the page template that fits your screens. Cards hug their content, with no equal-height grids. Nothing may truncate or clip at 1214 or 910 window width, in Bangla or English.
- No functionality changes beyond the listed fixes. Keep the existing tests passing, and update them only where the UI intentionally changed. Add tests for the new behaviour.
- New strings go in your feature's ARB fragment (bn + en). The Bangla must be natural.
- No Flutter SDK locally; CI is the compiler. Self-review for compile errors before every push.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. gh CLI: "/c/Program Files/GitHub CLI/gh.exe", repo Im-Rudra/attendance-alamin.
- Other wave-2 builders work in parallel on other folders. If `tool/containers_allowlist.txt` conflicts on rebase, regenerate it with `--write`.
- Hand back once (≤ 20 lines): the PR URL, CI status per job, each finding ID → what changed, deviations, and anything unverified.
