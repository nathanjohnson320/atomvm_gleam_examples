import atomgl_image/item.{
  type Item, Default16px, Rect, Text, Transparent, scaled, wrap_frame,
}
import atomgl_image/sprite.{type Sprite}
import gleam/list

const background = 0x202020

const label = 0xffaff3

/// First item is on top; background rect stays last.
pub fn render(
  width: Int,
  height: Int,
  png: Sprite,
  gif_frames: List(Sprite),
  frame_index: Int,
) -> List(Item) {
  // 32×32 Lucy, shown 2× so she stays readable on the 320×240 panel.
  let png_item = scaled(24, 48, 2, png)
  let gif_item = case gif_frames {
    [] -> Text(176, 48, Default16px, label, Transparent, <<"no gif":utf8>>)
    frames -> {
      let index = wrap_frame(frame_index, list.length(frames))
      let assert Ok(frame) = list.drop(frames, index) |> list.first
      scaled(176, 48, 2, frame)
    }
  }

  [
    Text(24, 20, Default16px, label, Transparent, <<"Lucy":utf8>>),
    Text(176, 20, Default16px, label, Transparent, <<"Spin":utf8>>),
    png_item,
    gif_item,
    Rect(0, 0, width, height, background),
  ]
}
