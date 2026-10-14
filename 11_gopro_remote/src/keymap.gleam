import gleam/option.{type Option, None, Some}

/// Arrow cluster only — this app ignores the rest of the matrix.
pub fn label(row: Int, col: Int) -> Option(String) {
  case row, col {
    4, 11 -> Some("Up")
    5, 10 -> Some("Left")
    5, 11 -> Some("Down")
    5, 12 -> Some("Right")
    _, _ -> None
  }
}
