import atomgl_image/gif
import atomgl_image/item
import atomgl_image/png
import atomgl_image/sprite.{Rgba8888}
import gleam/bit_array
import gleam/list
import gleeunit
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn wrap_frame_test() {
  assert item.wrap_frame(0, 3) == 0
  assert item.wrap_frame(3, 3) == 0
  assert item.wrap_frame(4, 3) == 1
  assert item.wrap_frame(-1, 3) == 2
  assert item.wrap_frame(5, 0) == 0
}

pub fn png_fixture_decodes_test() {
  let assert Ok(bytes) = simplifile.read_bits(from: "test/fixtures/demo.png")
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

pub fn gif_fixture_decodes_test() {
  let assert Ok(bytes) = simplifile.read_bits(from: "test/fixtures/demo.gif")
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
