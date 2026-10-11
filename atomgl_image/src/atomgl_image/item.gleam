/// AtomGL display-list helpers for decoded rgba8888 sprites.

import atomgl_image/sprite.{type Sprite, Rgba8888}

pub type Font {
  Default16px
}

pub type Background {
  Transparent
}

/// Constructors compile to the tuples AtomGL expects:
/// `{text, X, Y, default16px, Colour, transparent, Text}`,
/// `{image, X, Y, transparent, {rgba8888, W, H, Pixels}}`,
/// `{scaled_cropped_image, X, Y, W, H, Bg, SrcX, SrcY, ScaleX, ScaleY, [], Sprite}`,
/// `{rect, X, Y, W, H, Colour}`.
pub type Item {
  Text(Int, Int, Font, Int, Background, BitArray)
  Image(Int, Int, Background, Sprite)
  ScaledCroppedImage(
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    List(Nil),
    Sprite,
  )
  Rect(Int, Int, Int, Int, Int)
}

/// Draw a sprite 1:1 with a transparent background.
pub fn image(x: Int, y: Int, sprite: Sprite) -> Item {
  Image(x, y, Transparent, sprite)
}

/// Draw a sprite scaled uniformly.
pub fn scaled(x: Int, y: Int, scale: Int, sprite: Sprite) -> Item {
  let Rgba8888(w, h, _) = sprite
  ScaledCroppedImage(
    x,
    y,
    w * scale,
    h * scale,
    0x000000,
    0,
    0,
    scale,
    scale,
    [],
    sprite,
  )
}

/// Wrap a frame index into `0 .. count-1`, including negative clocks.
pub fn wrap_frame(index: Int, count: Int) -> Int {
  case count <= 0 {
    True -> 0
    False -> {
      let r = index % count
      case r < 0 {
        True -> r + count
        False -> r
      }
    }
  }
}
