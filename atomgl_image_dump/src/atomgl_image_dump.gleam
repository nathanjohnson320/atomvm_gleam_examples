/// Host CLI for dumping PNG/GIF assets into AtomGL rgba8888 dumps.
///
/// ```sh
/// gleam run -- \
///   --png ../09_images/assets/src/lucy.png \
///   --gif ../09_images/assets/src/lucy_spin.gif \
///   --decoded ../09_images/assets/decoded \
///   --module ../09_images/src/assets.gleam \
///   --png-stem lucy --gif-stem lucy_spin \
///   --png-fn lucy_png --gif-fn lucy_spin_frames
/// ```

import argv
import atomgl_image_dump/dump
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub fn main() -> Nil {
  case parse(argv.load().arguments) {
    Error(message) -> {
      io.println(usage())
      panic as message
    }
    Ok(config) ->
      case dump.run(config) {
        Ok(Nil) ->
          io.println(
            "Wrote "
            <> config.decoded_dir
            <> " and "
            <> config.gleam_module_path,
          )
        Error(message) -> panic as { "atomgl_image_dump failed: " <> message }
      }
  }
}

fn usage() -> String {
  string.concat([
    "Usage: gleam run -- \\\n",
    "  --png <file> --gif <file> \\\n",
    "  --decoded <dir> --module <assets.gleam> \\\n",
    "  --png-stem <stem> --gif-stem <stem> \\\n",
    "  --png-fn <name> --gif-fn <name> \\\n",
    "  [--sprite-import atomgl_image/sprite]\n",
  ])
}

fn parse(args: List(String)) -> Result(dump.Config, String) {
  use flags <- result.try(parse_flags(args, []))
  use png <- result.try(required(flags, "png"))
  use gif <- result.try(required(flags, "gif"))
  use decoded <- result.try(required(flags, "decoded"))
  use module <- result.try(required(flags, "module"))
  use png_stem <- result.try(required(flags, "png-stem"))
  use gif_stem <- result.try(required(flags, "gif-stem"))
  use png_fn <- result.try(required(flags, "png-fn"))
  use gif_fn <- result.try(required(flags, "gif-fn"))
  let sprite_import = case list.key_find(flags, "sprite-import") {
    Ok(value) -> value
    Error(Nil) -> "atomgl_image/sprite"
  }
  Ok(dump.Config(
    source_png: png,
    source_gif: gif,
    decoded_dir: decoded,
    gleam_module_path: module,
    png_stem:,
    gif_stem:,
    sprite_import:,
    png_fn:,
    gif_fn:,
  ))
}

fn parse_flags(
  args: List(String),
  acc: List(#(String, String)),
) -> Result(List(#(String, String)), String) {
  case args {
    [] -> Ok(list.reverse(acc))
    [flag, value, ..rest] ->
      case string.starts_with(flag, "--") {
        False -> Error("unexpected argument: " <> flag)
        True ->
          parse_flags(rest, [
            #(string.drop_start(from: flag, up_to: 2), value),
            ..acc
          ])
      }
    [flag] -> Error("missing value for " <> flag)
  }
}

fn required(
  flags: List(#(String, String)),
  name: String,
) -> Result(String, String) {
  case list.key_find(flags, name) {
    Ok(value) -> Ok(value)
    Error(Nil) -> Error("missing --" <> name)
  }
}
