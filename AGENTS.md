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

## Cloud Agent

The environment install puts Gleam 1.19.2, Erlang/OTP 27.3.4.12, and rebar3 3.27.3 on `/usr/local/bin`.

`/usr/local/bin/git` wraps `/usr/bin/git`. On `git checkout` of a 40-character commit that is missing locally, it fetches that commit from `origin` first. Gleam checks out pinned git SHAs after fetching only branch tips, and some `atomvm_gleam` pins are still on GitHub but not reachable from the default branch.

Host checks: `gleam test` in a package, and `gleam run -m orbital -- build` to pack an `.avm`. `atomgl_image_dump` has no `*_test.gleam` module; exercise it with `gleam run`. Flashing still needs a badge.
