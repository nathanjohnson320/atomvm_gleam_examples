# Cursor harness

AtomVM Gleam examples — rules, hooks, and skills for this repo. Prefixes: `gleam-`, `general-`.

Cursor layering: **rules** (static policy), **skills** (on-demand workflows), **hooks** (mechanical format/gates).

| Path | Applies | Notes |
| --- | --- | --- |
| `rules/general-agent-behavior.mdc` | always | Stop after the ask; Gleam/AtomVM only |
| `rules/general-workflow.mdc` | always | Verify with gleam; pause for merge or destructive git |
| `rules/general-secrets.mdc` | always | No Wi-Fi/MQTT passwords or credentials in git |
| `rules/general-git-and-pr.mdc` | always | Commit/PR when landing; ask before merge |
| `rules/general-no-narrative-comments.mdc` | always | No restating-the-code comments |
| `rules/gleam-conventions.mdc` | `*.gleam` / `*.erl` | Packages, Orbital, `start`, FFI |
| `skills/land-change/SKILL.md` | on demand | Multi-crate landings: slice, verify, then PR |
| `hooks.json` | project | Format after edit; deny destructive shell and secret files |
| `hooks/` | project | Scripts referenced by `hooks.json` |
| `templates/AGENTS.md` | reference | App-root `AGENTS.md` for agents |
| `docs/` | — | App-specific runbooks only |
