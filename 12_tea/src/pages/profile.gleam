import atomgl.{type Item, Default16px, Text, Transparent}
import gleam/list
import nav

const body_bg = 0xf0f0f0

const ink = 0x000000

const dim = 0x606060

const pad_x = 8

pub fn view(width: Int, height: Int, username: String) -> List(Item) {
  list.flatten([
    content(username),
    nav.bar(width, nav.Home),
    atomgl.clear(width, height, body_bg),
  ])
}

fn content(username: String) -> List(Item) {
  let name_line = case username {
    "" -> "Username: (not set)"
    name -> "Username: " <> name
  }

  [
    Text(pad_x, 120, Default16px, dim, Transparent, nav.body_hint(nav.Home)),
    Text(pad_x, 72, Default16px, ink, Transparent, atomgl.utf8(name_line)),
    Text(pad_x, 48, Default16px, ink, Transparent, <<"Profile":utf8>>),
  ]
}
