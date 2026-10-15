/// Shared AtomGL display-list constructors for page views.
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

/// AtomGL's damage box skips a single full-screen rect — clear in two halves.
pub fn clear(width: Int, height: Int, colour: Int) -> List(Item) {
  let mid = height / 2
  [Rect(0, 0, width, mid, colour), Rect(0, mid, width, height - mid, colour)]
}

pub fn utf8(text: String) -> BitArray {
  <<text:utf8>>
}
