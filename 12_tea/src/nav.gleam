//// Top status bar with CP437 button glyphs (VGA font on AtomGL).

import atomgl.{type Item, Default16px, Rect, Text, Transparent}
import gleam/bit_array

pub type Page {
  Home
  Chat
  Edit
}

pub const status_h = 24

pub const pad_x = 8

pub const status_bg = 0xb0bcc8

pub const status_fg = 0x202028

pub const status_dim = 0x606870

/// CP437: ■ (black square) — Square key.
pub fn square() -> BitArray {
  <<0xfe>>
}

/// CP437: ▲ (up triangle) — Triangle key.
pub fn triangle() -> BitArray {
  <<0x1e>>
}

/// CP437: ♦ (diamond) — Diamond key.
pub fn diamond() -> BitArray {
  <<0x04>>
}

/// Status strip: current page on the left, other destinations on the right.
pub fn bar(width: Int, page: Page) -> List(Item) {
  [
    right_links(width, page),
    title(page),
    Rect(0, 0, width, status_h, status_bg),
  ]
}

fn title(page: Page) -> Item {
  let bits = case page {
    Home -> join([square(), <<" home":utf8>>])
    Chat -> join([triangle(), <<" chat":utf8>>])
    Edit -> join([diamond(), <<" edit":utf8>>])
  }
  Text(pad_x, 4, Default16px, status_fg, Transparent, bits)
}

fn right_links(width: Int, page: Page) -> Item {
  let bits = case page {
    Home -> join([triangle(), <<"chat ":utf8>>, diamond(), <<"edit":utf8>>])
    Chat -> join([square(), <<"home":utf8>>])
    Edit -> join([square(), <<"home  Enter=save":utf8>>])
  }
  let x = width - bit_array.byte_size(bits) * 8 - pad_x
  Text(x, 4, Default16px, status_dim, Transparent, bits)
}

pub fn body_hint(page: Page) -> BitArray {
  case page {
    Home -> join([diamond(), <<" edit name":utf8>>])
    Chat -> join([square(), <<" home":utf8>>])
    Edit -> join([square(), <<" cancel":utf8>>])
  }
}

fn join(parts: List(BitArray)) -> BitArray {
  bit_array.concat(parts)
}
