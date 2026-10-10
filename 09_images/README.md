# Exercise 9, in Gleam: decode PNG/GIF and show them on AtomGL

A small gallery that decodes embedded PNG and GIF bytes in **pure Gleam**, then
pushes AtomGL display lists through
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam).

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in
`.tool-versions`.

Assumes the AtomGL image from exercise 1 is already installed on the badge.

## The application

`gallery.start` opens SPI and the ST7789 the same way as `03_atomgl`, decodes
`assets.demo_png` and `assets.demo_gif` once, then loops GIF frames.

| Module | Role |
|--------|------|
| `png.gleam` | 8-bit RGBA, non-interlaced PNG → `Rgba8888` |
| `zlib_inflate.gleam` | Stored-block zlib inflate for PNG IDAT |
| `gif.gleam` | GIF87a/89a → composed `Rgba8888` frames |
| `image.gleam` | AtomGL `image` / `scaled_cropped_image` helpers |
| `scene.gleam` | Display list |
| `assets.gleam` | Embedded demo binaries |

PNG support is intentionally narrow (colour type 6, 8-bit, no Adam7). The
inflate path accepts **stored** deflate blocks only — enough for the embedded
demo and for hand-built fixtures. GIF handles local/global palettes,
transparency, disposal, and interlacing.

## Build, flash, and monitor

```sh
gleam test
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

## Replacing the demo art

Paste another small PNG/GIF as a `BitArray` literal in `src/assets.gleam`. Keep
images tiny (the demos are 8×8) so decode and flash fit AtomVM RAM and the
`main.avm` partition. Prefer PNGs whose IDAT uses stored zlib blocks, or extend
`zlib_inflate.gleam` if you need Huffman-compressed streams.
