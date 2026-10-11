# Exercise 9, in Gleam: show PNG/GIF art on AtomGL

Decode PNG and GIF **on the host** with the shared
[`atomgl_image`](../atomgl_image) package, embed the rgba8888 dumps for the
badge, then push AtomGL display lists through
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam).

The demo art is **Lucy**, Gleam’s starfish mascot — a static PNG plus an
8-frame spinning GIF generated from the official SVG.

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in
`.tool-versions`.

Assumes the AtomGL image from exercise 1 is already installed on the badge.

## Pipeline

```text
assets/src/lucy.svg
        │
        ▼  python3 scripts/make_lucy_assets.py
assets/src/lucy.png + lucy_spin.gif
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
| `assets/src/lucy.svg` | Official Lucy SVG (see attribution below) |
| `scripts/make_lucy_assets.py` | Rasterize SVG → stored-zlib PNG + spinning GIF |
| `dump_assets.gleam` | Example paths wired into `atomgl_image/dump` |
| `assets/decoded/` | Raw rgba8888 dumps (`name@WxH.rgba`) |
| `src/assets.gleam` | Generated sprites the badge loads |
| `scene.gleam` / `gallery.gleam` | Display-only AtomVM app |

The badge never inflates PNG or runs GIF LZW. It only loads pre-decoded
`Rgba8888` sprites from `atomgl_image/sprite`.

## Regenerate assets

After changing the SVG or the maker script:

```sh
python3 scripts/make_lucy_assets.py   # needs: pip install pillow cairosvg
gleam run -m dump_assets
```

Commit `assets/src/`, `assets/decoded/`, and `src/assets.gleam` so flash does
not require a dump step.

## Build, flash, and monitor

```sh
# shared package tests
cd ../atomgl_image && gleam test && cd ../09_images

gleam test
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

## Attribution

Lucy is part of [Gleam’s branding](https://gleam.run/branding/). The SVG used
here is from https://gleam.run/images/lucy/lucy.svg and is available under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).
