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
        source_png: "assets/src/lucy.png",
        source_gif: "assets/src/lucy_spin.gif",
        decoded_dir: "assets/decoded",
        gleam_module_path: "src/assets.gleam",
        png_stem: "lucy",
        gif_stem: "lucy_spin",
        sprite_import: "atomgl_image/sprite",
        png_fn: "lucy_png",
        gif_fn: "lucy_spin_frames",
      ),
    )
  {
    Ok(Nil) ->
      io.println("Wrote assets/decoded and src/assets.gleam")
    Error(message) -> panic as { "dump_assets failed: " <> message }
  }
}
