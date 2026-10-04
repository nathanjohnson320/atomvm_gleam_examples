import atomvm_gleam/i2c.{type Bus}
import gleam/int
import gleam/result

const address = 0x70

const temperature_register = 0x00

/// TMP103A temperature in °C. Register 0x00 is one signed byte, 1 LSB = 1 °C.
pub fn read_celsius(bus: Bus) -> Result(Int, String) {
  use data <- result.try(
    i2c.read_bytes(bus, address, temperature_register, 1)
    |> result.map_error(fn(error) {
      "TMP103 read failed: " <> i2c.error_to_string(error)
    }),
  )
  decode_celsius(data)
  |> result.map_error(fn(_) { "TMP103 read failed: unexpected payload" })
}

/// Convert Celsius to Fahrenheit, matching the Elixir exercise.
pub fn read_fahrenheit(bus: Bus) -> Result(Float, String) {
  use celsius <- result.try(read_celsius(bus))
  Ok(int.to_float(celsius) *. 1.8 +. 32.0)
}

/// Decode a one-byte signed Celsius reading.
pub fn decode_celsius(data: BitArray) -> Result(Int, Nil) {
  case data {
    <<celsius:signed-size(8)>> -> Ok(celsius)
    _ -> Error(Nil)
  }
}

/// Celsius to Fahrenheit, matching the Elixir loop.
pub fn fahrenheit(celsius: Int) -> Float {
  int.to_float(celsius) *. 1.8 +. 32.0
}
