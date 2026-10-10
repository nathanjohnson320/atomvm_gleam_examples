# Exercise 9, in Gleam: show PNG/GIF art on AtomGL

Decode PNG and GIF **on the host** into raw rgba8888 files, embed those for the
badge, then push AtomGL display lists through
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam).

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in
`.tool-versions`.

Assumes the AtomGL image from exercise 1 is already installed on the badge.

## Pipeline

```text
assets/src/*.png|*.gif
        │
        ▼  gleam run -m dump_assets
assets/decoded/*@WxH.rgba   +   src/assets.gleam
        │
        ▼  gallery.start on AtomVM
AtomGL image / scaled_cropped_image
```

| Path | Role |
|------|------|
| `assets/src/` | Source PNG/GIF (edit these) |
| `dump_assets.gleam` | Host decoder → `.rgba` files + generated module |
| `png.gleam` / `gif.gleam` / `zlib_inflate.gleam` | Used by the dump tool (and tests) |
| `assets/decoded/` | Raw rgba8888 dumps (`name@WxH.rgba`) |
| `src/assets.gleam` | Generated sprites the badge loads |
| `image.gleam` / `scene.gleam` / `gallery.gleam` | AtomGL display only |

The badge never inflates PNG or runs GIF LZW. It only loads pre-decoded
`Rgba8888` sprites.

PNG support in the dump tool is narrow (8-bit RGBA, non-interlaced, stored zlib
blocks). GIF handles palettes, transparency, disposal, and interlacing.

## Regenerate assets

After changing anything under `assets/src/`:

```sh
gleam run -m dump_assets
```

Commit `assets/decoded/` and `src/assets.gleam` with the sources so flash does
not require a dump step.

## Build, flash, and monitor

```sh
gleam test
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

## Replacing the demo art

Drop a small PNG or GIF into `assets/src/` (keep sizes tiny — the demos are
8×8), point `dump_assets` at the new filenames if you rename them, run the dump,
then flash.
