/// Decoded rgba8888 pixel buffers for AtomGL `{rgba8888, W, H, Pixels}`.

pub type Sprite {
  Rgba8888(Int, Int, BitArray)
}

pub fn width(sprite: Sprite) -> Int {
  let Rgba8888(w, _, _) = sprite
  w
}

pub fn height(sprite: Sprite) -> Int {
  let Rgba8888(_, h, _) = sprite
  h
}
