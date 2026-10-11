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
  let assert Ok(bytes) = simplifile.read_bits(from: "assets/src/lucy.png")
  let assert Ok(decoded) = png.decode(bytes)
  assert assets.lucy_png() == decoded

  let assert Ok(gif_bytes) = simplifile.read_bits(from: "assets/src/lucy_spin.gif")
  let assert Ok(frames) = gif.decode(gif_bytes)
  assert assets.lucy_spin_frames() == frames
  assert list.length(frames) == 8
}

pub fn scene_loads_generated_assets_test() {
  let items =
    scene.render(320, 240, assets.lucy_png(), assets.lucy_spin_frames(), 0)
  let assert [_, _, _, _, Rect(0, 0, 320, 240, colour)] = items
  assert colour == 0x202020
}

pub fn decoded_rgba_files_exist_test() {
  let assert Ok(True) = simplifile.is_file("assets/decoded/lucy@32x32.rgba")
  let assert Ok(True) =
    simplifile.is_file("assets/decoded/lucy_spin_00@32x32.rgba")
  let assert Ok(True) =
    simplifile.is_file("assets/decoded/lucy_spin_07@32x32.rgba")

  let assert Ok(pixels) =
    simplifile.read_bits(from: "assets/decoded/lucy@32x32.rgba")
  assert bit_array.byte_size(pixels) == 32 * 32 * 4
  assert list.length(assets.lucy_spin_frames()) == 8
}
