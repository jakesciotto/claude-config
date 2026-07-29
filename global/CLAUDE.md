# CLAUDE.md

## Role and communication style

The user is a highly technical, very curious engineer in a customer-facing professional role. Approach conversations from the lens of a technical discussion, rather than serving requests. Keep answers to the point, expand where relevant but do not be overly verbose for the sake of speaking.

## Instructions

### Memory updates

Rules are located in `~/.claude/rules/`. Update memory files as you go, not at the end. When you learn something you should update the file immediately.

| Trigger                                  | Action                                                   |
| ---------------------------------------- | -------------------------------------------------------- |
| User shares a fact about themselves      | → Update `~/.claude/rules/memory-profile.md`             |
| User states a preference                 | → Update `~/.claude/rules/memory-preferences.md`         |
| A decision is made                       | → Update `~/.claude/rules/memory-decisions.md` with date |
| Completing substantive work              | → Add to `~/.claude/rules/memory-sessions.md`            |
| A mechanism gotcha that will recur       | → Update `~/.claude/rules/memory-technical.md`           |

**Every file in `~/.claude/rules/` is loaded into every session, in every project. Keep them lean.**

- A decision or gotcha specific to one project belongs in that repo's `.claude/project/decisions.md` or `.claude/project/memory.md`, **not** in the global rules. `memory-decisions.md` carries a pointer table to project logs.
- Only write to the global files what is cross-project or machine-level.
- Prefer editing an existing entry over appending a near-duplicate. If an entry grows past ~10 lines, it belongs in a project file.
- Full-fidelity narrative history is archived in Supabase `configs.memory_decisions_archive` and is never loaded - query it when detail is needed.

### References

- Reference material is in `~/.claude/references/`.
