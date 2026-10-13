/// Marble-style Lucy: lateral accel integrates to velocity; edges stop her.
import atomgl_image/item.{type Item, Rect, scaled}
import atomgl_image/sprite.{type Sprite}
import gleam/int

const background = 0x202020

const width = 320

const height = 240

/// On-screen Lucy size (32×32 sprite at 2×): 320−64 / 240−64 bounds.
pub const max_x = 256

pub const max_y = 176

pub const start_x = 128

pub const start_y = 88

/// Ignore tiny residual tilt so a flat badge does not creep.
const deadzone_mg = 40

/// How hard milli-g push velocity each tick (lower = snappier).
const accel_div = 120

/// Velocity decay per tick: keep `friction_num / friction_den` of speed.
/// Applied to the existing velocity before adding accel so a 1-pixel nudge
/// is not truncated to zero (diagonal tilts split gravity across both axes).
const friction_num = 14

const friction_den = 15

/// Cap so she does not tunnel past an edge in one tick.
const max_speed = 12

pub type Body {
  Body(x: Int, y: Int, vx: Int, vy: Int)
}

pub fn rest() -> Body {
  Body(start_x, start_y, 0, 0)
}

/// Integrate one tick from panel-frame milli-g (`x` right, `y` top).
///
/// Gravity toward a lowered edge accelerates Lucy that way. Hitting an edge
/// zeroes that axis so she parks against the bezel.
pub fn step(body: Body, x_mg: Int, y_mg: Int) -> Body {
  let Body(x:, y:, vx:, vy:) = body
  let ax = accel(-x_mg)
  // Panel +y is toward the top; screen +y is toward the bottom.
  let ay = accel(y_mg)
  let vx = clamp_speed(vx * friction_num / friction_den + ax)
  let vy = clamp_speed(vy * friction_num / friction_den + ay)
  let #(x, vx) = slide(x, vx, 0, max_x)
  let #(y, vy) = slide(y, vy, 0, max_y)
  Body(x, y, vx, vy)
}

/// First item is on top; background rect stays last.
pub fn render(lucy: Sprite, body: Body) -> List(Item) {
  [
    scaled(body.x, body.y, 2, background, lucy),
    Rect(0, 0, width, height, background),
  ]
}

fn accel(mg: Int) -> Int {
  case int.absolute_value(mg) < deadzone_mg {
    True -> 0
    False -> mg / accel_div
  }
}

fn clamp_speed(v: Int) -> Int {
  case v > max_speed {
    True -> max_speed
    False ->
      case v < -max_speed {
        True -> -max_speed
        False -> v
      }
  }
}

fn slide(pos: Int, vel: Int, min: Int, max: Int) -> #(Int, Int) {
  let next = pos + vel
  case next < min {
    True -> #(min, 0)
    False ->
      case next > max {
        True -> #(max, 0)
        False -> #(next, vel)
      }
  }
}
