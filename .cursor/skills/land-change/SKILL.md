---
name: land-change
description: Lands multi-crate or large coordinated AtomVM Gleam changes in slices with verification, then commit/push/draft PR when asked to land. Use when changing a shared library plus consumers, or several example packages together. Do not use for a one-file fix.
---

# Land a change

Use this for shared-library + consumer work, or several coordinated example crates. Skip it for a one-file fix — `general-workflow` and `general-git-and-pr` are enough.

## Plan once, then execute

If product intent is unclear, use Plan Mode or ask **one** blocking question. Otherwise write a short plan in the first reply (crates and slice order), then implement **without waiting** for approval.

Do not reimplement Cursor built-ins (`/split-to-prs`, `/review`, Bugbot).

## Slices

Ship in this order when it applies. Verify each slice before starting the next.

1. **Shared library** — e.g. `atomgl_image` API and tests
2. **Host tooling** — e.g. `atomgl_image_dump` if assets/codegen change
3. **Example apps** — consumers under `NN_*` / `99_*`
4. **Tests** — scoped `gleam test` in each touched crate

Keep slices on the same branch. Do not pause between slices unless the workflow rule requires a human (merge, missing intent).

## Verify per slice

Use the app’s tools only. Do not tell the user to run them.

- `gleam format` on touched files
- `gleam test` in the crate you changed
- Apply `gleam-conventions` and `general-no-narrative-comments` before the next slice

## Finish

When the last slice is green: commit/push/draft PR per `general-git-and-pr` when the user asked to land the change. Do not merge. Ask before force-push or merge.
