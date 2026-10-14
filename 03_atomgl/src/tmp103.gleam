import atomvm_gleam/i2c.{type Bus}
import gleam/float
import gleam/int
import gleam/result

const address = 0x70

const temperature_register = 0x00

/// TMP103A at 0x70. Register 0x00 is one signed byte, 1 LSB = 1 °C.
pub fn read(bus: Bus) -> Result(Float, String) {
  use celsius <- result.try(read_celsius(bus))
  Ok(fahrenheit(celsius))
}

/// TMP103A temperature in °C.
pub fn read_celsius(bus: Bus) -> Result(Int, String) {
  use data <- result.try(
    i2c.read_bytes(bus, address, temperature_register, 1)
    |> result.map_error(fn(error) {
      "TMP103 read failed: " <> i2c.error_to_string(error)
    }),
  )
  case data {
    <<celsius:signed-size(8)>> -> Ok(celsius)
    _ -> Error("TMP103 read failed: unexpected payload")
  }
}

/// Rounded to two decimal places.
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
