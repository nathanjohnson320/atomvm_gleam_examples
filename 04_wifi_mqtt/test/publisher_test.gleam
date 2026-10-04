import gleeunit
import publisher

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn temperature_topic_test() {
  assert publisher.temperature_topic("goatmire/badge", "a1b2c3")
    == "goatmire/badge/a1b2c3/temperature"
}
