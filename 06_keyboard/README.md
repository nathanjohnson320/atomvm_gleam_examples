# Exercise 6, in Gleam: read the keyboard with interrupts

Same badge program as `06_keyboard`, written in Gleam. Gleam compiles to BEAM,
and the [Orbital fork](https://github.com/nathanjohnson320/orbital/tree/flash-offset-and-monitor)
packs those BEAM files into an `.avm` file and flashes it.

Requires Gleam 1.18.1. This directory pins it in `.tool-versions`.

Assumes the AtomGL image from exercise 1 is already installed on the badge.
Gleam does not replace that firmware.

## The application

`src/keyboard.gleam` starts a [`gleam_otp`](https://github.com/gleam-lang/otp)
actor — the Gleam counterpart of the Elixir GenServer in `06_keyboard`. The
actor opens the GPIO port via the local
[`atomvm_gleam`](../packages/atomvm_gleam) package (same shape as
`08_boot_button`) so `{gpio_interrupt, Pin}` lands in that process.
`keyboard.start` is the entry point. Orbital finds it because the package name
in `gleam.toml` is `keyboard`. After the actor starts, `start` parks forever
so AtomVM does not exit.

`src/keymap.gleam` says what each matrix position means. The layout can change
without touching the electrical code.

## How a matrix works

78 keys on 19 pins, because each key sits where one row crosses one column.

Columns are inputs held high by internal pull-ups. Drive one row low and any
key closed in that row pulls its own column low with it. Read all thirteen
columns, move to the next row, repeat.

Rows are open drain, so writing high releases the line rather than driving it.
The badge has no diodes: if two rows were driven hard and a key shorted them
together, they would fight. ROW5 (GPIO45) boots with an internal pull-down, so
its pull-up has to be set explicitly.

## Waking on a key

Scanning 50 times a second to learn that nobody is typing is a waste. Hold
every row low at once and the matrix becomes one big button: closing any key
pulls its own column down. A falling-edge interrupt on all thirteen columns
wakes the actor. Idle, that process costs nothing. There is no timer.

The actor has two states, told apart by the keys it last saw:

```text
pressed == []   idle: rows all low, interrupts armed, waiting for a message
pressed != []   active: interrupts off, a Scan message every 20 ms
```

The interrupt says something was pressed, never what. Finding out means
scanning, and scanning drives rows one at a time, which would retrigger the
interrupts just armed. The handler removes them first. Once every key is
released the actor arms them again and goes back to idle.

An interrupt that arrives while keys are already held is an echo of that
scanning, and the actor drops it.

Events are the difference between two scans, so a held key is reported once.
The 20 ms gap also covers contact bounce, which settles well inside one
interval.

## Flash and monitor

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor --timeout 0
```

`flash` reads the badge's partition table and writes the application at the
`main.avm` address (`0x2b8000` on the exercise 1 image). Esptool auto-detects
the serial port. `monitor --timeout 0` reads until Ctrl+C, pressed twice, so
you can type at leisure.

```text
Press a key.
pressed   row 2 col 1  Q
released  row 2 col 1  Q
```

## Good to know

* Badge not detected: hold **BOOT**, tap **RESET**, release **BOOT**, retry.
* Several boards connected: add `--port /dev/ttyACM0` to both commands.
* Pressing **BOOT** while plugged in can also put the board into download
  mode on some cables; if flash stops working, tap **RESET** and try again.
