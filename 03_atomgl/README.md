# Exercise 3, in Gleam: show the temperature on the display

Same badge program as `03_atomgl`, written in Gleam. Gleam compiles to BEAM,
and [Orbital](https://github.com/nathanjohnson320/orbital) packs those BEAM files into an
`.avm` file for AtomVM.

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in `.tool-versions`.

Assumes the AtomGL image from exercise 1 is already installed on the badge.
Gleam does not replace that firmware.

## The application

`src/display.gleam` opens SPI and the display port via the
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam) package, opens the TMP103 over I²C,
and runs the loop. `src/temperature_scene.gleam` builds the display list, and
`src/tmp103.gleam` converts the sensor reading. `display.start` is the entry
point. Orbital finds it because the package name in `gleam.toml` is `display`.

Badge pin and panel options stay in the application.
`src/tmp103_ffi.erl` is a small Erlang side for I²C open and the Celsius
read. Other exercises use `atomvm_gleam/i2c` for the same bus.

The scene is not an `avm_scene` process. That library is Elixir, so it is not
a Gleam dependency. The loop pushes the display list through
`atomvm_gleam/display.update`.

## Build, flash, and monitor

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

`flash` reads the badge's partition table and writes the application at the
`main.avm` address (`0x2b8000` on the exercise 1 image). Esptool auto-detects
the serial port. `monitor` reads the console for 10 seconds. The port is
chosen when only one USB serial device is connected.

```sh
gleam run -m orbital monitor --port /dev/ttyACM0 --timeout 30
```

`--timeout 0` keeps reading until Ctrl+C, pressed twice. `--no-reset` leaves
the board running instead of resetting it to show the boot log. The console
baud is 115200.
