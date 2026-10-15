import atomgl.{Text}
import config
import gleam/list
import gleam/option.{Some}
import gleeunit
import keymap
import pages/chat.{Line}
import pages/edit_profile
import pages/profile

pub fn main() -> Nil {
  gleeunit.main()
}

fn has_text(items: List(atomgl.Item), needle: BitArray) -> Bool {
  list.any(items, fn(item) {
    case item {
      Text(_, _, _, _, _, text) -> text == needle
      _ -> False
    }
  })
}

fn chat_model() -> chat.Model {
  let #(m, _) = chat.init(config.load(), "nate")
  m
}

pub fn chat_starts_empty_test() {
  let m = chat_model()
  assert m.messages == []
  assert m.draft == ""
}

pub fn type_and_submit_uses_username_test() {
  let #(m, _) = chat.update(chat_model(), chat.Type("h"))
  let #(m, _) = chat.update(m, chat.Type("i"))
  assert m.draft == "hi"

  let #(m, _) = chat.update(m, chat.Submit)
  assert m.draft == ""
  assert m.messages == [Line("nate", "hi")]
}

pub fn backspace_test() {
  let #(m, _) = chat.update(chat_model(), chat.Type("ab"))
  let #(m, _) = chat.update(m, chat.Backspace)
  assert m.draft == "a"
}

pub fn empty_submit_ignored_test() {
  let before = chat_model()
  let #(after, _) = chat.update(before, chat.Submit)
  assert after.messages == []
}

pub fn chat_view_shows_title_and_prompt_test() {
  let items = chat.view(320, 240, chat_model())
  assert has_text(items, <<0x1e, " chat":utf8>>)
  assert has_text(items, <<"> _":utf8>>)
}

pub fn format_line_test() {
  assert chat.format_line(Line("Juli", "hi")) == "Juli: hi"
}

pub fn profile_view_unset_test() {
  let items = profile.view(320, 240, "")
  assert has_text(items, <<0xfe, " home":utf8>>)
  assert has_text(items, <<"Username: (not set)":utf8>>)
  assert has_text(items, <<0x04, " edit name":utf8>>)
}

pub fn profile_view_set_test() {
  let items = profile.view(320, 240, "nate")
  assert has_text(items, <<"Username: nate":utf8>>)
}

pub fn edit_save_test() {
  let #(m, _) = edit_profile.init("")
  let #(m, _) = edit_profile.update(m, edit_profile.Type("n"))
  let #(m, _) = edit_profile.update(m, edit_profile.Type("j"))
  assert edit_profile.try_save(m) == Ok("nj")
}

pub fn edit_empty_save_rejected_test() {
  let #(m, _) = edit_profile.init("")
  assert edit_profile.try_save(m) == Error(Nil)
}

pub fn square_label_test() {
  assert keymap.label(0, 2) == Some("Square")
}

pub fn triangle_label_test() {
  assert keymap.label(0, 3) == Some("Triangle")
}

pub fn diamond_label_test() {
  assert keymap.label(0, 10) == Some("Diamond")
}

pub fn letter_label_test() {
  assert keymap.label(2, 1) == Some("q")
}
