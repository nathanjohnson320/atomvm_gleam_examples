import atomvm_gleam/display
import atomvm_gleam/gpio
import atomvm_gleam/spi
import counter_scene
import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result

const width = 320

const height = 240

/// Bounce window after accepting a press.
const debounce_ms = 200

type Message {
  GpioInterrupt
}

type State {
  State(display: display.Display, gpio: gpio.Gpio, count: Int)
}

pub fn start() -> Nil {
  let assert Ok(_) =
    actor.new_with_initialiser(5000, initialise)
    |> actor.on_message(handle_message)
    |> actor.start
  process.sleep_forever()
}

fn initialise(
  _subject: process.Subject(Message),
) -> Result(actor.Initialised(State, Message, Nil), String) {
  // Open hardware in this process so `{gpio_interrupt, Pin}` is delivered here.
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

  use pins <- result.try(
    gpio.open()
    |> or_log("GPIO open failed", gpio.error_to_string),
  )

  // Matching 065_boot: open the driver, then attach_interrupt on pin 0.
  use Nil <- result.try(
    gpio.attach_interrupt(gpio.pin(0), gpio.Falling)
    |> or_log("GPIO attach_interrupt failed", gpio.error_to_string),
  )

  display.update(screen, counter_scene.render(width, height, 0))

  let tag = atom.create("gpio_interrupt")
  let selector =
    process.new_selector()
    |> process.select_record(tag, 1, fn(_: Dynamic) { GpioInterrupt })

  Ok(
    actor.initialised(State(display: screen, gpio: pins, count: 0))
    |> actor.selecting(selector)
    |> actor.returning(Nil),
  )
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

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    GpioInterrupt -> {
      let count = state.count + 1
      io.println("Boot pressed: " <> int.to_string(count))
      display.update(state.display, counter_scene.render(width, height, count))
      // Block through the bounce window (AtomVM-safe). Flush any edges that
      // queued while we slept.
      process.sleep(debounce_ms)
      flush_interrupts()
      // gpio stays in state so the port is not dropped.
      actor.continue(State(..state, count:))
    }
  }
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
