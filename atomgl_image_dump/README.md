# atomgl_image_dump

Host-side Gleam tool that turns PNG/GIF sources into AtomGL-ready assets:

1. Decode with [`atomgl_image`](../atomgl_image)
2. Write `name@WxH.rgba` dumps
3. Generate a Gleam module of pre-decoded `Rgba8888` sprites

This package is **not** flashed to the badge. Example apps only depend on
`atomgl_image` for runtime `sprite` / `item` helpers.

## Usage

```sh
cd atomgl_image_dump
gleam run -- \
  --png ../09_images/assets/src/lucy.png \
  --gif ../09_images/assets/src/lucy_spin.gif \
  --decoded ../09_images/assets/decoded \
  --module ../09_images/src/assets.gleam \
  --png-stem lucy --gif-stem lucy_spin \
  --png-fn lucy_png --gif-fn lucy_spin_frames
```

Optional: `--sprite-import atomgl_image/sprite` (default).

## Library

`atomgl_image_dump/dump` exposes `Config` and `run/1` if you want to call the
dumper from another Gleam host program instead of the CLI.
