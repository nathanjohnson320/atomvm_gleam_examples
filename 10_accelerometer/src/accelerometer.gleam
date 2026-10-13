import assets
import atomgl_image/sprite.{type Sprite}
import atomvm_gleam/display
import atomvm_gleam/i2c
import atomvm_gleam/spi
import gleam/erlang/process
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import sc7a20
import scene.{type Body}

const width = 320

const height = 240

/// Sensor poll cadence. I²C is cheap; the panel write is not.
const poll_ms = 40

/// Shortest gap between full-panel repaints (~one ST7789 write at 40 MHz).
const min_frame_ms = 40

pub fn start() -> Nil {
  let assert Ok(Nil) = initialize()
  Nil
}

fn initialize() -> Result(Nil, String) {
  use spi_bus <- result.try(
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
    |> or_log("SPI open failed", spi.error_to_string),
  )
  use bus <- result.try(
    i2c.open(i2c.Config(scl: 10, sda: 11, clock_speed_hz: 100_000))
    |> or_log("I2C open failed", i2c.error_to_string),
  )
  use _ <- result.try(
    sc7a20.init(bus) |> or_log("SC7A20 init failed", sc7a20.error_to_string),
  )

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
      clock_speed_hz: Some(40_000_000),
      spi_host: spi_bus,
    ))

  let lucy = assets.lucy_png()
  let body = scene.rest()

  display.update(screen, scene.render(lucy, body))

  screen
  |> loop(bus, lucy, None, body)
  |> Ok()
}

fn loop(
  screen: display.Display,
  bus: i2c.Bus,
  lucy: Sprite,
  previous: Option(sc7a20.Mg),
  body: Body,
) -> Nil {
  case sc7a20.read(bus, previous) {
    Error(message) -> {
      io.println(message)
      process.sleep(poll_ms)
      loop(screen, bus, lucy, previous, body)
    }
    Ok(mg) -> {
      let #(x_mg, y_mg, _) = mg
      let next = scene.step(body, x_mg, y_mg)
      case next.x != body.x || next.y != body.y {
        True -> {
          display.update(screen, scene.render(lucy, next))
          process.sleep(min_frame_ms)
        }
        False -> process.sleep(poll_ms)
      }
      loop(screen, bus, lucy, Some(mg), next)
    }
  }
}

fn or_log(
  value: Result(a, e),
  message: String,
  explain: fn(e) -> String,
) -> Result(a, String) {
  result.map_error(value, fn(error) {
    io.println(message <> ": " <> explain(error))
    message
  })
}
