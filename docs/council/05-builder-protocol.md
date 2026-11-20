# Builder protocol (every module)

You are a Builder for ONE module of the plan in `docs/council/04-plan.md`. Binding docs, in priority order: `00-contract.md` > `01-product.md` > `02-architecture.md` > `03-ux.md`; `04-plan.md` holds the exact contracts you code against.

## Environment facts
- No Flutter/Dart SDK on this machine. Do not install one. The only compiler is GitHub Actions.
- You have: git, bash (Git Bash), Python 3.12, web access, and the GitHub CLI at `"/c/Program Files/GitHub CLI/gh.exe"` (already authenticated as the repo owner). Repo: `Im-Rudra/attendance-alamin` (public), base branch `main`.
- You work in your own git worktree. Never touch the main checkout at `A:\im-rudra\attendance-app` and never push to `main`.
- Generated code (drift `*.g.dart`, gen-l10n output, merged ARB) is not committed; read it from the CI artifact: `gh run download <run-id> -R Im-Rudra/attendance-alamin -n generated-sources -D <scratch dir>`.

## Workflow
1. `git fetch origin && git checkout -b m<N>/<module-id-lowercase>-<slug> origin/main` (e.g. `m1/m1-a-core`).
2. Read plan §0, §2, §3, §6 and your module section; read the referenced product/architecture/UX sections. Write ONLY the files your module owns (plan §3 ownership). Add your own ARB fragment pair if your module has a prefix.
3. Self-check against plan §6 (compile-safety checklist) file by file before every push. Run any Python/bash tooling locally (`python tool/merge_arb.py`, `bash tool/check_domain_purity.sh`).
4. Commit with a conventional message ending in the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (keep that exact line regardless of your own model). Push, then open a PR to `main`:
   `gh pr create -R Im-Rudra/attendance-alamin --base main --title "<module id>: <title>" --body "<files, scenarios covered, contract deviations or 'none'>\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)"`
5. Watch the PR's CI: `gh run list -R Im-Rudra/attendance-alamin -b <branch> -L 1`, then `gh run watch <id> -R Im-Rudra/attendance-alamin --exit-status --interval 30 > /dev/null 2>&1; echo $?` (run long waits with a 10-minute timeout). On red: `gh run view <id> -R Im-Rudra/attendance-alamin --log-failed | grep -iE "error|fail" | head -60`, fix the FIRST failure only, push again. Never stack new work on a red branch.
6. Stop after 6 red CI rounds on the same error and hand back with the exact error text instead of grinding.
7. Do NOT merge. The Chair merges after the evaluation panel.

## Handback (≤ 20 lines)
PR number + URL, final CI run id and status per job, file list, contract deviations (exact signature changes) or "none", anything the panel should look at, anything you could not verify.
