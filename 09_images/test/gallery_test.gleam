import assets
import gif
import gleam/bit_array
import gleam/list
import gleeunit
import image.{Rgba8888, Rect}
import png
import scene

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

pub fn png_decode_test() {
  let assert Ok(Rgba8888(width, height, pixels)) = png.decode(assets.demo_png())
  assert width == 8
  assert height == 8
  assert bit_array.byte_size(pixels) == 8 * 8 * 4

  // Top-left quadrant is yellow-ish (R=255,G=255,B=64)
  let assert Ok(<<r, g, b, a>>) = bit_array.slice(pixels, 0, 4)
  assert r == 255
  assert g == 255
  assert b == 64
  assert a == 255

  // Top-right pixel (x=4,y=0) is green-ish (R=0,G=255,B=64)
  let assert Ok(<<r2, g2, b2, a2>>) = bit_array.slice(pixels, 4 * 4, 4)
  assert r2 == 0
  assert g2 == 255
  assert b2 == 64
  assert a2 == 255
}

pub fn gif_decode_test() {
  let assert Ok(frames) = gif.decode(assets.demo_gif())
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

pub fn scene_contains_background_test() {
  let assert Ok(png_sprite) = png.decode(assets.demo_png())
  let assert Ok(frames) = gif.decode(assets.demo_gif())
  let items = scene.render(320, 240, png_sprite, frames, 0)
  let assert [_, _, _, _, Rect(0, 0, 320, 240, colour)] = items
  assert colour == 0x202020
}
