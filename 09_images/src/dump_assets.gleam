/// Example wrapper around [`atomgl_image/dump`](../../atomgl_image).
///
/// ```sh
/// gleam run -m dump_assets
/// ```

import atomgl_image/dump
import gleam/io

pub fn main() -> Nil {
  case
    dump.run(
      dump.Config(
        source_png: "assets/src/demo.png",
        source_gif: "assets/src/demo.gif",
        decoded_dir: "assets/decoded",
        gleam_module_path: "src/assets.gleam",
        png_stem: "demo",
        gif_stem: "demo_gif",
        sprite_import: "atomgl_image/sprite",
        png_fn: "demo_png",
        gif_fn: "demo_gif_frames",
      ),
    )
  {
    Ok(Nil) ->
      io.println("Wrote assets/decoded and src/assets.gleam")
    Error(message) -> panic as { "dump_assets failed: " <> message }
  }
}
