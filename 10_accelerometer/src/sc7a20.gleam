/// SC7A20 accelerometer: init/read over I²C, decode, EMA, and tilt orientation.
import atomvm_gleam/i2c.{type Bus}
import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam_community/maths.{atan2, nth_root, pi}

const address = 0x19

const ctrl_reg1 = 0x20

const ctrl_reg1_25hz_xyz = 0x37

const ctrl_reg3 = 0x22

const ctrl_reg3_int_off = 0x00

const ctrl_reg4 = 0x23

const ctrl_reg4_bdu_2g = 0x80

/// OUT_X_L with auto-increment bit set (`0x28 | 0x80`).
const out_x_l_auto = 0xA8

pub type Mg =
  #(Int, Int, Int)

pub type Orientation =
  #(Int, Int)

/// Enable 25 Hz XYZ, ±2g BDU, INT1 off. Polled reads only.
pub fn init(bus: Bus) -> Result(Nil, String) {
  use _ <- result.try(write_reg(bus, ctrl_reg1, ctrl_reg1_25hz_xyz))
  use _ <- result.try(write_reg(bus, ctrl_reg4, ctrl_reg4_bdu_2g))
  write_reg(bus, ctrl_reg3, ctrl_reg3_int_off)
}

pub fn read(bus: Bus, previous: Option(Mg)) -> Result(Mg, String) {
  use data <- result.try(
    i2c.read_bytes(bus, address, out_x_l_auto, 6)
    |> result.map_error(fn(error) {
      "SC7A20 read failed: " <> i2c.error_to_string(error)
    }),
  )
  use sample <- result.try(
    decode(data)
    |> result.map_error(fn(_) { "SC7A20 read failed: unexpected payload" }),
  )
  Ok(average(previous, sample))
}

/// Decodes OUT_X_L..OUT_Z_H into milli-g in the panel frame.
pub fn decode(data: BitArray) -> Result(Mg, Nil) {
  case data {
    <<
      x:signed-little-size(16),
      y:signed-little-size(16),
      z:signed-little-size(16),
    >> -> {
      // Sensor faces the back of the board: x and z oppose the panel.
      Ok(#(-to_mg(x), to_mg(y), -to_mg(z)))
    }
    _ -> Error(Nil)
  }
}

/// Exponential moving average, alpha = 1/4, per axis. `None` adopts `sample`.
pub fn average(previous: Option(Mg), sample: Mg) -> Mg {
  case previous {
    None -> sample
    Some(#(px, py, pz)) -> {
      let #(x, y, z) = sample
      #(ema(px, x), ema(py, y), ema(pz, z))
    }
  }
}

/// Roll and pitch in whole degrees. Both zero face-up and level; roll positive
/// with the right edge lowered, pitch positive with the top edge raised.
pub fn orientation(mg: Mg) -> Orientation {
  let #(x, y, z) = mg
  let xf = int.to_float(x)
  let yf = int.to_float(y)
  let zf = int.to_float(z)
  let assert Ok(root) = nth_root(yf *. yf +. zf *. zf, 2)
  let roll = float.round(atan2(0.0 -. xf, root) *. 180.0 /. pi())
  let pitch = float.round(atan2(yf, zf) *. 180.0 /. pi())
  #(roll, pitch)
}

fn write_reg(bus: Bus, register: Int, value: Int) -> Result(Nil, String) {
  i2c.write_bytes(bus, address, register, <<value>>)
  |> result.map_error(fn(error) {
    "SC7A20 init failed: " <> i2c.error_to_string(error)
  })
}

fn to_mg(raw: Int) -> Int {
  raw * 125 / 2048
}

fn ema(previous: Int, new: Int) -> Int {
  previous + { new - previous } / 4
}

pub fn error_to_string(error: String) -> String {
  "SC7A20 " <> error
}
