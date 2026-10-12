import atomvm_gleam/adc
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{None, Some}
import gleam/result

const battery_pin = 1

const vbus_pin = 2

/// Both rails reach the ADC through an even divider, so the pin sees half.
const divider = 2

/// Averaged per reading. The ADC is noisy and a battery moves slowly.
const samples = 64

const interval_ms = 2000

/// Working range of the cell, in millivolts.
const empty = 3300

const full = 4200

/// VBUS at or above this means USB is supplying power.
const usb_present_mv = 4000

pub fn start() -> Nil {
  case open() {
    Error(message) -> io.println(message)
    Ok(#(unit, battery, vbus)) -> loop(unit, battery, vbus)
  }
}

fn open() -> Result(#(adc.Unit, adc.Channel, adc.Channel), String) {
  use unit <- result.try(
    adc.init()
    |> result.map_error(fn(error) {
      "ADC init failed: " <> adc.error_to_string(error)
    }),
  )
  use battery <- result.try(acquire(unit, battery_pin))
  use vbus <- result.try(acquire(unit, vbus_pin))
  Ok(#(unit, battery, vbus))
}

fn acquire(unit: adc.Unit, pin: Int) -> Result(adc.Channel, String) {
  adc.acquire(pin, unit, adc.BitMax, adc.Db12)
  |> result.map_error(fn(error) {
    "ADC acquire failed: " <> adc.error_to_string(error)
  })
}

fn loop(unit: adc.Unit, battery: adc.Channel, vbus: adc.Channel) -> Nil {
  case read_rail(unit, battery), read_rail(unit, vbus) {
    Ok(battery_mv), Ok(vbus_mv) -> io.println(format_line(battery_mv, vbus_mv))
    Error(message), _ -> io.println(message)
    _, Error(message) -> io.println(message)
  }
  process.sleep(interval_ms)
  loop(unit, battery, vbus)
}

/// `sample_with` returns millivolts at the pin, which is half the rail.
fn read_rail(unit: adc.Unit, channel: adc.Channel) -> Result(Int, String) {
  use reading <- result.try(
    adc.sample_with(
      channel,
      unit,
      adc.SampleOptions(raw: True, voltage: True, samples:),
    )
    |> result.map_error(fn(error) {
      "ADC sample failed: " <> adc.error_to_string(error)
    }),
  )
  case reading.millivolts {
    Some(millivolts) -> Ok(millivolts * divider)
    None -> Error("ADC sample failed: missing voltage")
  }
}

fn format_line(battery_mv: Int, vbus_mv: Int) -> String {
  "battery "
  <> int.to_string(battery_mv)
  <> " mV ("
  <> int.to_string(percent(battery_mv))
  <> "%)   vbus "
  <> int.to_string(vbus_mv)
  <> " mV   usb "
  <> bool_label(usb_present(vbus_mv))
}

/// Cell state of charge from rail millivolts. 3300 is empty, 4200 is full.
pub fn percent(millivolts: Int) -> Int {
  case millivolts <= empty {
    True -> 0
    False ->
      case millivolts >= full {
        True -> 100
        False -> { millivolts - empty } * 100 / { full - empty }
      }
  }
}

/// Whether VBUS millivolts mean USB is supplying power.
pub fn usb_present(vbus_millivolts: Int) -> Bool {
  vbus_millivolts >= usb_present_mv
}

fn bool_label(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
