import assets
import atomgl_image/item
import atomgl_image/sprite.{type Sprite}
import atomvm_gleam/display
import atomvm_gleam/spi
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import scene

const width = 320

const height = 240

const frame_ms = 120

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
      // Pre-decoded rgba8888 from `gleam run -m dump_assets`.
      loop(screen, assets.lucy_png(), assets.lucy_spin_frames(), 0)
    }
  }
}

fn loop(
  screen: display.Display,
  png_sprite: Sprite,
  gif_frames: List(Sprite),
  frame: Int,
) -> Nil {
  display.update(
    screen,
    scene.render(width, height, png_sprite, gif_frames, frame),
  )
  process.sleep(frame_ms)
  let next = case list.length(gif_frames) {
    0 -> 0
    count -> item.wrap_frame(frame + 1, count)
  }
  loop(screen, png_sprite, gif_frames, next)
}
