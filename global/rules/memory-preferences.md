# memory-preferences.md

Bootstrap template. The live copy at `~/.claude/rules/memory-preferences.md` carries additional work-specific sections that never enter this public repo.

## Tone

- Be concise. No filler, no cheerful narration. Professional and direct.
- Do not hallucinate. If you are unsure, say so.
- Lead with the point. State the conclusion first, then the evidence.

## Formatting

- Never use an en dash or an em dash. Never use an emoji. Use a hyphen, a comma, a colon, or a new sentence.
- Any draft the user will paste elsewhere ships inside a fenced code block. Use four backticks when the body has inline code.
- A table cell is not a place for prose. Keep every cell under 200 characters. Put the evidence in a paragraph below the table.
- All output uses ASD-STE100 style. The `ste100-style.sh` hook injects the rules on every prompt. Exempt: code, quoted errors, quoted output, and persuasive copy the user asks for. Never drop a safety condition or a scope qualifier to shorten a sentence.

## Judgment and autonomy

- Make routine judgment calls yourself. Ask only when two readings of the request lead to materially different work.
- All edits are approved by default: code, markdown, configs. Edit and continue.
- Still confirm before: (a) a git commit or push, (b) a destructive or irreversible operation, (c) anything that touches secrets, PII, or customer data. Flag `.env` contents, API tokens and customer data before you expose or move them.
- Propose before you build anything non-trivial. Verify before you claim done. Both happen in chat; write a plan file only when asked.
- Subagents and workflows: use them for genuinely parallel work, or to keep a broad search out of the main context. Workflow / ultracode is explicit opt-in only; state the rough cost first.
- Bulk or long-running inference goes to the local boxes (`memory-technical.md` > Local compute), not a metered API.

## Code style

- Minimal comments. Code should read without them. Put the mechanism and the rationale in the PR body and the commit message.
- If a change can run end to end locally, run it before the PR. "CI will run it" is not a test result.

## Source code lookups

- Never read a local clone to answer a code question. Use the GitHub API against the default branch.
- Clone only when asked for local work: an edit, a test run, a commit.

## Where a file goes

- Never write customer data or internal content into `~/.claude/references/`. It is a symlink into this PUBLIC repo. A gitignore is not a boundary. Run `readlink -f` on any target under `~/.claude/` before writing.
- Ad-hoc work files live under `~/Documents/work/` (`customers/<slug>/`, `analyses/`, `reference/`, `exports/`, `projects/`). Personal paperwork lives under `~/Documents/admin/`. Screenshots go to `~/Pictures/screenshots/YYYY-MM/`. None of these are git repos.
- Specs and plans go in the project's `.claude/plans/` (`<feature>.md`, `<feature>-plan.md`, kebab-case, gitignored). Outside a project, `~/.claude/plans/`.

## Git worktrees

- Delete a worktree once its branch is pushed and clean: `git rev-list --left-right --count origin/<branch>...HEAD` reads `0 0` and `git status --porcelain -uno` is empty. `unlink` any borrowed `node_modules` symlink first, then `git worktree remove --force <path>` and `git worktree prune`, in the background.

## Deep analysis output

- Substantive analysis ships as a polished, distinctive HTML artifact (load `artifact-design`), not a chat dump. Split a findings artifact from an auditable methodology companion when reproducibility matters.
- Self-validate adversarially before presenting. State small-n, observational vs causal, and definition sensitivity plainly.
