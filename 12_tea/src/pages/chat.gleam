import atomgl.{type Item, Default16px, Rect, Text, Transparent}
import config.{type Config}
import effect.{type Effect}
import gleam/list
import http/chat as http
import nav
import utils

pub type Line {
  Line(from: String, body: String)
}

pub type Model {
  Model(
    config: Config,
    username: String,
    messages: List(Line),
    draft: String,
    clock: String,
    cursor_on: Bool,
  )
}

pub type Msg {
  Type(String)
  Backspace
  Submit
  Tick
  CreatedMessage(Result(Nil, String))
}

const input_h = 20

const line_h = 16

const pad_x = 8

const body_bg = 0xf0f0f0

const ink = 0x000000

const sep = 0x000000

pub fn init(config: Config, username: String) -> #(Model, Effect(Msg)) {
  #(
    Model(
      config:,
      username:,
      messages: [],
      draft: "",
      clock: "11:04:40 UTC",
      cursor_on: True,
    ),
    effect.none(),
  )
}

pub fn set_username(model: Model, username: String) -> Model {
  Model(..model, username:)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Type(ch) -> #(Model(..model, draft: model.draft <> ch), effect.none())
    Backspace -> #(
      Model(..model, draft: utils.drop_last(model.draft)),
      effect.none(),
    )
    Submit ->
      case model.draft {
        "" -> #(model, effect.none())
        body -> {
          let from = case model.username {
            "" -> "You"
            name -> name
          }
          #(
            Model(
              ..model,
              messages: [Line(from, body), ..model.messages],
              draft: "",
            ),
            http.create_message(model.config, body, CreatedMessage),
          )
        }
      }
    Tick -> #(Model(..model, cursor_on: !model.cursor_on), effect.none())
    CreatedMessage(Ok(_)) -> #(model, effect.none())
    CreatedMessage(Error(reason)) -> #(
      Model(..model, messages: [Line("!", reason), ..model.messages]),
      effect.none(),
    )
  }
}

pub fn view(width: Int, height: Int, model: Model) -> List(Item) {
  list.flatten([
    content(width, height, model),
    nav.bar(width, nav.Chat),
    atomgl.clear(width, height, body_bg),
  ])
}

pub fn format_line(line: Line) -> String {
  line.from <> ": " <> line.body
}

fn content(width: Int, height: Int, model: Model) -> List(Item) {
  let input_y = height - input_h
  let msg_bottom = input_y - 2
  let msg_top = nav.status_h + 4
  let capacity = case msg_bottom > msg_top {
    True -> { msg_bottom - msg_top } / line_h
    False -> 0
  }

  list.flatten([
    [input_line(input_y, model)],
    [Rect(0, input_y - 2, width, 1, sep)],
    message_items(msg_top, capacity, model.messages),
  ])
}

fn message_items(top: Int, capacity: Int, messages: List(Line)) -> List(Item) {
  let visible = messages |> take_first(capacity) |> reverse()
  list.index_map(visible, fn(line, i) {
    let y = top + i * line_h
    Text(
      pad_x,
      y,
      Default16px,
      ink,
      Transparent,
      atomgl.utf8(format_line(line)),
    )
  })
}

fn input_line(y: Int, model: Model) -> Item {
  let cursor = case model.cursor_on {
    True -> "_"
    False -> " "
  }
  let text = "> " <> model.draft <> cursor
  Text(pad_x, y + 2, Default16px, ink, Transparent, atomgl.utf8(text))
}

fn take_first(items: List(a), n: Int) -> List(a) {
  case items, n <= 0 {
    _, True -> []
    [], False -> []
    [x, ..rest], False -> [x, ..take_first(rest, n - 1)]
  }
}

fn reverse(items: List(a)) -> List(a) {
  reverse_onto(items, [])
}

fn reverse_onto(items: List(a), acc: List(a)) -> List(a) {
  case items {
    [] -> acc
    [x, ..rest] -> reverse_onto(rest, [x, ..acc])
  }
}
