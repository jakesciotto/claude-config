# WORKFLOW.md

### 1. Plan Node

- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- Before reading the entire codebase, read through the `.claude` directory FIRST instead of
  burning up tens of thousands of tokens looking at every file in the directory
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs in `.claude/plans` upfront to reduce ambiguity

### 2. Subagent Strategy

- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop

- After ANY correction from the user: update `.claude/project/MEMORY.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review memory at session start for relevant project

### 4. Verification Before Done

- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a principal engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance

- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing

- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `.claude/project/TODO.md` with checkable items
2. **Verify Plan**: Check in before starting implementation; do not make any `git` commits yourself
3. **Track Progress**: Mark items complete as you go in `.claude/project/TODO.md`
4. **Explain Changes**: Output succinct high-level summary at each step
5. **Document Results**: Add review section to `.claude/project/TODO.md`a
6. **Capture Lessons**: Update `.claude/project/MEMORY.md` after corrections
7. **Track Changes**:
   7a. Update `.claude/project/CHANGELOG.md` after work is finished and confirmed finished by the user
   7b. If architecture changes were made, update `.claude/project/ARCHITECTURE.md`
   7c. If `.claude/project/TODO.md` starts to exceed 500 lines, move the finished items to `.claude/plans/DONE.md`
