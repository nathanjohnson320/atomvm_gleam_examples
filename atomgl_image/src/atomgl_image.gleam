//// Decode PNG/GIF into rgba8888 sprites and dump AtomGL image assets.
////
//// See `atomgl_image/png`, `atomgl_image/gif`, `atomgl_image/dump`,
//// `atomgl_image/sprite`, and `atomgl_image/item`.

import atomgl_image/sprite.{type Sprite}

/// Re-export so the package root documents the core pixel type.
pub type ImageSprite =
  Sprite
