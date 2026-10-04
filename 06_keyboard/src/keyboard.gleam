import atomvm_gleam/gpio
import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import keymap

const rows = [38, 39, 40, 41, 42, 45]

const cols = [37, 36, 35, 48, 34, 33, 47, 46, 21, 18, 17, 16, 15]

/// While keys are held, scan again after this many milliseconds. Idle has no
/// timer. Matching the Elixir exercise.
const interval_ms = 20

type Message {
  GpioInterrupt
  Scan
}

type State {
  State(
    gpio: gpio.Gpio,
    pressed: List(#(Int, Int)),
    subject: process.Subject(Message),
  )
}

/// AtomVM entrypoint. The package name in `gleam.toml` is `keyboard`, so this
/// module is the one Orbital marks as the start module.
///
/// Starts an actor (Gleam counterpart of the Elixir GenServer in `06_keyboard`)
/// that owns the GPIO interrupt mailbox, then parks forever so AtomVM does not
/// exit.
pub fn start() -> Nil {
  let assert Ok(_) =
    actor.new_with_initialiser(5000, initialise)
    |> actor.on_message(handle_message)
    |> actor.start
  io.println("Press a key.")
  process.sleep_forever()
}

fn initialise(
  subject: process.Subject(Message),
) -> Result(actor.Initialised(State, Message, Nil), String) {
  // Open hardware in this process so `{gpio_interrupt, Pin}` is delivered here.
  // The port is only needed for interrupts; reads and writes go straight to
  // the NIFs.
  use pins <- result.try(
    gpio.open()
    |> or_log("GPIO open failed", gpio.error_to_string),
  )
  use Nil <- result.try(setup())

  let state = idle(State(gpio: pins, pressed: [], subject:))

  // A custom selector replaces the default one, so the subject must be
  // selected too or `Scan` and the recheck `GpioInterrupt` are discarded.
  let tag = atom.create("gpio_interrupt")
  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_record(tag, 1, fn(_: Dynamic) { GpioInterrupt })

  Ok(
    actor.initialised(state)
    |> actor.selecting(selector)
    |> actor.returning(Nil),
  )
}

/// Map a driver `Result` to `Result(a, String)`, logging on failure.
fn or_log(
  value: Result(a, e),
  message: String,
  explain: fn(e) -> String,
) -> Result(a, String) {
  result.map_error(value, fn(error) {
    io.println(message <> ": " <> explain(error))
    message
  })
}

fn each_ok(
  items: List(a),
  run: fn(a) -> Result(Nil, String),
) -> Result(Nil, String) {
  list.try_fold(items, Nil, fn(_, item) { run(item) })
}

fn setup() -> Result(Nil, String) {
  // Columns idle high. A closed switch is the only thing that pulls one down.
  use Nil <- result.try(
    each_ok(cols, fn(pin) {
      use Nil <- result.try(
        gpio.set_pin_mode(pin, gpio.Input)
        |> or_log("GPIO set_pin_mode failed", gpio.error_to_string),
      )
      gpio.set_pin_pull(pin, gpio.Up)
      |> or_log("GPIO set_pin_pull failed", gpio.error_to_string)
    }),
  )

  // Open drain, so writing high releases a row instead of driving it and two
  // rows can never fight through a closed switch. ROW5 (GPIO45) boots pulled
  // down, so its pull-up has to be set explicitly.
  each_ok(rows, fn(pin) {
    use Nil <- result.try(
      gpio.set_pin_mode(pin, gpio.OutputOd)
      |> or_log("GPIO set_pin_mode failed", gpio.error_to_string),
    )
    use Nil <- result.try(
      gpio.set_pin_pull(pin, gpio.Up)
      |> or_log("GPIO set_pin_pull failed", gpio.error_to_string),
    )
    gpio.digital_write(pin, gpio.PinHigh)
    |> or_log("GPIO digital_write failed", gpio.error_to_string)
  })
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    // Nothing was held, so this is a real key going down: stop listening and
    // start looking. Scanning drives rows one at a time, which would retrigger
    // the interrupts.
    GpioInterrupt ->
      case state.pressed {
        [] -> {
          disarm(state.gpio)
          actor.continue(scan_and_report(state))
        }
        // Something is already held, so this is an echo of our own scanning.
        _ -> actor.continue(state)
      }
    Scan -> actor.continue(scan_and_report(state))
  }
}

