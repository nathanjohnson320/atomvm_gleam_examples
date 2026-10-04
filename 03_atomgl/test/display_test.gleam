import gleam/option
import gleeunit
import temperature_scene.{Rect, Text}
import tmp103

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn freezing_point_test() {
  assert tmp103.fahrenheit(0) == 32.0
  assert tmp103.format(32.0) == "32.00"
}

pub fn room_temperature_test() {
  assert tmp103.fahrenheit(25) == 77.0
}

pub fn below_zero_test() {
  assert tmp103.fahrenheit(-40) == -40.0
  assert tmp103.format(-40.0) == "-40.00"
}

pub fn cold_mercury_test() {
  let assert [_, _, _, _, _, Rect(_, _, _, height, colour), ..] =
    temperature_scene.render(320, 240, option.Some(-15.0))

  assert height == 0
  assert colour == 0x0000ff
}

pub fn hot_mercury_test() {
  let assert [_, _, _, _, _, Rect(x, y, width, height, colour), ..] =
    temperature_scene.render(320, 240, option.Some(120.0))

  assert x == 240
  assert y == 24
  assert width == 20
  assert height == 160
  assert colour == 0xff0000
}

pub fn blank_reading_test() {
  let assert [Text(_, _, _, _, _, text), ..] =
    temperature_scene.render(320, 240, option.None)

  assert text == <<"--":utf8>>
}
