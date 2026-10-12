# Exercise 9, in Gleam: show PNG/GIF art on AtomGL

Decode PNG and GIF **on the host** with
[`atomgl_image_dump`](../atomgl_image_dump), embed the rgba8888 dumps for the
badge, then push AtomGL display lists through
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam) using
[`atomgl_image`](../atomgl_image) runtime helpers.

The demo art is **Lucy**, Gleam’s starfish mascot — a static PNG plus an
8-frame spinning GIF derived from the official SVG.

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in
`.tool-versions`.

Assumes the AtomGL image from exercise 1 is already installed on the badge.

## Pipeline

```text
assets/src/lucy.png + lucy_spin.gif
        │
        ▼  atomgl_image_dump (separate host package)
assets/decoded/*@WxH.rgba   +   src/assets.gleam
        │
        ▼  gallery.start on AtomVM
AtomGL image / scaled_cropped_image
```

| Path | Role |
|------|------|
| [`../atomgl_image`](../atomgl_image) | Runtime `sprite` / `item` (+ codecs for tests) |
| [`../atomgl_image_dump`](../atomgl_image_dump) | Host dump CLI — not part of this example app |
| `assets/src/` | Source PNG/GIF (plus `lucy.svg` for provenance) |
| `assets/decoded/` | Raw rgba8888 dumps (`name@WxH.rgba`) |
| `src/assets.gleam` | Generated sprites the badge loads |
| `scene.gleam` / `gallery.gleam` | Display-only AtomVM app |

The badge never inflates PNG or runs GIF LZW. It only loads pre-decoded
`Rgba8888` sprites from `atomgl_image/sprite`.

## Regenerate assets

After changing anything under `assets/src/`:

```sh
cd ../atomgl_image_dump
gleam run -- \
  --png ../09_images/assets/src/lucy.png \
  --gif ../09_images/assets/src/lucy_spin.gif \
  --decoded ../09_images/assets/decoded \
  --module ../09_images/src/assets.gleam \
  --png-stem lucy --gif-stem lucy_spin \
  --png-fn lucy_png --gif-fn lucy_spin_frames
```

Commit `assets/decoded/` and `src/assets.gleam` with the sources so flash does
not require a dump step.

## Build, flash, and monitor

```sh
cd ../atomgl_image && gleam test && cd ../09_images

gleam test
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

## Attribution

Lucy is part of [Gleam’s branding](https://gleam.run/branding/). The SVG used
here is from https://gleam.run/images/lucy/lucy.svg and is available under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
