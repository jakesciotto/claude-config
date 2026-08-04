# repository.md

Repository-level rules. No `paths:` frontmatter: these apply to every session in this project, not to a file type.

## Rules

1. Do not ever publish passwords, API keys, or tokens to git/npm/docker.
2. Under no circumstance should a commit be made without explicit approval OR verification that no secrets are included.
3. Never commit `.env` to git, always verify `.env` is in `.gitignore`.
4. Integration branch is `staging`, not `main` - always branch from `staging` and target `staging` in PRs. Do not target `main` directly.
5. You should not burn tokens reviewing the entire repo when asked about planning or implementation. Review project files in `.claude/project` first.
6. Use [Semantic Versioning](https://semver.org/) in release tags. Given `MAJOR.MINOR.PATCH`, increment MAJOR for incompatible API changes, MINOR for backward-compatible functionality, PATCH for backward-compatible bug fixes.

Rules 1-3 are requests, not enforcement. If a secret must never leave this repo, back them with a `PreToolUse` hook that blocks the write, or a `permissions.deny` rule. A written instruction is not a guarantee.
