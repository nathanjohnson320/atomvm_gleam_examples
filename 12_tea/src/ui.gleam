//// App shell — mirrors an elm `ui` package: routes + page msgs + effects.

import atomgl.{type Item}
import config
import effect.{type Effect}
import gleam/option.{type Option, None, Some}
import keymap
import pages/chat
import pages/edit_profile
import pages/profile
import runtime

// MAIN ------------------------------------------------------------------------

pub fn start() -> Nil {
  runtime.start(init, update, view, key_msg, Tick)
}

// MODEL -----------------------------------------------------------------------

pub type Route {
  Profile
  EditProfile
  Chat
}

pub type Model {
  Model(
    route: Route,
    username: String,
    chat: chat.Model,
    edit: edit_profile.Model,
  )
}

pub type Msg {
  Key(keymap.Key)
  Tick
  ChatMsg(chat.Msg)
  EditMsg(edit_profile.Msg)
}

fn init() -> #(Model, Effect(Msg)) {
  let cfg = config.load()
  let username = ""
  let #(chat_model, chat_eff) = chat.init(cfg, username)
  let #(edit_model, edit_eff) = edit_profile.init(username)
  // No username yet → land on edit so the first run sets a name.
  let route = case username {
    "" -> EditProfile
    _ -> Profile
  }
  #(
    Model(route:, username:, chat: chat_model, edit: edit_model),
    effect.batch([
      effect.map(chat_eff, ChatMsg),
      effect.map(edit_eff, EditMsg),
    ]),
  )
}

fn key_msg(coord: #(Int, Int)) -> Option(Msg) {
  case keymap.from_coord(coord) {
    Some(key) -> Some(Key(key))
    None -> None
  }
}

// UPDATE ----------------------------------------------------------------------

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    Key(key) -> handle_key(model, key)
    Tick -> tick(model)
    ChatMsg(inner) -> {
      let #(page, eff) = chat.update(model.chat, inner)
      #(Model(..model, chat: page), effect.map(eff, ChatMsg))
    }
    EditMsg(inner) -> {
      let #(page, eff) = edit_profile.update(model.edit, inner)
      #(Model(..model, edit: page), effect.map(eff, EditMsg))
    }
  }
}

fn handle_key(model: Model, key: keymap.Key) -> #(Model, Effect(Msg)) {
  case key {
    keymap.Square -> go_profile(model)
    keymap.Triangle -> go_chat(model)
    keymap.Diamond ->
      case model.route {
        Profile -> go_edit(model)
        _ -> #(model, effect.none())
      }
    _ -> page_key(model, key)
  }
}

fn page_key(model: Model, key: keymap.Key) -> #(Model, Effect(Msg)) {
  case model.route {
    Chat ->
      case key {
        keymap.Enter -> forward_chat(model, chat.Submit)
        keymap.Bksp -> forward_chat(model, chat.Backspace)
        keymap.Char(ch) -> forward_chat(model, chat.Type(ch))
        _ -> #(model, effect.none())
      }
    EditProfile ->
      case key {
        keymap.Enter -> save_profile(model)
        keymap.Bksp -> forward_edit(model, edit_profile.Backspace)
        keymap.Char(ch) -> forward_edit(model, edit_profile.Type(ch))
        _ -> #(model, effect.none())
      }
    Profile -> #(model, effect.none())
  }
}

fn forward_chat(model: Model, msg: chat.Msg) -> #(Model, Effect(Msg)) {
  let #(page, eff) = chat.update(model.chat, msg)
  #(Model(..model, chat: page), effect.map(eff, ChatMsg))
}

fn forward_edit(model: Model, msg: edit_profile.Msg) -> #(Model, Effect(Msg)) {
  let #(page, eff) = edit_profile.update(model.edit, msg)
  #(Model(..model, edit: page), effect.map(eff, EditMsg))
}

fn go_profile(model: Model) -> #(Model, Effect(Msg)) {
  case model.username {
    "" -> go_edit(model)
    _ -> #(Model(..model, route: Profile), effect.none())
  }
}

fn go_chat(model: Model) -> #(Model, Effect(Msg)) {
  case model.username {
    "" -> go_edit(model)
    _ -> #(Model(..model, route: Chat), effect.none())
  }
}

fn go_edit(model: Model) -> #(Model, Effect(Msg)) {
  let #(edit, eff) = edit_profile.init(model.username)
  #(Model(..model, route: EditProfile, edit:), effect.map(eff, EditMsg))
}

fn save_profile(model: Model) -> #(Model, Effect(Msg)) {
  case edit_profile.try_save(model.edit) {
    Ok(name) -> #(
      Model(
        ..model,
        username: name,
        chat: chat.set_username(model.chat, name),
        route: Profile,
      ),
      effect.none(),
    )
    Error(Nil) -> #(model, effect.none())
  }
}

fn tick(model: Model) -> #(Model, Effect(Msg)) {
  case model.route {
    Chat -> forward_chat(model, chat.Tick)
    EditProfile -> forward_edit(model, edit_profile.Tick)
    Profile -> #(model, effect.none())
  }
}

// VIEW ------------------------------------------------------------------------

fn view(width: Int, height: Int, model: Model) -> List(Item) {
  case model.route {
    Profile -> profile.view(width, height, model.username)
    EditProfile -> edit_profile.view(width, height, model.edit)
    Chat -> chat.view(width, height, model.chat)
  }
}
