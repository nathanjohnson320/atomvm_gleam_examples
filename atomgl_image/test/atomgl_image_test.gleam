import atomgl_image/gif
import atomgl_image/item
import atomgl_image/jpeg
import atomgl_image/png
import atomgl_image/sprite.{Rgba8888}
import gleam/bit_array
import gleam/int
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

fn assert_close(actual: Int, expected: Int) -> Nil {
  assert int.absolute_value(actual - expected) <= 30
}

fn pixel_at(
  pixels: BitArray,
  width: Int,
  x: Int,
  y: Int,
) -> #(Int, Int, Int, Int) {
  let assert Ok(<<r, g, b, a>>) =
    bit_array.slice(pixels, { y * width + x } * 4, 4)
  #(r, g, b, a)
}

pub fn jpeg_fixture_decodes_test() {
  let assert Ok(bytes) = simplifile.read_bits(from: "test/fixtures/thumb.jpg")
  let assert Ok(Rgba8888(width, height, pixels)) = jpeg.decode(bytes)
  assert width == 160
  assert height == 120
  assert bit_array.byte_size(pixels) == 160 * 120 * 4

  let #(r, g, b, a) = pixel_at(pixels, width, 2, 2)
  assert_close(r, 39)
  assert_close(g, 120)
  assert_close(b, 199)
  assert a == 255

  let #(r, g, b, a) = pixel_at(pixels, width, 80, 60)
  assert_close(r, 132)
  assert_close(g, 121)
  assert_close(b, 151)
  assert a == 255
}

pub fn jpeg_decode_scaled_test() {
  let assert Ok(bytes) = simplifile.read_bits(from: "test/fixtures/thumb.jpg")
  let assert Ok(Rgba8888(width, height, pixels)) =
    jpeg.decode_scaled(bytes, 80, 60)
  assert width <= 80
  assert height <= 60
  assert width == 80
  assert height == 60
  assert bit_array.byte_size(pixels) == width * height * 4

  let assert Ok(Rgba8888(width, height, _)) =
    jpeg.decode_scaled(bytes, 500, 500)
  assert width == 160
  assert height == 120

  let assert Ok(Rgba8888(width, height, _)) = jpeg.decode_scaled(bytes, 50, 100)
  assert width == 50
  assert height == 37
}

pub fn jpeg_decode_preview_test() {
  let assert Ok(bytes) = simplifile.read_bits(from: "test/fixtures/thumb.jpg")
  let assert Ok(Rgba8888(width, height, pixels)) =
    jpeg.decode_preview(bytes, 80, 60)
  assert width <= 80
  assert height <= 60
  assert width > 0
  assert height > 0
  assert bit_array.byte_size(pixels) == width * height * 4

  let assert Ok(<<_, _, _, a>>) = bit_array.slice(pixels, 0, 4)
  assert a == 255
}

pub fn jpeg_rejects_non_jpeg_test() {
  assert jpeg.decode(<<1, 2, 3>>) == Error(jpeg.NotJpeg)
  assert jpeg.decode(<<0xFF, 0xD8, 0xFF>>) == Error(jpeg.Truncated)
}
