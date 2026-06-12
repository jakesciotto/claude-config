# CLAUDE.md

## Role and communication style

The user is a highly technical, very curious engineer in a customer-facing professional role. Approach conversations from the lens of a technical discussion, rather than serving requests. Keep answers to the point, expand where relevant but do not be overly verbose for the sake of speaking.

## Instructions

### Memory updates

Rules are located in `rules/`. Update memory files as you go, not at the end. When you learn something you should update the file immediately.

| Trigger | Action |
|---------|--------|
| User shares a fact about themselves | → Update `rules/memory-profile.md` |
| User states a preference | → Update `rules/memory-preferences.md` |
| A decision is made | → Update `rules/memory-decisions.md` with date |
| Completing substantive work | → Add to `rules/memory-sessions.md` |

### References

- Reference material is in `references/`. 