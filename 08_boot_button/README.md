# Exercise 8, in Gleam: count boot-button presses

Same badge program as `065_boot`, written in Gleam. Gleam compiles to BEAM,
and the [Orbital fork](https://github.com/nathanjohnson320/orbital)
packs those BEAM files into an `.avm` file and flashes it.

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in `.tool-versions`.

Assumes the AtomGL image from exercise 1 is already installed on the badge.
Gleam does not replace that firmware.

## The application

`src/boot_button.gleam` starts a [`gleam_otp`](https://github.com/gleam-lang/otp)
actor — the Gleam counterpart of the Elixir GenServer in `065_boot`. The actor
opens SPI and the display port via the
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam) package, arms GPIO 0 with
`attach_interrupt(gpio.pin(0), …)` (same shape as `065_boot`), then handles each
`{gpio_interrupt, Pin}` message: bump the count, redraw, sleep 200 ms for
debounce, flush bounced edges. `boot_button.start` is the entry point. Orbital
finds it because the package name in `gleam.toml` is `boot_button`. After the
actor starts, `start` parks forever so AtomVM does not exit.

`src/counter_scene.gleam` builds the display list.

Badge pin and panel options stay in the application. Call `open` from inside
the actor so interrupt messages land in that process.

The scene is not an `avm_scene` process. That library is Elixir, so it is not
a Gleam dependency. After each press the actor pushes the display list
through `atomvm_gleam/display.update`.

GPIO 0 is the boot button. A falling edge wakes the actor. A short debounce
sleep drops the mechanical bounce that follows.

## Flash and monitor

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor --timeout 0
```

`flash` reads the badge's partition table and writes the application at the
`main.avm` address (`0x2b8000` on the exercise 1 image). Esptool auto-detects
the serial port. `monitor --timeout 0` reads until Ctrl+C, pressed twice, so
you can press the button at leisure.

```text
Boot pressed: 1
Boot pressed: 2
```

The display shows the total and a row of sixteen pips that fill and wrap while
the number keeps climbing.

## Good to know

* Badge not detected: hold **BOOT**, tap **RESET**, release **BOOT**, retry.
* Several boards connected: add `--port /dev/ttyACM0` to both commands.
* Pressing **BOOT** while plugged in can also put the board into download
  mode on some cables; if flash stops working, tap **RESET** and try again.
