import gleeunit
import tmp103

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn decode_celsius_test() {
  assert tmp103.decode_celsius(<<24>>) == Ok(24)
  assert tmp103.decode_celsius(<<255>>) == Ok(-1)
}

pub fn fahrenheit_test() {
  assert tmp103.fahrenheit(0) == 32.0
  assert tmp103.fahrenheit(24) == 75.2
}
