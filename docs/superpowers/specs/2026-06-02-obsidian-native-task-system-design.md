# Obsidian-Native Task System — Design

**Date:** 2026-06-02
**Status:** approved, implementing
**Supersedes:** the bidirectional Obsidian↔Todoist `/sync` + `/daily-plan` generator, and the "Obsidian is the brain for tasks (mirrored to Todoist)" model.

## Problem

Tasks were tracked in **two** editable stores — Obsidian markdown + Todoist — so they drifted. A full session of reconciliation + two abandoned architectures (bidirectional sync hardening; the `obsidian-todoist-plugin` live-query model) proved the real constraints:

- **Offline is mandatory.** The plugin model (live Todoist API query blocks) was rejected because tasks couldn't be read/edited offline.
- **Single source of truth is mandatory.** Any second editable copy reintroduces drift.
- **No reminder layer needed.** Deadlines are *review metadata* the user scans when planning, not push notifications (user confirmed).
- **Capture matters but Obsidian-mobile-acceptable.** On-the-go capture happens, but a good Obsidian path (or a one-way Todoist funnel) suffices.

## Decision

**Obsidian markdown is the single source of truth for tasks. Everything runs offline. Todoist is demoted to a capture-only inbox funnel. Supabase is a write-only archive.**

## Architecture

### 1. Data model
Tasks are markdown checkboxes living in their **PARA home page** (project/area file) — task lives next to its context. Metadata = **Dataview inline fields** (single consistent syntax):

```
- [ ] Schedule colonoscopy [due:: 2026-06-30] [deadline:: 2026-06-30] [tier:: next]
```

- `[due:: YYYY-MM-DD]` — movable date. `[deadline:: YYYY-MM-DD]` — immovable constraint. **Both kept, distinct** (Dataview supports it; Tasks-plugin emoji could not — a reason Dataview was chosen).
- `[tier:: now|next|waiting|blocked|someday|backlog]` — exactly one lane per task. Inline field (not a `#tag`) so it's a single-valued property, queryable, and doesn't pollute the global tag namespace. **A checkbox is a task IFF it has `[tier::]`** — this is the rule that keeps stray non-task checkboxes (study guides, HUD checklists, scratch notes) out of the queries. Untriaged = `[tier:: backlog]`.
- Completion: `[x]` (Dataview `completed`); optional `[completion:: YYYY-MM-DD]`.
- Other cross-cutting labels (follow-up, energy) → additional inline fields or tags, ad hoc.

### 2. Views (offline, Dataview)
Dataview indexes the vault **locally** — no network. `TASK` query blocks live in `Dashboard.md` and the daily note:

| Lane | Query (`TASK WHERE !completed AND …`) |
|---|---|
| Now | `(due <= date(today) OR deadline < date(today) OR tier = "now")` |
| Next | `tier = "next"` |
| Waiting | `tier = "waiting"` |
| Blocked | `tier = "blocked"` |
| Someday | `tier = "someday"` |
| Backlog | `!due AND !tier` (future-deadline, no-tier tasks fold in here) |

### 3. Capture funnel — `/capture` (one-way, online)
Capture stays in Todoist (Wispr / email / mobile quick-add) → **Inbox only**. `/capture` runs online: read Todoist Inbox → append each item to `Inbox.md` → complete/clear it from Todoist. **Todoist never stores tasks long-term** — pure funnel, nothing to drift. User then triages `Inbox.md`: move each line into its PARA page, add `[tier:: …]`.

### 4. Archive — `/archive` (one-way, online)
Sweep completed (`[x]`) tasks across the vault → upsert to Supabase `public.archived_tasks` → prune the lines from pages (git holds history). Write-only Obsidian→Supabase; cannot drift. Runs on a cadence (or folded into `/end-of-day`).

### 5. Daily surface — `/daily`
A template stamps a dated daily note containing Calendar, Focus, journaling space, and the **embedded lane query blocks** (same as Dashboard). No backend, no generation logic — just a template; the queries render live. Preserves the planning ritual without the regeneration that historically clobbered edits.

### 6. Styling
CSS snippet `tasks-dataview.css`: strike-through + dim completed tasks; tame Dataview inline-field chips. Reading view recommended for the dashboard (Live Preview shows raw `[k:: v]`).

## Components (each independently understandable)
1. **Data convention** — Dataview inline-field format (`docs` + `Resources/conventions/task-system.md`).
2. **`Dashboard.md`** — live lane queries.
3. **Daily-note template** + `/daily` — dated surface embedding the queries.
4. **`/capture`** — Todoist Inbox → `Inbox.md`, clear Todoist.
5. **`/archive`** — completed vault tasks → Supabase, prune.
6. **CSS snippet** — strikethrough + chip styling.
7. **Migration** — one-time reformat of existing parenthetical task lines → inline fields; strip `<!-- todoist:id -->`.

## Retired / adapted
- **Retire:** `/sync` (bidirectional), `/daily-plan` (generator).
- **Adapt:** `/end-of-day`, `/weekly-review` → read the vault (Dataview), not Todoist.
- **Keep:** Supabase `archived_tasks` + `command_runs` logging.

## Non-goals (YAGNI)
- No push reminders/notifications (review-based).
- No bidirectional sync, no task-id tracking, no homing.
- No frozen daily snapshots (git is the history).

## Offline guarantee
Daily driving — Dashboard, daily note, checking off, editing tasks — is 100% local. Only `/capture` and `/archive` touch the network, and both are deliberate batch operations, not part of normal use.
