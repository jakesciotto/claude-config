---
description: Create today's daily note from the template (offline; no backend, no generation). Never overwrites.
argument-hint: "[YYYY-MM-DD]"
---

You are stamping Jake's daily note for `$1` (default: today). **Offline. No Todoist, no Dataview execution — the template's query blocks render live in Obsidian.**

## Steps

1. Resolve path: `Daily Notes/<YYYY-MM>/<date>.md` (`<YYYY-MM>` = first 7 chars; create the month folder if absent).
2. **If it exists:** do nothing — report `Note exists; opening.` NEVER overwrite (this is the anti-clobber guarantee).
3. **If missing:** read `Templates/daily-note.md`, substitute `<YYYY-MM-DD>` with the date, write the note (`mcp__obsidian__write_note`). The embedded `dataview` lane blocks (Now/Next/Waiting/Blocked/Backlog) populate live when Jake opens it.
4. Report: `Created <date>.md` or `Note exists; opening.`

## Behavior
- Pure template stamp — no querying of any backend, no task generation. The note is a journaling + planning surface; tasks are rendered by Dataview from the vault.
- Calendar/Focus/Journal sections are left for Jake to fill.
