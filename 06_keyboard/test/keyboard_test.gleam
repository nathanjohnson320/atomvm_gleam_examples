import gleam/option.{None, Some}
import gleeunit
import keyboard
import keymap

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn q_label_test() {
  assert keymap.label(2, 1) == Some("Q")
}

pub fn space_label_test() {
  assert keymap.label(5, 4) == Some("Space")
}

pub fn empty_cell_test() {
  assert keymap.label(0, 0) == None
}

pub fn out_of_range_label_test() {
  assert keymap.label(9, 0) == None
  assert keymap.label(0, 99) == None
  assert keymap.label(-1, 0) == None
}

pub fn press_test() {
  assert keyboard.changes([], [#(2, 1)]) == #([#(2, 1)], [])
}

pub fn release_test() {
  assert keyboard.changes([#(2, 1)], []) == #([], [#(2, 1)])
}

pub fn held_key_reported_once_test() {
  assert keyboard.changes([#(2, 1)], [#(2, 1)]) == #([], [])
}

pub fn press_keeps_scan_order_test() {
  assert keyboard.changes([#(2, 1)], [#(2, 1), #(3, 2), #(4, 0)])
    == #([#(3, 2), #(4, 0)], [])
}
