/// Keyboard + display actor: arrow keys browse JPG thumbs on the GoPro.
import atomgl_image/jpeg
import atomgl_image/sprite.{type Sprite}
import atomvm_gleam/display
import atomvm_gleam/gpio
import gallery_scene
import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
import gopro.{type MediaItem, type Snapshot}
import keymap

const width = 320

const height = 240

/// Preview (DC-only) fit under the status bar. Thumbnail HTTP is already the
/// smallest GoPro image API; screennail is larger.
const max_thumb_w = 240

const max_thumb_h = 160

const rows = [38, 39, 40, 41, 42, 45]

const cols = [37, 36, 35, 48, 34, 33, 47, 46, 21, 18, 17, 16, 15]

const interval_ms = 20

/// Refresh camera status while idle (not on every key).
const status_interval_ms = 5000

type Message {
  GpioInterrupt
  Scan
  RefreshStatus
  /// Kick off HTTP + JPEG in a child process (actor stays responsive to keys).
  LoadCurrent
  ThumbReady(Int, Result(Sprite, String))
}

type State {
  State(
    display: display.Display,
    gpio: gpio.Gpio,
    pressed: List(#(Int, Int)),
    subject: process.Subject(Message),
    items: List(MediaItem),
    index: Int,
    /// Bumped on each navigate/load so stale ThumbReady results are ignored.
    load_gen: Int,
    snapshot: Option(Snapshot),
    thumb: Option(Sprite),
    thumb_note: Option(String),
  )
}

pub fn start(
  screen: display.Display,
  items: List(MediaItem),
  snapshot: Option(Snapshot),
) -> Nil {
  let assert Ok(_) =
    actor.new_with_initialiser(5000, fn(subject) {
      initialise(subject, screen, items, snapshot)
    })
    |> actor.on_message(handle_message)
    |> actor.start
  process.sleep_forever()
}

fn initialise(
  subject: process.Subject(Message),
  screen: display.Display,
  items: List(MediaItem),
  snapshot: Option(Snapshot),
) -> Result(actor.Initialised(State, Message, Nil), String) {
  use pins <- result.try(
    gpio.open()
    |> or_log("GPIO open failed", gpio.error_to_string),
  )
  use Nil <- result.try(setup())

  let state =
    State(
      display: screen,
      gpio: pins,
      pressed: [],
      subject:,
      items:,
      index: 0,
      load_gen: 0,
      snapshot:,
      thumb: None,
      thumb_note: Some("Loading thumb..."),
    )
  redraw(state)
  let _ = process.send_after(subject, 0, LoadCurrent)
  let _ = process.send_after(subject, status_interval_ms, RefreshStatus)

  let tag = atom.create("gpio_interrupt")
  let selector =
    process.new_selector()
    |> process.select(subject)
    |> process.select_record(tag, 1, fn(_: Dynamic) { GpioInterrupt })

  Ok(
    actor.initialised(idle(state))
    |> actor.selecting(selector)
    |> actor.returning(Nil),
  )
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
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
    LoadCurrent -> actor.continue(start_thumb_load(state))
    ThumbReady(gen, result) -> {
      case gen == state.load_gen {
        False -> actor.continue(state)
        True -> {
          let state = case result {
            Ok(sprite) -> {
              io.println("thumb decode ok")
              State(..state, thumb: Some(sprite), thumb_note: None)
            }
            Error(message) -> {
              io.println("thumb: " <> message)
              State(..state, thumb: None, thumb_note: Some(message))
            }
          }
          redraw(state)
          actor.continue(state)
        }
      }
    }
    RefreshStatus -> {
      let snapshot = case gopro.fetch_snapshot() {
        Ok(s) -> Some(s)
        Error(_) -> state.snapshot
      }
      let state = State(..state, snapshot:)
      redraw(state)
      let _ =
        process.send_after(state.subject, status_interval_ms, RefreshStatus)
      actor.continue(state)
    }
  }
}

fn scan_and_handle(state: State) -> State {
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

fn on_press(state: State, key: #(Int, Int)) -> State {
  let #(row, col) = key
  case keymap.label(row, col) {
    Some("Left") | Some("Up") -> {
      io.println("key Left/Up")
      step(state, -1)
    }
    Some("Right") | Some("Down") -> {
      io.println("key Right/Down")
      step(state, 1)
    }
    _ -> state
  }
}

fn step(state: State, delta: Int) -> State {
  let count = list.length(state.items)
  case count == 0 {
    True -> state
    False -> {
      let index = gopro.wrap_index(state.index + delta, count)
      let load_gen = state.load_gen + 1
      let state =
        State(
          ..state,
          index:,
          load_gen:,
          thumb: None,
          thumb_note: Some("Loading thumb..."),
        )
      redraw(state)
      let _ = process.send_after(state.subject, 0, LoadCurrent)
      state
    }
  }
}

fn start_thumb_load(state: State) -> State {
  case list.drop(state.items, state.index) |> list.first {
    Error(Nil) -> {
      let state = State(..state, thumb: None, thumb_note: Some("No files"))
      redraw(state)
      state
    }
    Ok(item) -> {
      let gen = state.load_gen
      let reply_to = state.subject
      io.println("thumb GET " <> item.path)
      let _ =
        process.spawn(fn() {
          process.send(reply_to, ThumbReady(gen, fetch_and_decode(item.path)))
        })
      state
    }
  }
}

fn fetch_and_decode(path: String) -> Result(Sprite, String) {
  use jpeg_bytes <- result.try(
    gopro.fetch_thumbnail(path)
    |> result.map_error(fn(message) { message }),
  )
  let n = bit_array.byte_size(jpeg_bytes)
  io.println("thumb " <> int.to_string(n) <> " bytes, decoding...")
  jpeg.decode_preview(jpeg_bytes, max_thumb_w, max_thumb_h)
  |> result.replace_error("JPEG decode failed")
}

fn redraw(state: State) -> Nil {
  let view = case state.items {
    [] -> gallery_scene.Empty
    items -> {
      let filename = case list.drop(items, state.index) |> list.first {
        Ok(item) -> gopro.short_filename(item.path)
        Error(Nil) -> ""
      }
      gallery_scene.Gallery(
        snapshot: state.snapshot,
        index: state.index,
        count: list.length(items),
        filename:,
        thumb: state.thumb,
        thumb_note: state.thumb_note,
      )
    }
  }
  display.update(state.display, gallery_scene.render(width, height, view))
}

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

fn idle(state: State) -> State {
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
