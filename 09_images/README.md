# Exercise 9, in Gleam: show PNG/GIF art on AtomGL

Decode PNG and GIF **on the host** with the shared
[`atomgl_image`](../atomgl_image) package, embed the rgba8888 dumps for the
badge, then push AtomGL display lists through
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam).

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in
`.tool-versions`.

Assumes the AtomGL image from exercise 1 is already installed on the badge.

## Pipeline

```text
assets/src/*.png|*.gif
        │
        ▼  gleam run -m dump_assets   (thin wrapper → atomgl_image/dump)
assets/decoded/*@WxH.rgba   +   src/assets.gleam
        │
        ▼  gallery.start on AtomVM
AtomGL image / scaled_cropped_image
```

| Path | Role |
|------|------|
| [`../atomgl_image`](../atomgl_image) | Reusable PNG/GIF decode + dump + AtomGL helpers |
| `assets/src/` | Source PNG/GIF for this example |
| `dump_assets.gleam` | Example paths wired into `atomgl_image/dump` |
| `assets/decoded/` | Raw rgba8888 dumps (`name@WxH.rgba`) |
| `src/assets.gleam` | Generated sprites the badge loads |
| `scene.gleam` / `gallery.gleam` | Display-only AtomVM app |

The badge never inflates PNG or runs GIF LZW. It only loads pre-decoded
`Rgba8888` sprites from `atomgl_image/sprite`.

## Regenerate assets

After changing anything under `assets/src/`:

```sh
gleam run -m dump_assets
```

Commit `assets/decoded/` and `src/assets.gleam` with the sources so flash does
not require a dump step.

## Build, flash, and monitor

```sh
# shared package tests
cd ../atomgl_image && gleam test && cd ../09_images

gleam test
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

## Replacing the demo art

Drop a small PNG or GIF into `assets/src/` (keep sizes tiny — the demos are
8×8), adjust the paths in `dump_assets.gleam` if you rename them, run the dump,
then flash.
