import assets
import atomgl_image/gif
import atomgl_image/item.{Rect}
import atomgl_image/png
import gleam/bit_array
import gleam/list
import gleeunit
import scene
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn generated_assets_match_decode_test() {
  let assert Ok(bytes) = simplifile.read_bits(from: "assets/src/demo.png")
  let assert Ok(decoded) = png.decode(bytes)
  assert assets.demo_png() == decoded

  let assert Ok(gif_bytes) = simplifile.read_bits(from: "assets/src/demo.gif")
  let assert Ok(frames) = gif.decode(gif_bytes)
  assert assets.demo_gif_frames() == frames
}

pub fn scene_loads_generated_assets_test() {
  let items =
    scene.render(320, 240, assets.demo_png(), assets.demo_gif_frames(), 0)
  let assert [_, _, _, _, Rect(0, 0, 320, 240, colour)] = items
  assert colour == 0x202020
}

pub fn decoded_rgba_files_exist_test() {
  let assert Ok(True) = simplifile.is_file("assets/decoded/demo@8x8.rgba")
  let assert Ok(True) =
    simplifile.is_file("assets/decoded/demo_gif_00@8x8.rgba")
  let assert Ok(True) =
    simplifile.is_file("assets/decoded/demo_gif_01@8x8.rgba")

  let assert Ok(pixels) =
    simplifile.read_bits(from: "assets/decoded/demo@8x8.rgba")
  assert bit_array.byte_size(pixels) == 8 * 8 * 4
  assert list.length(assets.demo_gif_frames()) == 2
}
