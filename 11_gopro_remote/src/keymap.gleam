import gleam/list
import gleam/option.{type Option, None, Some}

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
    Some("Q"),
    Some("W"),
    Some("E"),
    Some("R"),
    Some("T"),
    Some("Y"),
    Some("U"),
    Some("I"),
    Some("O"),
    Some("P"),
    Some("["),
    Some("]"),
  ],
  [
    Some("Fn"),
    Some("A"),
    Some("S"),
    Some("D"),
    Some("F"),
    Some("G"),
    Some("H"),
    Some("J"),
    Some("K"),
    Some("L"),
    Some(";"),
    Some("'"),
    Some("Enter"),
  ],
  [
    Some("LShift"),
    Some("Z"),
    Some("X"),
    Some("C"),
    Some("V"),
    Some("B"),
    Some("N"),
    Some("M"),
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

fn at(items: List(a), index: Int) -> Result(a, Nil) {
  case index >= 0 {
    True -> list.drop(items, index) |> list.first
    False -> Error(Nil)
  }
}
