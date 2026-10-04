import atomvm_gleam/i2c
import gleam/float
import gleam/int
import gleam/io
import gleam/result
import tmp103

@external(erlang, "timer", "sleep")
fn sleep(milliseconds: Int) -> Nil

/// AtomVM entrypoint. The package name in `gleam.toml` is `temperature`, so
/// this module is the one Orbital marks as the start module.
pub fn start() -> Nil {
  case open_bus() {
    Error(message) -> {
      io.println(message)
      Nil
    }
    Ok(bus) -> loop(bus)
  }
}

fn open_bus() -> Result(i2c.Bus, String) {
  i2c.open(i2c.Config(scl: 10, sda: 11, clock_speed_hz: 100_000))
  |> result.map_error(fn(error) {
    "I2C open failed: " <> i2c.error_to_string(error)
  })
}

fn loop(bus: i2c.Bus) -> Nil {
  case tmp103.read_fahrenheit(bus) {
    Ok(fahrenheit) -> io.println("Temperature: " <> format_f(fahrenheit) <> " °F")
    Error(message) -> io.println(message)
  }
  sleep(1000)
  loop(bus)
}

fn format_f(fahrenheit: Float) -> String {
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
