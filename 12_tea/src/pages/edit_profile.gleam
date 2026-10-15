import atomgl.{type Item, Default16px, Rect, Text, Transparent}
import effect.{type Effect}
import gleam/list
import nav
import utils

pub type Model {
  Model(draft: String, cursor_on: Bool)
}

pub type Msg {
  Type(String)
  Backspace
  Tick
}

const input_h = 20

const pad_x = 8

const body_bg = 0xf0f0f0

const ink = 0x000000

const dim = 0x606060

const sep = 0x000000

pub fn init(username: String) -> #(Model, Effect(Msg)) {
  #(Model(draft: username, cursor_on: True), effect.none())
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Type(ch) -> #(Model(..model, draft: model.draft <> ch), effect.none())
    Backspace -> #(
      Model(..model, draft: utils.drop_last(model.draft)),
      effect.none(),
    )
    Tick -> #(Model(..model, cursor_on: !model.cursor_on), effect.none())
  }
}

/// Enter with a non-empty draft saves; empty Enter is ignored (caller decides).
pub fn try_save(model: Model) -> Result(String, Nil) {
  case model.draft {
    "" -> Error(Nil)
    name -> Ok(name)
  }
}

pub fn view(width: Int, height: Int, model: Model) -> List(Item) {
  list.flatten([
    content(width, height, model),
    nav.bar(width, nav.Edit),
    atomgl.clear(width, height, body_bg),
  ])
}

fn content(width: Int, height: Int, model: Model) -> List(Item) {
  let input_y = height - input_h
  [
    input_line(input_y, model),
    Rect(0, input_y - 2, width, 1, sep),
    Text(pad_x, 72, Default16px, dim, Transparent, nav.body_hint(nav.Edit)),
    Text(pad_x, 48, Default16px, ink, Transparent, <<"Edit username":utf8>>),
  ]
}

fn input_line(y: Int, model: Model) -> Item {
  let cursor = case model.cursor_on {
    True -> "_"
    False -> " "
  }
  let text = "> " <> model.draft <> cursor
  Text(pad_x, y + 2, Default16px, ink, Transparent, atomgl.utf8(text))
}
