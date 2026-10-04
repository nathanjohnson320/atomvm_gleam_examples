import atomvm_gleam/i2c.{type Bus}
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
  case data {
    <<celsius:signed-size(8)>> -> Ok(celsius)
    _ -> Error("TMP103 read failed: unexpected payload")
  }
}
