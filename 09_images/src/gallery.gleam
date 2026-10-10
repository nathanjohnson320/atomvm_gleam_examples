import assets
import atomvm_gleam/display
import atomvm_gleam/spi
import gif
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import image.{type Sprite}
import png
import scene

const width = 320

const height = 240

const frame_ms = 200

@external(erlang, "timer", "sleep")
fn sleep(milliseconds: Int) -> Nil

/// AtomVM entrypoint. The package name in `gleam.toml` is `gallery`.
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
      case load_assets() {
        Error(message) -> {
          io.println(message)
          Nil
        }
        Ok(#(png_sprite, gif_frames)) ->
          loop(screen, png_sprite, gif_frames, 0)
      }
    }
  }
}

fn load_assets() -> Result(#(Sprite, List(Sprite)), String) {
  case png.decode(assets.demo_png()) {
    Error(_) -> Error("PNG decode failed")
    Ok(png_sprite) ->
      case gif.decode(assets.demo_gif()) {
        Error(_) -> Error("GIF decode failed")
        Ok(frames) -> Ok(#(png_sprite, frames))
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
  sleep(frame_ms)
  let next = case list.length(gif_frames) {
    0 -> 0
    count -> image.wrap_frame(frame + 1, count)
  }
  loop(screen, png_sprite, gif_frames, next)
}
