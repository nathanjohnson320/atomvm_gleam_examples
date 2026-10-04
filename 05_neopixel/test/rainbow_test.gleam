import gleeunit
import rainbow
import sk6812

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn hsv_red_test() {
  assert rainbow.hsv_to_rgb(0, 255, 255) == #(255, 0, 0)
}

pub fn hsv_green_test() {
  assert rainbow.hsv_to_rgb(120, 255, 255) == #(0, 255, 0)
}

pub fn encode_zero_byte_test() {
  // Every LED bit is 0, so every SPI nibble-pair is 0x88.
  assert sk6812.encode_byte(0) == <<0x88, 0x88, 0x88, 0x88>>
}

pub fn encode_pixel_green_first_test() {
  let encoded = sk6812.encode_pixel(#(1, 0, 0))
  let assert <<green:bytes-size(4), red:bytes-size(4), blue:bytes-size(4)>> = encoded
  assert green == sk6812.encode_byte(0)
  assert red == sk6812.encode_byte(1)
  assert blue == sk6812.encode_byte(0)
}
