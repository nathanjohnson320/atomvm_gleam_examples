import assets
import gif
import gleam/bit_array
import gleam/list
import gleeunit
import image.{Rgba8888, Rect}
import png
import scene
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn wrap_frame_test() {
  assert image.wrap_frame(0, 3) == 0
  assert image.wrap_frame(3, 3) == 0
  assert image.wrap_frame(4, 3) == 1
  assert image.wrap_frame(-1, 3) == 2
  assert image.wrap_frame(5, 0) == 0
}

pub fn png_source_decodes_test() {
  let assert Ok(bytes) = simplifile.read_bits(from: "assets/src/demo.png")
  let assert Ok(Rgba8888(width, height, pixels)) = png.decode(bytes)
  assert width == 8
  assert height == 8
  assert bit_array.byte_size(pixels) == 8 * 8 * 4

  let assert Ok(<<r, g, b, a>>) = bit_array.slice(pixels, 0, 4)
  assert r == 255
  assert g == 255
  assert b == 64
  assert a == 255
}

pub fn gif_source_decodes_test() {
  let assert Ok(bytes) = simplifile.read_bits(from: "assets/src/demo.gif")
  let assert Ok(frames) = gif.decode(bytes)
  assert list.length(frames) == 2

  let assert [Rgba8888(w0, h0, frame0), Rgba8888(w1, h1, frame1)] = frames
  assert w0 == 8
  assert h0 == 8
  assert w1 == 8
  assert h1 == 8

  let assert Ok(<<r0, g0, b0, a0>>) = bit_array.slice(frame0, 0, 4)
  assert r0 == 255
  assert g0 == 0
  assert b0 == 0
  assert a0 == 255

  let assert Ok(<<r1, g1, b1, a1>>) = bit_array.slice(frame1, 0, 4)
  assert r1 == 0
  assert g1 == 0
  assert b1 == 255
  assert a1 == 255
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
  let assert Ok(True) =
    simplifile.is_file("assets/decoded/demo@8x8.rgba")
  let assert Ok(True) =
    simplifile.is_file("assets/decoded/demo_gif_00@8x8.rgba")
  let assert Ok(True) =
    simplifile.is_file("assets/decoded/demo_gif_01@8x8.rgba")

  let assert Ok(pixels) =
    simplifile.read_bits(from: "assets/decoded/demo@8x8.rgba")
  assert bit_array.byte_size(pixels) == 8 * 8 * 4
}
