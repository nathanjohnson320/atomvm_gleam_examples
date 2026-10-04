import atomvm_gleam/display
import atomvm_gleam/spi
import gleam/io
import gleam/option.{None, Some}
import temperature_scene
import tmp103.{type Bus}

const width = 320

const height = 240

@external(erlang, "timer", "sleep")
fn sleep(milliseconds: Int) -> Nil

/// AtomVM entrypoint. The package name in `gleam.toml` is `display`, so this
/// module is the one Orbital marks as the start module.
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
    Ok(bus) -> {
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
          spi_host: bus,
        ))
      loop(screen, tmp103.open())
    }
  }
}

fn loop(screen: display.Display, sensor: Bus) -> Nil {
  let temperature = tmp103.read(sensor)
  display.update(
    screen,
    temperature_scene.render(width, height, Some(temperature)),
  )
  sleep(1000)
  loop(screen, sensor)
}
