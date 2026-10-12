import counter_scene.{Rect, Text}
import gleam/list
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn zero_presses_test() {
  assert counter_scene.filled_pips(0) == 0

  let assert Ok(Text(_, _, _, _, _, text)) =
    counter_scene.render(320, 240, 0)
    |> list.find(fn(item) {
      case item {
        Text(_, 110, _, _, _, _) -> True
        _ -> False
      }
    })

  assert text == <<"0":utf8>>
}

pub fn first_press_fills_one_pip_test() {
  assert counter_scene.filled_pips(1) == 1
}

pub fn sixteenth_press_fills_the_row_test() {
  assert counter_scene.filled_pips(16) == 16
}

pub fn seventeenth_press_wraps_the_pips_test() {
  assert counter_scene.filled_pips(17) == 1
}

pub fn render_draws_sixteen_pips_test() {
  let pips =
    counter_scene.render(320, 240, 3)
    |> list.filter_map(fn(item) {
      case item {
        Rect(x, 150, 14, 24, _) -> Ok(x)
        _ -> Error(Nil)
      }
    })

  assert list.length(pips) == 16
  assert pips
    == [
      20, 38, 56, 74, 92, 110, 128, 146, 164, 182, 200, 218, 236, 254, 272, 290,
    ]
}

pub fn third_press_lights_three_pips_test() {
  let lit =
    counter_scene.render(320, 240, 3)
    |> list.filter_map(fn(item) {
      case item {
        Rect(_, 150, 14, 24, 0xffffff) -> Ok(Nil)
        _ -> Error(Nil)
      }
    })

  assert list.length(lit) == 3
}
