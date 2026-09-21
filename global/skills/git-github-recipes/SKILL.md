---
name: git-github-recipes
description: Mechanics of git and the GitHub API that cost a wrong first attempt - signed-commit rulesets and what they forbid, the ~/.config/git layout and its include chain, HTTPS credential helpers for GUI apps, API paths that 404 or return a silent zero, canonical-repo checks before an absence claim, squash-merge and release mechanics, and the PostHog/posthog local venv. Load before a commit, a merge, a release, a repo-settings write, a code search that returned zero, or any claim that a file or symbol does not exist in a repo.
when_to_use: Committing or pushing to a repo with a signed-commits ruleset, merging or releasing through gh, reading PR reviews or files through the API, concluding that a symbol or field does not exist, a git config that reads empty after a dotfiles pull, an HTTPS remote that prompts for a username, or a PostHog/posthog commit whose pre-commit hook dies.
---

# Git and GitHub recipes

## Signed commits

PostHog's org-level ruleset requires verified signatures on every branch of every PostHog repo, not only master (`GH013`). Git is configured for it: SSH format, `user.signingkey=~/.ssh/id_ed25519_signing.pub`, `commit.gpgsign=true`. `~/.ssh` holds `id_ed25519_signing`, its `.pub`, and `allowed_signers`. Run `git log -1 --format='%G?'` after the first commit of a session; quote the `?` or zsh globs it. An unsigned commit is rejected only at push time.

The contents API does not route around it. GitHub web-flow signs commits from a GitHub App token, but a `gh` OAuth token (`gho_*`) and the Copilot MCP's `create_or_update_file` both get `409 Repository rule violations found / Commits must have verified signatures`. Sign locally.

**The same ruleset bans rebase merge.** `gh pr merge --rebase` dies with `Base branch requires signed commits. Rebase merges cannot be automatically signed by GitHub`. Squash or merge-commit. Squash keeps the author's message only if you pass it:

```
gh pr merge <n> --squash --subject "$(git log -1 --format=%s origin/<branch>)" --body "$(git log -1 --format=%b origin/<branch>)"
```

Verify with `gh api repos/<o>/<r>/commits/<sha> --jq .commit.verification.verified`. A LOCAL `git log --format='%G?'` reads `E` on a GitHub-signed commit because the web-flow key is not in `allowed_signers`; that is not a failure. `gh pr merge --delete-branch` deleted the local branch and left the remote one with exit 0, so follow it with `git push origin --delete <branch>`.

## The git config layout

The config lives in `~/.config/git/` since 2026-09-09: `config`, `posthog`, `signing`, and the machine-local `local` (formerly `~/.gitconfig-local`). `install.sh` in dotfiles links them, and links `signing` only where the signing key exists. **Git reads `~/.config/git/config` only when `~/.gitconfig` does not exist**, so a dotfiles pull alone leaves the old symlink dangling and `user.email`, `commit.gpgsign` and `allowedSignersFile` all read empty. Rerun the installer in the same session as the pull. `git config --global --get <key>` does not follow the include chain and reports a live key as missing; drop `--global` to read the effective value.

Rule for any dotfiles path move: grep the whole repo AND the home dotfiles for the old path. `install.sh` manages only what it links, and an untracked legacy file (`~/.bash_profile` on m4max) keeps a stale line working until it breaks.

Signing loads only via `includeIf "gitdir:/Users/"`. `gpgsign=true` on a keyless box breaks every commit; m4max is keyless and leaves `gpgsign` unset. Git identity: gmail default everywhere, `jake.s@posthog.com` only via includeIf work-dir blocks (posthog, posthog.com, gtm-toolkit, runbooks).

## HTTPS remotes and GUI apps

An HTTPS remote needs a credential helper in `~/.config/git/local`, and the helper needs an ABSOLUTE path:

```
[credential "https://github.com"]
    helper = !/opt/homebrew/bin/gh auth git-credential
```

An app launched from Finder (Obsidian, any Electron app) gets a minimal PATH and never sees `/opt/homebrew/bin`. SSH is not the fallback: `id_ed25519_signing` is a signing key only, and the `gh` token lacks `admin:public_key`. Verify with `env -i HOME=$HOME PATH=/usr/bin:/bin GIT_TERMINAL_PROMPT=0 git ls-remote origin`. From a NON-INTERACTIVE ssh session on a Mac, `gh auth git-credential` fails with `-25308` (locked login keychain); the same helper works from a GUI session.

