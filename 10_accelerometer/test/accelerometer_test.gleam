import gleam/float
import gleam/int
import gleam/option.{None, Some}
import gleeunit
import sc7a20
import scene

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn decode_panel_frame_test() {
  let bytes = <<
    -1120:int-little-size(16),
    13_936:int-little-size(16),
    -9184:int-little-size(16),
  >>
  assert sc7a20.decode(bytes) == Ok(#(68, 850, 560))
}

pub fn decode_face_up_test() {
  let bytes = <<
    0:int-little-size(16),
    0:int-little-size(16),
    -16_384:int-little-size(16),
  >>
  assert sc7a20.decode(bytes) == Ok(#(0, 0, 1000))
}

pub fn decode_y_toward_top_test() {
  let bytes = <<
    0:int-little-size(16),
    16_384:int-little-size(16),
    0:int-little-size(16),
  >>
  assert sc7a20.decode(bytes) == Ok(#(0, 1000, 0))
}

pub fn decode_x_toward_left_test() {
  let bytes = <<
    16_384:int-little-size(16),
    0:int-little-size(16),
    0:int-little-size(16),
  >>
  assert sc7a20.decode(bytes) == Ok(#(-1000, 0, 0))
}

pub fn decode_unit_magnitude_test() {
  let bytes = <<
    -1120:int-little-size(16),
    13_936:int-little-size(16),
    -9184:int-little-size(16),
  >>
  let assert Ok(#(x, y, z)) = sc7a20.decode(bytes)
  let magnitude = float.square_root(int.to_float(x * x + y * y + z * z))
  let assert Ok(mag) = magnitude
  assert mag >=. 970.0
  assert mag <=. 1030.0
}

pub fn average_none_adopts_sample_test() {
  assert sc7a20.average(None, #(100, 200, 300)) == #(100, 200, 300)
}

pub fn average_one_step_quarter_test() {
  assert sc7a20.average(Some(#(0, 0, 0)), #(100, 200, 300)) == #(25, 50, 75)
}

pub fn average_settles_test() {
  let settled = settle(40, #(0, 0, 0), #(100, 200, 300))
  let #(x, y, z) = settled
  assert int.absolute_value(x - 100) <= 3
  assert int.absolute_value(y - 200) <= 3
  assert int.absolute_value(z - 300) <= 3
  assert settle(80, #(0, 0, 0), #(100, 200, 300)) == settled
}

pub fn orientation_face_up_test() {
  assert sc7a20.orientation(#(0, 0, 1000)) == #(0, 0)
}

pub fn orientation_roll_positive_test() {
  assert sc7a20.orientation(#(-1000, 0, 0)) == #(90, 0)
  assert sc7a20.orientation(#(-500, 0, 866)) == #(30, 0)
}

pub fn orientation_pitch_positive_test() {
  assert sc7a20.orientation(#(0, 1000, 0)) == #(0, 90)
  assert sc7a20.orientation(#(0, 500, 866)) == #(0, 30)
}

pub fn orientation_pitch_negative_test() {
  assert sc7a20.orientation(#(0, -500, 866)) == #(0, -30)
}

pub fn step_flat_stays_put_test() {
  let body = scene.rest()
  assert scene.step(body, 0, 0) == body
}

pub fn step_right_tilt_moves_right_test() {
  let after = scene.step(scene.rest(), -500, 0)
  assert after.x > scene.start_x
  assert after.vx > 0
}

pub fn step_top_raised_moves_down_test() {
  let after = scene.step(scene.rest(), 0, 500)
  assert after.y > scene.start_y
  assert after.vy > 0
}

pub fn step_hits_right_edge_and_stops_test() {
  let started = scene.Body(scene.max_x - 2, scene.start_y, 8, 0)
  let after = scene.step(started, -800, 0)
  assert after.x == scene.max_x
  assert after.vx == 0
}

pub fn step_diagonal_moves_both_axes_test() {
  // Mild 45° split (~350 mg each) used to die under integer friction.
  let after = scene.step(scene.rest(), -350, 350)
  assert after.x > scene.start_x
  assert after.y > scene.start_y
  assert after.vx > 0
  assert after.vy > 0
}

fn settle(n: Int, acc: sc7a20.Mg, sample: sc7a20.Mg) -> sc7a20.Mg {
  case n {
    0 -> acc
    _ -> settle(n - 1, sc7a20.average(Some(acc), sample), sample)
  }
}
