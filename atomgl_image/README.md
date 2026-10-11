# atomgl_image

Reusable Gleam helpers for AtomGL image assets:

1. Decode PNG / GIF bytes to `Rgba8888` sprites (host-side)
2. Build AtomGL display-list items for those sprites (badge-side)

For writing `.rgba` dumps and generating a Gleam assets module, use the
separate [`atomgl_image_dump`](../atomgl_image_dump) host tool.

## Modules

| Module | Role |
|--------|------|
| `atomgl_image/png` | 8-bit RGBA, non-interlaced PNG |
| `atomgl_image/gif` | GIF87a/89a frames |
| `atomgl_image/zlib_inflate` | Stored-block zlib for PNG IDAT |
| `atomgl_image/sprite` | `Rgba8888` type |
| `atomgl_image/item` | AtomGL `image` / `scaled_cropped_image` helpers |

## Use from an example app

```toml
# gleam.toml
atomgl_image = { path = "../atomgl_image" }
```

```gleam
import atomgl_image/item
import atomgl_image/sprite.{type Sprite}

pub fn draw(png: Sprite) {
  item.image(24, 40, png)
}
```

## Limits

PNG: colour type 6, 8-bit, non-interlaced, **stored** zlib blocks.  
GIF: palettes, transparency, disposal, interlacing.
