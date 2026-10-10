import gleam/list
import image.{
  type Item, type Sprite, Default16px, Rect, Text, Transparent,
}

const background = 0x202020

const label = 0xc0c0c0

/// First item is on top; background rect stays last.
pub fn render(
  width: Int,
  height: Int,
  png: Sprite,
  gif_frames: List(Sprite),
  frame_index: Int,
) -> List(Item) {
  let png_item = image.image(24, 40, png)
  let gif_item = case gif_frames {
    [] -> Text(180, 40, Default16px, label, Transparent, <<"no gif":utf8>>)
    frames -> {
      let index = image.wrap_frame(frame_index, list.length(frames))
      let assert Ok(frame) = list.drop(frames, index) |> list.first
      image.scaled(180, 40, 3, frame)
    }
  }

  [
    Text(24, 16, Default16px, label, Transparent, <<"PNG":utf8>>),
    Text(180, 16, Default16px, label, Transparent, <<"GIF":utf8>>),
    png_item,
    gif_item,
    Rect(0, 0, width, height, background),
  ]
}
