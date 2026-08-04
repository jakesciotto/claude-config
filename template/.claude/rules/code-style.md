---
paths:
  - "**/*.{ts,tsx,js,jsx}"
  - "**/*.py"
  - "**/*.{sql,sh}"
---

# code-style.md

Loaded only when a matching source file is read, so it costs nothing during planning or docs work. Narrow the globs above to the languages this project actually uses, and delete the ones it does not.

## Style

1. Minimal comments. Comment only where the code genuinely cannot speak for itself.
2. Under no circumstance should an emoji appear in a commit message, comment, or planning document.
3. Prefer explicit over compact. No nested ternaries; use `if`/`else` chains or a switch for multiple conditions.
4. Unless given explicit approval, do not create extra files in temporary directories for scripting or testing.