## API paths that lie

- **`PATCH /repos/{o}/{r}` needs admin.** Maintain permission gets a bare `404 Not Found` on a private repo. Run a no-op maintain-level control write (`PUT .../topics` with an empty list) before you blame the token, then send the user to the web settings page, which Maintain can use.
- **Code search is intermittent org-wide.** It returned zero for every query on 2026-08-17 and worked on 08-19. Run a control query with known hits before any absence claim. Fallback: `gh api "repos/<o>/<r>/git/trees/<branch>?recursive=1" --jq '.tree[].path'` (one call), grep, then `gh api repos/<o>/<r>/contents/<path> --jq .content | base64 -d`. A `contents/<dir>` listing truncates at 30 entries; use the tree.
- **`/pulls/<n>/reviews` and `/files` can 404 on a PR that exists, and `gh pr view --json` can 503.** Read reviews from the timeline: `gh api "repos/<o>/<r>/issues/<n>/timeline?per_page=100" --jq '.[] | select(.event=="reviewed")'`. `raw.githubusercontent.com` rate-limits to 429 after roughly 100 parallel fetches and poisons every later curl; fetch bulk content through `gh api contents`.
- **`is:unmerged` returns a silent zero.** Read merge state from the search payload's `.pull_request.merged_at` (null plus `closed_at` means closed unmerged) or from `pulls/<n>` `.merged`.

## Absence claims

**Check that a repo is canonical before reading it: `gh api repos/<o>/<r> --jq '.archived, .pushed_at'`.** On 2026-08-24 an archived repo (`posthog-js-lite`, last push 2025-07) produced a confident false negative about a React Native config field that the live monorepo (`posthog-js/packages/react-native`) had shipped months earlier. A stale repo really does lack the field, so every other check passes. Two rules: reconcile a search result against what context already says, and never assert "X does not exist" from a repo whose `archived` and `pushed_at` you did not read. **An implausible finding is a signal to recheck the premise, not a discovery.** When a finding requires someone competent to have made an obvious mistake, verify what you are looking at before you verify what it says.

## Before you document or edit a repo

`git fetch && git log --oneline HEAD..origin/main` before rewriting anything in a repo that self-driving PRs land in. A README rewritten from a `main` six merged PRs stale described replaced behavior and had to be redone. Also `grep -rn '^<<<<<<< ' .` on that first read: a merged PR is no proof the tree is clean.

`PostHog/posthog.com` tracks `.claude/settings.local.json` on master (contents `{}`), so a local Claude Code config edit there is a working-tree diff against a public repo. `origin` there is upstream by design (Vercel skips fork PRs). Use `git update-index --skip-worktree` if you must change it locally.

## Release mechanics

1. `gh pr checks <n> --watch` right after `gh pr create` dies with `no checks reported`. CI has not registered yet; rerun it a minute later.
2. `git tag v1.2.3` with `tag.gpgsign=true` dies with `fatal: no tag message?`, so a lightweight tag cannot be made locally. Create it server-side: `gh release create <tag> --target <branch>`.
3. `--target <short sha>` returns `HTTP 422 Release.target_commitish is invalid`. Pass a branch name or the full 40-character SHA.

## PostHog/posthog local development

Backend tests run locally through the flox venv: `.flox/cache/venv/bin/pytest <path>`. `flox` and `uv` are absent from PATH; the venv binaries (`python`, `pytest`, `ruff`, `ty`) are not on it either. **Prepend `/Users/jakesciotto/github/posthog/.flox/cache/venv/bin` to PATH for any commit or push in this repo**, or the husky pre-commit hook dies on `bin/hogli: exec: python: not found`. With it, `lint:python:fix`, `format:python`, `uv run --no-sync ty check` and the pre-push `hogli ci:preflight --strict` all pass, including in a worktree. A worktree prints `uv.lock differs from <main repo>, skipping venv borrow` and gets no venv, so the PATH prefix is mandatory there too. Try the plain `git commit` first; `--no-verify` is justified only if `ty check` dies on ENOENT after you ran `ruff check --fix`, `ruff format` and the tests by hand. Never carry `--no-verify` to the push.

Worktree cleanup: once `git rev-list --left-right --count origin/<branch>...HEAD` reads `0 0` and `git status --porcelain -uno` is empty, `unlink` any borrowed `node_modules` symlink, then `git worktree remove --force <path>` and `git worktree prune`, in the background. A posthog worktree is 1 to 4 GB.
