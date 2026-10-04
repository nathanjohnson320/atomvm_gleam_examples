import gleeunit
import hello_world

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn alive_line_test() {
  assert hello_world.alive_line(0) == "Still alive, 0 seconds"
}
