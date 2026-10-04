import gleam/int
import gleam/list

pub type Font {
  Default16px
}

pub type Background {
  Transparent
}

/// Constructors compile to the tuples AtomGL expects:
/// `{text, X, Y, default16px, Colour, transparent, Text}`,
/// `{rect, X, Y, W, H, Colour}`.
pub type Item {
  Text(Int, Int, Font, Int, Background, BitArray)
  Rect(Int, Int, Int, Int, Int)
}

const background = 0x000000

const label = 0x808080

const value = 0xffffff

const dim = 0x202020

// A row of pips under the number. It fills one pip per press and starts over,
// while the number keeps the real total.
const pip_count = 16

const pip_width = 14

const pip_height = 24

const pip_gap = 4

const pip_x = 20

const pip_y = 150

/// First item is on top and the last is drawn first, so the background
/// rectangle stays at the end of the list.
pub fn render(width: Int, height: Int, count: Int) -> List(Item) {
  list.append(pips(count), [
    Text(20, 110, Default16px, value, Transparent, count_text(count)),
    Text(20, 70, Default16px, label, Transparent, <<"Presses":utf8>>),
    Rect(0, 0, width, height, background),
  ])
}

pub fn filled_pips(count: Int) -> Int {
  case count {
    0 -> 0
    _ -> { count - 1 } % pip_count + 1
  }
}

fn count_text(count: Int) -> BitArray {
  let text = int.to_string(count)
  <<text:utf8>>
}

fn pips(count: Int) -> List(Item) {
  let filled = filled_pips(count)
  // `int.range` is exclusive of `to`. Prepend then reverse to keep left-to-right.
  int.range(from: 0, to: pip_count, with: [], run: fn(items, i) {
    let colour = case i < filled {
      True -> value
      False -> dim
    }
    let x = pip_x + i * { pip_width + pip_gap }
    [Rect(x, pip_y, pip_width, pip_height, colour), ..items]
  })
  |> list.reverse
}
