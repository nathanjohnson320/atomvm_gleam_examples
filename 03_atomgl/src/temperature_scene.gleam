import gleam/bit_array
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import tmp103

pub type Font {
  Default16px
}

pub type Background {
  Transparent
}

pub type Sprite {
  Rgba8888(Int, Int, BitArray)
}

/// Constructors compile to the tuples AtomGL expects:
/// `{text, X, Y, default16px, Colour, transparent, Text}`,
/// `{image, X, Y, transparent, {rgba8888, W, H, Pixels}}`,
/// `{rect, X, Y, W, H, Colour}`.
pub type Item {
  Text(Int, Int, Font, Int, Background, BitArray)
  Image(Int, Int, Background, Sprite)
  Rect(Int, Int, Int, Int, Int)
}

const background = 0x000000

const label = 0x808080

const value_colour = 0xffffff

const glass = 0x808080

// Mercury fills the tube across this range, in Fahrenheit, and blends from
// cold to hot as it rises.
const min_temperature = -15

const max_temperature = 120

const cold = 0x0000ff

const hot = 0xff0000

// Thermometer geometry, in pixels. The inner tube runs from tube_top down to
// tube_bottom, where it disappears into the bulb.
const tube_x = 240

const tube_width = 20

const tube_top = 24

const tube_bottom = 184

const wall = 4

const bulb_size = 40

const bulb_x = 230

const bulb_y = 180

const bulb_wall = 4

/// First item is on top and the last is drawn first, so the background
/// rectangle stays at the end of the list.
pub fn render(width: Int, height: Int, temperature: Option(Float)) -> List(Item) {
  let mercury = mercury_colour(temperature)
  let column = mercury_height(temperature)

  [
    Text(20, 100, Default16px, value_colour, Transparent, reading(temperature)),
    Text(20, 70, Default16px, label, Transparent, <<"Temperature":utf8>>),
    Text(
      tube_x + tube_width + wall + 8,
      tube_top - 8,
      Default16px,
      label,
      Transparent,
      <<int.to_string(max_temperature):utf8, "F":utf8>>,
    ),
    Text(
      tube_x + tube_width + wall + 8,
      tube_bottom - 8,
      Default16px,
      label,
      Transparent,
      <<int.to_string(min_temperature):utf8, "F":utf8>>,
    ),
    Image(
      bulb_x,
      bulb_y,
      Transparent,
      Rgba8888(bulb_size, bulb_size, bulb(mercury)),
    ),
    Rect(tube_x, tube_bottom - column, tube_width, column, mercury),
    Rect(tube_x, tube_top, tube_width, tube_bottom - tube_top, background),
    Rect(
      tube_x - wall,
      tube_top - wall,
      tube_width + 2 * wall,
      tube_bottom - tube_top + 2 * wall,
      glass,
    ),
    Rect(0, 0, width, height, background),
  ]
}

fn reading(temperature: Option(Float)) -> BitArray {
  case temperature {
    option.None -> <<"--":utf8>>
    // AtomGL's built-in font is the Linux 8x16 VGA font, indexed by raw byte
    // in CP437 layout. Byte 0xF8 is the degree sign.
    option.Some(temperature) -> {
      let text = tmp103.format(temperature) <> " "
      <<text:utf8, 0xf8, "F":utf8>>
    }
  }
}

fn fraction(temperature: Float) -> Float {
  let low = int.to_float(min_temperature)
  let high = int.to_float(max_temperature)
  let clamped = temperature |> float.max(low) |> float.min(high)
  { clamped -. low } /. { high -. low }
}

fn mercury_height(temperature: Option(Float)) -> Int {
  case temperature {
    option.None -> 0
    option.Some(temperature) ->
      float.round(fraction(temperature) *. int.to_float(tube_bottom - tube_top))
  }
}

fn mercury_colour(temperature: Option(Float)) -> Int {
  case temperature {
    option.None -> background
    option.Some(temperature) -> blend(fraction(temperature))
  }
}

fn blend(portion: Float) -> Int {
  use colour, shift <- list.fold([16, 8, 0], 0)
  let from = channel(cold, shift)
  let to = channel(hot, shift)
  let mixed =
    float.round(
      int.to_float(from)
      +. { int.to_float(to) -. int.to_float(from) }
      *. portion,
    )
  int.bitwise_or(colour, int.bitwise_shift_left(mixed, shift))
}

fn channel(colour: Int, shift: Int) -> Int {
  int.bitwise_and(int.bitwise_shift_right(colour, shift), 0xff)
}

// A round bulb: a glass ring around mercury, with transparent corners. Above
// the centre the mercury also runs through the ring so it joins the tube.
// Coordinates are doubled so the pixel centres stay integers.
fn bulb(mercury: Int) -> BitArray {
  let outer = bulb_size * bulb_size
  let inner = { bulb_size - 2 * bulb_wall } * { bulb_size - 2 * bulb_wall }
  let offset = { bulb_size - tube_width } / 2

  // `int.range` is exclusive of `to`, so this visits every pixel once.
  int.range(from: 0, to: bulb_size, with: [], run: fn(rows, y) {
    let row =
      int.range(from: 0, to: bulb_size, with: [], run: fn(pixels, x) {
        [bulb_pixel(x, y, outer, inner, offset, mercury), ..pixels]
      })
    [list.reverse(row), ..rows]
  })
  |> list.reverse
  |> list.flatten
  |> bit_array.concat
}

fn bulb_pixel(
  x: Int,
  y: Int,
  outer: Int,
  inner: Int,
  offset: Int,
  mercury: Int,
) -> BitArray {
  let dx = 2 * x - { bulb_size - 1 }
  let dy = 2 * y - { bulb_size - 1 }
  let distance = dx * dx + dy * dy
  let in_tube = dy < 0 && x >= offset && x < offset + tube_width

  case distance > outer, distance <= inner || in_tube {
    True, _ -> pixel(background, 0)
    False, True -> pixel(mercury, 255)
    False, False -> pixel(glass, 255)
  }
}

// AtomGL reads each pixel as a little-endian 0xRRGGBBAA word, so the bytes
// go alpha, blue, green, red.
fn pixel(colour: Int, alpha: Int) -> BitArray {
  <<
    alpha,
    int.bitwise_and(colour, 0xff),
    int.bitwise_and(int.bitwise_shift_right(colour, 8), 0xff),
    int.bitwise_shift_right(colour, 16),
  >>
}
