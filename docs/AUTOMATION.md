# NEXA Music — Claude + GitHub + Codex Code Review

**Status (2026-10-16):** repository configuration prepared; Codex automatic GitHub review remains **UNVERIFIED / NOT YET ACTIVATED** until the owner enables it in their Codex account. This change is infrastructure-only (CR-002), not a phase acceptance.

## Architecture and responsibilities

| Actor | Responsibility | Must not do |
| --- | --- | --- |
| Claude Agent on the owner's Windows PC | Implement only the approved phase; run actual Windows checks; maintain report and PR branch; fix review findings in the same phase | Start the next phase, overwrite the Master Plan, merge itself |
| GitHub / Actions | Store code and reports; for ready PRs check tracked files, unchanged Master Plan, Flutter analyze/tests/Windows release build | Claim that a human heard audio or approved a phase |
| Codex Code Review | Review GitHub PRs, read root AGENTS.md, leave advisory findings | Accept a phase or auto-merge |
| KondexOff (owner) | Authorize a phase; inspect evidence and result; accept/reject the phase; merge PR; separately authorize the next phase | — |

**Invariant:** even if CI is green and Codex posts no findings, Claude **STOPS** after the report. No Phase N+1 starts without the owner's explicit permission. An infrastructure PR merge never equals phase acceptance.

## 1. Enable Codex Code Review (owner action)

1. Open the official [Codex GitHub code review settings](https://chatgpt.com/codex/settings/code-review) from Codex / Review code. If the deep link differs, navigate from Codex settings to **Review code**.
2. Connect the GitHub account/repository **KondexOFF/Nexa-Music** to Codex. A GitHub connection in ChatGPT by itself does not prove the **Codex review** feature is enabled.
3. In repository code review settings, choose NEXA Music and turn on **Automatic review**. Under **Personal preferences**, enable automatic reviews and choose an appropriate **Review trigger** (prefer when the PR is ready for review, if offered). Review the account's quota/plan before enabling.
4. Verify with a representative **ready** pull request. In a PR comment, `@codex review` is an official manual trigger / fallback. Check that the bot reacts and posts a code review. If no response, confirm account, installation permission, repository and triggers. Do **not** mistake an unrelated setting named "Auto-review" under action permissions for GitHub PR code review.
5. Codex review is additional evidence, not a formal PASS check. Root `AGENTS.md` contains repository-specific review rules.

Official reference: https://developers.openai.com/codex/cloud/code-review

## 2. Set up GitHub repository safeguards (owner action)

On GitHub, inspect **Settings → Rules → Rulesets** (or **Settings → Branches**, depending on UI and plan) for the private repository:

- Target **`main`**. Require PR before merging and require passing check names **Repository safety and plan lock** and **Windows Flutter analyze, test and build** *after these checks have run and are visible*. Avoid requiring a human reviewer if you are the sole GitHub account, because authors cannot approve their own pull requests. An optional second trusted reviewer can be added later.
- Leave **auto-merge OFF**; do not add merge bots or broad write tokens. Only KondexOff manually presses merge **after** phase acceptance. Limit direct pushes to `main` if your GitHub plan supports it.
- Never enable "delete head branch automatically" as a substitute for review; deletion behavior is separate.
- Repository settings/rulesets require owner/admin permissions and may vary by private-repository GitHub plan. The current GitHub connector cannot establish that these protections are active; check settings manually.

If required checks cannot be configured on the GitHub plan, the process still uses owner review/merge, but it is a **procedural gate**, not a technically enforced barrier. Don't claim stronger enforcement.

## 3. Claude's workflow per authorized phase

1. KondexOff gives **explicit authorization for Phase N** on the Windows computer (and, if desired, scoped continuing permission to push only the `phase/NN-review` branch and PR updates for that phase). `CLAUDE.md` and Master Plan remain authoritative.
2. Claude works only in Phase N; protects local tracks, user data, credentials and secrets. Run tests on Windows. Save a truthful `reports/PHASE_NN_REPORT.md` with PASS/FAIL/NOT RUN and screenshots/logs without identifying device paths.
3. Claude commits and, **only within the owner's authorized push scope**, pushes its phase branch and creates/updates a **DRAFT** pull request. Do not push directly to main.
4. Once evidence is ready and owner authorizes review, mark PR **Ready for review**. GitHub Actions runs; Codex reviews if enabled. GitHub's private Windows CI consumes Actions minutes and may incur billing beyond the plan's allowance. The workflows use timeouts and cancel superseded runs.
5. Claude addresses relevant findings and failing checks in the **same phase** on the same branch, updates the report and pushes again within the authorized scope. Re-review and re-run checks; no unrelated new features.
6. **STOP:** KondexOff compares PR diff, tests, report, screenshots and manual audible/playback checks. If satisfied, owner explicitly accepts the phase and manually merges the PR. **Separately**, the owner authorizes Phase N+1. If not accepted, repeat step 5.

GitHub CI cannot listen to sound, test specific MP3/FLAC/WAV files on your computer, or verify actual output-device behavior. Tests on Windows must remain part of each phase report.

## 4. Current branch layout (2026-10-16)

- `main`: original documents; Flutter code has not been merged yet.
- `phase/00-review`: Phase 0 code, evidence and report; PR #1, unmerged.
- `chore/nexa-automation`: this setup, proposed as a **draft PR targeting `phase/00-review`**. This ensures that Flutter CI will have actual Flutter sources when tested. It does **not** authorize Phase 1.

Suggested order: review this setup PR, enable Codex, mark setup PR ready and inspect CI, then **owner decides** whether to merge the setup PR into Phase 0 branch. After Phase 0's own acceptance, the owner may merge PR #1 to `main`. If the phase branch is merged first, retarget the setup PR to `main` and recheck its diff. No automatic merges at any step.

## 5. Troubleshooting / security

- If Codex is silent, try `@codex review` on a ready PR after verifying the repository's Codex integration; GitHub connector access is not enough.
- If CI fails, attach error details and record FAIL; do not bypass the check or assert tests passed. Some desktop/audio behaviors are only checkable locally.
- Do not add Claude or OpenAI API keys to this repository or GitHub Actions. This first configuration does **not** install `claude-code-action` or give bots write permissions.
- All automatic review comments, workflow minutes and user account limits are external services and may change.
