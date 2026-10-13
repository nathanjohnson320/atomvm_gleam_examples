import atomvm_gleam/display
import atomvm_gleam/i2c
import atomvm_gleam/spi
import gleam/erlang/process
import gleam/io
import gleam/option.{None, Some}
import temperature_scene
import tmp103

const width = 320

const height = 240

pub fn start() -> Nil {
  case
    spi.open(
      spi.Params(
        bus_config: spi.BusConfig(
          peripheral: Some("spi2"),
          sclk: Some(5),
          mosi: Some(8),
          miso: Some(9),
          pico: None,
          poci: None,
        ),
        device_config: [],
      ),
    )
  {
    Error(error) -> {
      io.println("SPI open failed: " <> spi.error_to_string(error))
      Nil
    }
    Ok(spi_bus) ->
      case i2c.open(i2c.Config(scl: 10, sda: 11, clock_speed_hz: 100_000)) {
        Error(error) -> {
          io.println("I2C open failed: " <> i2c.error_to_string(error))
          Nil
        }
        Ok(sensor) -> {
          let screen =
            display.open(display.Config(
              compatible: "sitronix,st7789",
              init_seq_type: "alt_gamma_2",
              enable_tft_invon: True,
              width:,
              height:,
              rotation: 3,
              reset: 6,
              dc: 4,
              cs: 7,
              backlight: 3,
              backlight_active: display.Low,
              backlight_enabled: True,
              clock_speed_hz: None,
              spi_host: spi_bus,
            ))
          loop(screen, sensor)
        }
      }
  }
}

fn loop(screen: display.Display, sensor: i2c.Bus) -> Nil {
  let temperature = case tmp103.read(sensor) {
    Ok(fahrenheit) -> Some(fahrenheit)
    Error(message) -> {
      io.println(message)
      None
    }
  }
  display.update(screen, temperature_scene.render(width, height, temperature))
  process.sleep(1000)
  loop(screen, sensor)
}
