# atomgl_image

Reusable Gleam helpers for AtomGL image assets:

1. Decode PNG / GIF bytes to `Rgba8888` sprites
2. Dump those sprites to `.rgba` files on the host
3. Generate a Gleam module the badge can load without decoding on-device

## Modules

| Module | Role |
|--------|------|
| `atomgl_image/png` | 8-bit RGBA, non-interlaced PNG |
| `atomgl_image/gif` | GIF87a/89a frames |
| `atomgl_image/zlib_inflate` | Stored-block zlib for PNG IDAT |
| `atomgl_image/dump` | Host `.rgba` dump + Gleam codegen |
| `atomgl_image/sprite` | `Rgba8888` type |
| `atomgl_image/item` | AtomGL `image` / `scaled_cropped_image` helpers |

## Use from an example app

```toml
# gleam.toml
atomgl_image = { path = "../atomgl_image" }
```

```gleam
import atomgl_image/dump

pub fn main() {
  let assert Ok(Nil) =
    dump.run(dump.Config(
      source_png: "assets/src/demo.png",
      source_gif: "assets/src/demo.gif",
      decoded_dir: "assets/decoded",
      gleam_module_path: "src/assets.gleam",
      png_stem: "demo",
      gif_stem: "demo_gif",
      sprite_import: "atomgl_image/sprite",
      png_fn: "demo_png",
      gif_fn: "demo_gif_frames",
    ))
}
```

## Limits

PNG: colour type 6, 8-bit, non-interlaced, **stored** zlib blocks.  
GIF: palettes, transparency, disposal, interlacing.
