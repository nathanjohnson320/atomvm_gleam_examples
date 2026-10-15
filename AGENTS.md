# AGENTS.md

Instructions for coding agents. Conventions live in [`.cursor/rules/`](.cursor/rules/). Read `gleam-conventions` and `gleam-atomvm-stdlib` before changing Gleam or Erlang FFI.

## Stack

Gleam → BEAM → AtomVM on the badge, flashed with [Orbital](https://github.com/nathanjohnson320/orbital). Shared image helpers in `atomgl_image` / `atomgl_image_dump`.

## Commands

```bash
# In the example crate you changed (e.g. 01_hello_world)
gleam format
gleam test

# Flash / monitor — see that example's README
gleam run -m orbital flash
```

## Secrets

Never commit real Wi-Fi or MQTT credentials. Keep placeholders in `config.gleam`. See `.cursor/rules/general-secrets.mdc`.

## Git

Verify with `gleam format` / `gleam test` in touched crates. Ask before merge or destructive git (`.cursor/rules/general-git-and-pr.mdc`, `general-workflow.mdc`).
