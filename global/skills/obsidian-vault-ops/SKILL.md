---
name: obsidian-vault-ops
description: Rules and recovery recipes for a git-tracked Obsidian vault that several machines write - what an agent may write into the vault without polluting the task dashboard, how the three writers and three directory names produce false negatives, why TCC and an iCloud firmlink hide a whole clone, the obsidian-git pull-failed loop, and the add/add conflict that strands a rebase in detached HEAD with markers that autosave keeps overwriting. Load before writing any file into the vault, running git in it, or diagnosing a sync failure.
when_to_use: Writing or moving a note in the vault, an obsidian-git "Pull failed" or "non-fast-forward" notice, a rebase stuck in detached HEAD, a .canvas or note that became invalid, verifying whether a machine holds a vault clone, or any question about which box made a vault commit.
---

# Obsidian vault operations

Vault root on m5pro is `~/Documents/posthog/` (not "Obsidian Vault"). Remote: private repo `jakesciotto/obsidian`. m5pro runs the only Obsidian instance; obsidian-git commits every 10 minutes as `vault backup: <ts>` with `syncMethod=rebase` and `pullBeforePush=true`.

## What an agent may write

- **Never write `- [ ]` or a dataview inline field.** `dashboard.md` ends with `TASK from !"archives" WHERE tier = null and checked = false`, so an unchecked untiered checkbox anywhere outside `archives/` becomes one of Jake's todos. `areas/work/backlog.md` additionally sweeps `FROM "areas/work"`.
- Agent-written notes belong in `resources/`, use status words not checkboxes, and carry no `tier`, `deadline`, `due` or `priority` fields.
- Customer notes are flat at `areas/work/customers/<slug>.md` with `org_id` in frontmatter, only for accounts in the book. A `## Log` row is a plain `-` bullet, never `- [ ]`. A finished task is marked in place with `[completion:: YYYY-MM-DD]`, never deleted.
- Folder notes are named after their folder (`projects/<name>/<name>.md`), not `README.md`. The archive path is basename-keyed, so a folder note archives to `archives/areas/work/work/<YYYY-MM>`; the doubled segment is the convention. A bare `[[projects]]` is ambiguous; keep folder-note links path-qualified.
- Timestamp properties were deleted on 2026-08-20. Never propose a bump-on-edit mechanism; git answers "when did this change".
- An external write to a note Obsidian has open gets clobbered by the next autosave. Write through the Obsidian MCP when the note may be open.
- A duplicate-task sweep cannot run on text similarity. Real duplicates are cross-surface (`inbox.md` vs the account file) in different words. Group open tasks BY ACCOUNT and read each group; the account file is the source of truth. Exclude `archives/`, where every old daily-note snapshot repeats a still-open task.

## Three writers, three directory names

Measured 2026-09-09 over 30 commits: m5pro 22, fedora 6, vinelab 2. fedora holds a HEADLESS clone at `/home/jake/github/obsidian` and pushes `recall: ...` commits. vinelab pushes the weekly dependency digest as `depwatch <depwatch@vinelab>`. m4max holds `~/Documents/Obsidian Vault`, which is an iCloud firmlink to `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Obsidian Vault/`.

**Verify a vault clone by its REMOTE, never by its directory name.** Searching m4max for a directory named `posthog` produced a false "no copy here".

**macOS TCC blocks an ssh session from reading anything under `~/Documents` on m4max**, and blocks Jake's own interactive terminal too: `git`, `cat`, `grep`, `ls` return `Operation not permitted`, `find` silently skips the tree, and `gls` reads exactly like an empty folder. `stat` still works: `stat -f '%l' <dir>` minus 2 is the subdirectory count. `~/Library/Application Support/obsidian/obsidian.json` is readable and lists every vault path, but the per-vault json holds only window geometry. Reading that clone needs Full Disk Access for the terminal app.

A git repo inside iCloud Drive is a standing hazard: iCloud evicts files to dataless placeholders and syncs partial writes, which corrupts `.git` independently of any Obsidian conflict.

Attribute a commit by timezone offset only to separate fedora (`-0600`) and vinelab (`+0000`) from the Macs. m5pro and m4max are both `-0400` with the same gmail author, so the offset cannot tell them apart.

## The obsidian-git pull-failed loop

"Pull failed (rebase): You have unstaged changes" plus "[rejected] (non-fast-forward)" is ONE self-sustaining loop, not a credential or signing fault. The plugin runs `pull --rebase` BEFORE it commits, so a single dirty tracked file aborts the pull; `main` stays behind; the push is rejected; the next cycle repeats. Fix is one commit, not a git repair: commit or stash the dirty file, rebase onto `origin/main`, and the plugin's next push fast-forwards. Read `git status --porcelain` first and expect exactly one modified note. Before the rebase, compare `git diff --name-only main...origin/main` against `origin/main...main`: two machines often produce the SAME blob through two commits, so an alarming overlap rebases clean. Do NOT rewrite history once `git merge-base --is-ancestor <sha> origin/main` succeeds; the other machine already holds it.

## The add/add conflict on a new file

A NEW file the plugin commits twice from one racing timer (a default name like `Untitled.canvas` makes this likely) lands as an add/add conflict and strands the rebase in detached HEAD: `git status -sb` reads `## HEAD (no branch)` with one `AA` path.

**A conflict-marker grep is useless here and reads as a false all-clear.** Obsidian autosaves over whatever git wrote, so the working file is marker-free on one cycle and marker-polluted on the next. Diagnose with `git status --porcelain` plus `git diff --diff-filter=U`.

Recovery:

1. Copy the live working file out first; it is usually newer than both conflict sides.
2. Read all three versions: `git ls-files -u <path>` gives the stage-2 and stage-3 blobs for `git cat-file -p`. Node ids let you diff a `.canvas` by content.
3. **Never `git add` the conflicted path without reading it.** Run `grep -c '^<<<<<<< ' <path>` and, for a `.canvas`, `python3 -c "import json;json.load(open(p))"`. Staging a polluted file on 2026-09-09 put four markers into a canvas, made it invalid JSON, and Obsidian then renamed the file so the corruption followed the new name.
4. `git add <path>` then `git rebase --continue`. Read `.git/rebase-merge/end`: the rebase can replay several commits and the same file conflicts again on each.
5. To repair a polluted file: strip each hunk to the `<<<<<<< HEAD` side (in a rebase, HEAD is the already-applied newer content), diff against the last clean blob (`git show <sha>:<path>`), confirm the node ids match, then write it back.

## Scheduling

launchd jobs that touch the vault die under TCC. The obsidian-git plugin is the working scheduler; a vault write from outside Obsidian goes through the MCP or a plain git commit from a headless clone.
