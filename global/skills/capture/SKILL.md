---
name: capture
description: Pull Todoist Inbox into Obsidian Inbox.md (one-way), then clear Todoist. Todoist is a capture funnel only.
argument-hint: ""
disable-model-invocation: true
---

You are running capture for Jake. **One-way: Todoist Inbox → Obsidian. Todoist never stores tasks long-term.**

## Context
- Vault: `/Users/jakesciotto/Documents/posthog` (`mcp__obsidian__*`)
- Todoist: `mcp__todoist__*` — **Inbox only**
- Online operation (needs Todoist API). The captured tasks then live offline in the vault.

## Steps

1. **Read Todoist Inbox:** `mcp__todoist__find-tasks({"projectId":"inbox","limit":100})`. Capture `id`, `content`, `due`, `deadline`, `labels`.
2. **Append to `inbox.md`** under `## Untriaged`, one line per task, in the Dataview inline-field format. Carry over any metadata Todoist had:
   ```
   - [ ] <content> [due:: YYYY-MM-DD] [deadline:: YYYY-MM-DD]
   ```
   Omit fields that don't apply. **Do not** add a `[tier::]` (Jake triages that). No Todoist id comment.

   **Append under `## Untriaged`.** That heading now holds plain markdown task lines only.
   Dashboard 3.0's Untriaged panel renders them vault-wide with the triage controls, so
   `inbox.md` carries no `datacorejsx` block any more.
3. **Clear from Todoist:** `mcp__todoist__complete-tasks` for each captured id (removes it from Inbox; recoverable in Todoist's completed log). This keeps Todoist a pure funnel.
4. **Report:** `Captured N item(s) to Inbox.md; cleared from Todoist.` If Inbox empty: `Todoist Inbox empty — nothing to capture.`
5. **Log** (`${CLAUDE_SKILL_DIR}/references/supabase-logging.md`): `command='capture'`, `scope='inbox'`, `status='applied'`, `applied_counts={captured:N}`. Non-blocking.

## Behavior
- Touches **only** the Todoist Inbox. Never reads/writes other Todoist projects.
- If Todoist MCP is unavailable: report and stop (capture is the one online step; try again later).
- Triage is Jake's job. He sets `[tier::]` from the block's controls, then moves lines into PARA pages.
