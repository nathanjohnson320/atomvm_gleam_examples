import atomvm_gleam/atomvm
import atomvm_gleam/spi.{type Spi}
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import sk6812

const pixel_count = 4

/// 3 degrees every frame. With a 10 ms frame this is faster than the 2.4 s
/// turn described in the Elixir README (`@interval` there is 10).
const hue_step = 3

const interval_ms = 10

pub fn start() -> Nil {
  case sk6812.open() {
    Error(message) -> {
      io.println(message)
      Nil
    }
    Ok(bus) -> loop(bus, 0)
  }
}

fn loop(bus: Spi, hue: Int) -> Nil {
  case sk6812.write(bus, pixels(hue)) {
    Ok(Nil) -> Nil
    Error(message) -> io.println(message)
  }
  process.sleep(interval_ms)
  loop(bus, { hue + hue_step } % 360)
}

// The four LEDs sit an equal distance apart on the colour wheel, and the
// whole wheel turns a little on every frame. Brightness is the low 8 bits of
// `atomvm:random/0`, so each LED is 0..255.
fn pixels(hue: Int) -> List(#(Int, Int, Int)) {
  use i <- list.map([0, 1, 2, 3])
  let led_hue = { hue + i * { 360 / pixel_count } } % 360
  hsv_to_rgb(led_hue, 255, int.absolute_value(atomvm.random()) % 256)
}

/// Hue 0..359, saturation and value 0..255. Integer maths only.
pub fn hsv_to_rgb(hue: Int, saturation: Int, value: Int) -> #(Int, Int, Int) {
  let sector = hue / 60
  let offset = { hue % 60 } * 255 / 60
  let p = value * { 255 - saturation } / 255
  let q = value * { 255 - saturation * offset / 255 } / 255
  let t = value * { 255 - saturation * { 255 - offset } / 255 } / 255
  sector_rgb(sector, value, p, q, t)
}

fn sector_rgb(
  sector: Int,
  value: Int,
  p: Int,
  q: Int,
  t: Int,
) -> #(Int, Int, Int) {
  case sector {
    0 -> #(value, t, p)
    1 -> #(q, value, p)
    2 -> #(p, value, t)
    3 -> #(p, q, value)
    4 -> #(t, p, value)
    _ -> #(value, p, q)
  }
}
