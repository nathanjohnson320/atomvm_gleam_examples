import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Key {
  Square
  Triangle
  Diamond
  Enter
  Bksp
  Char(String)
}

/// What each matrix position means, kept apart from the scanning so the layout
/// can be corrected without touching the electrical code.
///
/// One list per row, left to right. `None` is a position with no switch under
/// it.
const layout = [
  [
    None,
    Some("Esc"),
    Some("Square"),
    Some("Triangle"),
    Some("Cross"),
    None,
    None,
    None,
    Some("Circle"),
    Some("Clover"),
    Some("Diamond"),
    Some("Bksp"),
    None,
  ],
  [
    Some("`"),
    Some("1"),
    Some("2"),
    Some("3"),
    Some("4"),
    Some("5"),
    Some("6"),
    Some("7"),
    Some("8"),
    Some("9"),
    Some("0"),
    Some("-"),
    Some("="),
  ],
  [
    Some("Tab"),
    Some("q"),
    Some("w"),
    Some("e"),
    Some("r"),
    Some("t"),
    Some("y"),
    Some("u"),
    Some("i"),
    Some("o"),
    Some("p"),
    Some("["),
    Some("]"),
  ],
  [
    Some("Fn"),
    Some("a"),
    Some("s"),
    Some("d"),
    Some("f"),
    Some("g"),
    Some("h"),
    Some("j"),
    Some("k"),
    Some("l"),
    Some(";"),
    Some("'"),
    Some("Enter"),
  ],
  [
    Some("LShift"),
    Some("z"),
    Some("x"),
    Some("c"),
    Some("v"),
    Some("b"),
    Some("n"),
    Some("m"),
    Some(","),
    Some("."),
    Some("/"),
    Some("Up"),
    Some("RShift"),
  ],
  [
    Some("Ctrl"),
    Some("SP"),
    Some("Alt"),
    Some("\\"),
    Some("Space"),
    Some("Space"),
    Some("Space"),
    Some("Space"),
    None,
    Some("AltGr"),
    Some("Left"),
    Some("Down"),
    Some("Right"),
  ],
]

/// Label for a matrix position. `None` when the cell is empty or out of range.
pub fn label(row: Int, col: Int) -> Option(String) {
  case at(layout, row) {
    Ok(row_keys) ->
      case at(row_keys, col) {
        Ok(label) -> label
        Error(Nil) -> None
      }
    Error(Nil) -> None
  }
}

pub fn from_coord(coord: #(Int, Int)) -> Option(Key) {
  let #(row, col) = coord
  case label(row, col) {
    Some("Square") -> Some(Square)
    Some("Triangle") -> Some(Triangle)
    Some("Diamond") -> Some(Diamond)
    Some("Enter") -> Some(Enter)
    Some("Bksp") -> Some(Bksp)
    Some("Space") -> Some(Char(" "))
    Some(name) ->
      case is_modifier(name) {
        True -> None
        False ->
          case string.length(name) == 1 {
            True -> Some(Char(name))
            False -> None
          }
      }
    None -> None
  }
}

fn is_modifier(name: String) -> Bool {
  case name {
    "Esc"
    | "Tab"
    | "Fn"
    | "LShift"
    | "RShift"
    | "Ctrl"
    | "Alt"
    | "AltGr"
    | "SP"
    | "Left"
    | "Right"
    | "Up"
    | "Down"
    | "Cross"
    | "Circle"
    | "Clover" -> True
    _ -> False
  }
}

fn at(items: List(a), index: Int) -> Result(a, Nil) {
  case index >= 0 {
    True -> list.drop(items, index) |> list.first
    False -> Error(Nil)
  }
}