/// Presses are `current` minus `previous` (scan order). Releases are
/// `previous` minus `current`. A key in both lists is a hold and is omitted,
/// so it is reported once, on the scan that first saw it.
pub fn changes(
  previous: List(#(Int, Int)),
  current: List(#(Int, Int)),
) -> #(List(#(Int, Int)), List(#(Int, Int))) {
  #(without(current, previous), without(previous, current))
}

fn without(left: List(a), right: List(a)) -> List(a) {
  list.filter(left, fn(item) { !list.contains(right, item) })
}

/// Only the difference between two scans is news: the rest is a key being
/// held down.
fn scan_and_report(state: State) -> State {
  let pressed = scan()
  let #(presses, releases) = changes(state.pressed, pressed)
  list.each(presses, fn(key) { report("pressed ", key) })
  list.each(releases, fn(key) { report("released", key) })

  case pressed {
    [] -> idle(state)
    _ -> {
      // The timer reference is only needed to cancel. This scan always runs.
      let _ = process.send_after(state.subject, interval_ms, Scan)
      State(..state, pressed:)
    }
  }
}

fn report(event: String, key: #(Int, Int)) -> Nil {
  let #(row, col) = key
  let name = case keymap.label(row, col) {
    Some(label) -> label
    None -> "unmapped"
  }
  io.println(
    event
    <> "  row "
    <> int.to_string(row)
    <> " col "
    <> int.to_string(col)
    <> "  "
    <> name,
  )
}

/// Rows all low, so closing any key pulls its own column down and fires an
/// interrupt. The process now costs nothing until one arrives.
fn idle(state: State) -> State {
  all_rows(gpio.PinLow)
  flush_interrupts()
  arm(state.gpio)

  // A key pressed between the last scan and arming raised no edge, so look
  // once. Reading columns drives no rows and cannot raise an edge itself.
  case any_column_low() {
    True -> actor.send(state.subject, GpioInterrupt)
    False -> Nil
  }

  State(..state, pressed: [])
}

fn arm(pins: gpio.Gpio) -> Nil {
  list.each(cols, fn(pin) {
    let _ =
      gpio.set_int(pins, pin, gpio.Falling)
      |> or_log("GPIO set_int failed", gpio.error_to_string)
  })
}

fn disarm(pins: gpio.Gpio) -> Nil {
  list.each(cols, fn(pin) {
    let _ =
      gpio.remove_int(pins, pin)
      |> or_log("GPIO remove_int failed", gpio.error_to_string)
  })
}

/// Interrupts raised by our own row driving are not news either.
fn flush_interrupts() -> Nil {
  let tag = atom.create("gpio_interrupt")
  case
    process.new_selector()
    |> process.select_record(tag, 1, fn(_: Dynamic) { Nil })
    |> process.selector_receive(0)
  {
    Ok(_) -> flush_interrupts()
    Error(Nil) -> Nil
  }
}

fn any_column_low() -> Bool {
  list.any(cols, fn(pin) {
    case gpio.digital_read(pin) {
      Ok(gpio.PinLow) -> True
      _ -> False
    }
  })
}

fn all_rows(level: gpio.Level) -> Nil {
  list.each(rows, fn(pin) {
    let _ = gpio.digital_write(pin, level)
  })
}

/// Drive one row low at a time and see which columns follow it down.
fn scan() -> List(#(Int, Int)) {
  all_rows(gpio.PinHigh)

  let keys =
    list.index_map(rows, fn(pin, row) {
      let _ = gpio.digital_write(pin, gpio.PinLow)
      let closed = closed_columns(row)
      let _ = gpio.digital_write(pin, gpio.PinHigh)
      closed
    })
    |> list.flatten

  all_rows(gpio.PinLow)
  keys
}

fn closed_columns(row: Int) -> List(#(Int, Int)) {
  list.index_map(cols, fn(pin, col) {
    case gpio.digital_read(pin) {
      Ok(gpio.PinLow) -> [#(row, col)]
      _ -> []
    }
  })
  |> list.flatten
}
