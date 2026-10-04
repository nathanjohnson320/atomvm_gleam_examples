import gleam/float
import gleam/int

/// Opaque handle for the badge I²C bus.
pub type Bus

@external(erlang, "tmp103_ffi", "open")
pub fn open() -> Bus

@external(erlang, "tmp103_ffi", "read_celsius")
fn read_celsius(bus: Bus) -> Int

/// TMP103A at 0x70. Register 0x00 is one signed byte, 1 LSB = 1 °C.
pub fn read(bus: Bus) -> Float {
  fahrenheit(read_celsius(bus))
}

/// Rounded to two decimal places, matching the Elixir driver.
pub fn fahrenheit(celsius: Int) -> Float {
  let raw = int.to_float(celsius) *. 1.8 +. 32.0
  let centi = float.round(raw *. 100.0)
  int.to_float(centi) /. 100.0
}

pub fn format(fahrenheit: Float) -> String {
  let centi = float.round(fahrenheit *. 100.0)
  let sign = case centi < 0 {
    True -> "-"
    False -> ""
  }
  let centi = int.absolute_value(centi)
  sign <> int.to_string(centi / 100) <> "." <> pad2(centi % 100)
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}
