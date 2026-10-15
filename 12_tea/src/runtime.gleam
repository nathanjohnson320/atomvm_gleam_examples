//// Badge shell: keyboard + display actor that runs `init` / `update` / `view`
//// and performs `Effect`s (HTTP, timers via Tick, …).

import atomvm_gleam/display
import atomvm_gleam/gpio
import atomvm_gleam/spi
import effect.{type Effect}
import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result

const width = 320

const height = 240

const rows = [38, 39, 40, 41, 42, 45]

const cols = [37, 36, 35, 48, 34, 33, 47, 46, 21, 18, 17, 16, 15]

const interval_ms = 20

const blink_ms = 500

type RuntimeMsg(msg) {
  GpioInterrupt
  Scan
  Tick
  App(msg)
}

type State(model, msg, item) {
  State(
    display: display.Display,
    gpio: gpio.Gpio,
    pressed: List(#(Int, Int)),
    subject: process.Subject(RuntimeMsg(msg)),
    model: model,
    update: fn(model, msg) -> #(model, Effect(msg)),
    view: fn(Int, Int, model) -> List(item),
    key_msg: fn(#(Int, Int)) -> Option(msg),
    tick: msg,
  )
}

pub fn start(
  init: fn() -> #(model, Effect(msg)),
  update: fn(model, msg) -> #(model, Effect(msg)),
  view: fn(Int, Int, model) -> List(item),
  key_msg: fn(#(Int, Int)) -> Option(msg),
  tick: msg,
) -> Nil {
  let assert Ok(_) =
    actor.new_with_initialiser(5000, fn(subject) {
      initialise(subject, init, update, view, key_msg, tick)
    })
    |> actor.on_message(handle_message)
    |> actor.start
  process.sleep_forever()
}

fn initialise(
  subject: process.Subject(RuntimeMsg(msg)),
  init: fn() -> #(model, Effect(msg)),
  update: fn(model, msg) -> #(model, Effect(msg)),
  view: fn(Int, Int, model) -> List(item),
  key_msg: fn(#(Int, Int)) -> Option(msg),
  tick: msg,
) -> Result(
  actor.Initialised(State(model, msg, item), RuntimeMsg(msg), Nil),
  String,
) {
  use bus <- result.try(
    spi.open(
      spi.Params(
        bus_config: spi.BusConfig(
          peripheral: Some("spi2"),
          sclk: Some(5),
          mosi: Some(8),
          miso: Some(9),
          pico: None,
          poci: None,
        ),
        device_config: [],
      ),
    )
    |> or_log("SPI open failed", spi.error_to_string),
  )

  let screen =
    display.open(display.Config(
      compatible: "sitronix,st7789",
      init_seq_type: "alt_gamma_2",
      enable_tft_invon: True,
      width:,
      height:,
      rotation: 3,
      reset: 6,
      dc: 4,
      cs: 7,
      backlight: 3,
      backlight_active: display.Low,
      backlight_enabled: True,
      clock_speed_hz: None,
      spi_host: bus,
    ))

  // Open hardware in this process so `{gpio_interrupt, Pin}` is delivered here.
  use pins <- result.try(
    gpio.open()
    |> or_log("GPIO open failed", gpio.error_to_string),
  )
  use Nil <- result.try(setup())

  let #(model, boot_effect) = init()
  display.update(screen, view(width, height, model))
  let _ = process.send_after(subject, blink_ms, Tick)

  let state =
    idle(State(
      display: screen,
      gpio: pins,
      pressed: [],
      subject:,
      model:,
      update:,
      view:,
      key_msg:,
      tick:,
    ))

  run_effect(state, boot_effect)

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

fn handle_message(
  state: State(model, msg, item),
  message: RuntimeMsg(msg),
) -> actor.Next(State(model, msg, item), RuntimeMsg(msg)) {
  case message {
    GpioInterrupt ->
      case state.pressed {
        [] -> {
          disarm(state.gpio)
          actor.continue(scan_and_handle(state))
        }
        _ -> actor.continue(state)
      }
    Scan -> actor.continue(scan_and_handle(state))
    Tick -> {
      let state = apply(state, state.tick)
      let _ = process.send_after(state.subject, blink_ms, Tick)
      actor.continue(state)
    }
    App(msg) -> actor.continue(apply(state, msg))
  }
}

fn apply(state: State(model, msg, item), msg: msg) -> State(model, msg, item) {
  let #(model, eff) = state.update(state.model, msg)
  display.update(state.display, state.view(width, height, model))
  let state = State(..state, model:)
  run_effect(state, eff)
  state
}

fn run_effect(state: State(model, msg, item), eff: Effect(msg)) -> Nil {
  let subject = state.subject
  effect.perform(eff, fn(msg) { process.send(subject, App(msg)) })
}

fn scan_and_handle(state: State(model, msg, item)) -> State(model, msg, item) {
  let pressed = scan()
  let #(presses, _releases) = changes(state.pressed, pressed)
  let state = list.fold(presses, state, fn(s, key) { on_press(s, key) })

  case pressed {
    [] -> idle(state)
    _ -> {
      let _ = process.send_after(state.subject, interval_ms, Scan)
      State(..state, pressed:)
    }
  }
}

fn on_press(
  state: State(model, msg, item),
  key: #(Int, Int),
) -> State(model, msg, item) {
  case state.key_msg(key) {
    Some(msg) -> apply(state, msg)
    None -> state
  }
}

/// Presses are `current` minus `previous` (scan order).
pub fn changes(
  previous: List(#(Int, Int)),
  current: List(#(Int, Int)),
) -> #(List(#(Int, Int)), List(#(Int, Int))) {
  #(without(current, previous), without(previous, current))
}

fn without(left: List(a), right: List(a)) -> List(a) {
  list.filter(left, fn(item) { !list.contains(right, item) })
}

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
  use Nil <- result.try(
    each_ok(cols, fn(pin) {
      use Nil <- result.try(
        gpio.set_pin_mode(gpio.pin(pin), gpio.Input)
        |> or_log("GPIO set_pin_mode failed", gpio.error_to_string),
      )
      gpio.set_pin_pull(gpio.pin(pin), gpio.Up)
      |> or_log("GPIO set_pin_pull failed", gpio.error_to_string)
    }),
  )

  each_ok(rows, fn(pin) {
    use Nil <- result.try(
      gpio.set_pin_mode(gpio.pin(pin), gpio.OutputOd)
      |> or_log("GPIO set_pin_mode failed", gpio.error_to_string),
    )
    use Nil <- result.try(
      gpio.set_pin_pull(gpio.pin(pin), gpio.Up)
      |> or_log("GPIO set_pin_pull failed", gpio.error_to_string),
    )
    gpio.digital_write(gpio.pin(pin), gpio.PinHigh)
    |> or_log("GPIO digital_write failed", gpio.error_to_string)
  })
}

fn idle(state: State(model, msg, item)) -> State(model, msg, item) {
  all_rows(gpio.PinLow)
  flush_interrupts()
  arm(state.gpio)

  case any_column_low() {
    True -> actor.send(state.subject, GpioInterrupt)
    False -> Nil
  }

  State(..state, pressed: [])
}

fn arm(pins: gpio.Gpio) -> Nil {
  list.each(cols, fn(pin) {
    let _ =
      gpio.set_int(pins, gpio.pin(pin), gpio.Falling)
      |> or_log("GPIO set_int failed", gpio.error_to_string)
  })
}

fn disarm(pins: gpio.Gpio) -> Nil {
  list.each(cols, fn(pin) {
    let _ =
      gpio.remove_int(pins, gpio.pin(pin))
      |> or_log("GPIO remove_int failed", gpio.error_to_string)
  })
}

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
    case gpio.digital_read(gpio.pin(pin)) {
      Ok(gpio.PinLow) -> True
      _ -> False
    }
  })
}

fn all_rows(level: gpio.Level) -> Nil {
  list.each(rows, fn(pin) {
    let _ = gpio.digital_write(gpio.pin(pin), level)
  })
}

fn scan() -> List(#(Int, Int)) {
  all_rows(gpio.PinHigh)

  let keys =
    list.index_map(rows, fn(pin, row) {
      let _ = gpio.digital_write(gpio.pin(pin), gpio.PinLow)
      let closed = closed_columns(row)
      let _ = gpio.digital_write(gpio.pin(pin), gpio.PinHigh)
      closed
    })
    |> list.flatten

  all_rows(gpio.PinLow)
  keys
}

fn closed_columns(row: Int) -> List(#(Int, Int)) {
  list.index_map(cols, fn(pin, col) {
    case gpio.digital_read(gpio.pin(pin)) {
      Ok(gpio.PinLow) -> [#(row, col)]
      _ -> []
    }
  })
  |> list.flatten
}
