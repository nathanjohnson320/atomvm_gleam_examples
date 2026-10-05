# Exercise 2, in Gleam: read the temperature sensor

Same badge program as `02_temperature`, written in Gleam. Gleam compiles to
BEAM, and the [Orbital fork](https://github.com/nathanjohnson320/orbital)
packs those BEAM files into an `.avm` file and flashes it.

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in `.tool-versions`.

Assumes AtomVM is already installed on the badge, see exercise 1. Gleam does
not replace that firmware.

## The application

`src/temperature.gleam` is the loop, `src/tmp103.gleam` the sensor driver.
`temperature.start` is the entry point. Orbital finds it because the package
name in `gleam.toml` is `temperature`.

I²C open and read go through the
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam) package (`atomvm_gleam/i2c`).

## The bus

One I²C bus, shared by the TMP103, the accelerometer, the touch controller and
the Qwiic connector. Every device answers to its own address, and inside each
device registers are selected by a pointer byte: **bus → address → register**.

```gleam
i2c.open(i2c.Config(scl: 10, sda: 11, clock_speed_hz: 100_000))
```

`clock_speed_hz` is not optional: without it the driver refuses to open the bus.

## The sensor

The badge fits a **TMP103A** at address `0x70`. Four registers, pointer `0x00`
is the temperature: a single byte, 1 LSB = 1 °C, two's complement. The loop
converts to Fahrenheit, matching the Elixir exercise.

## Flash and monitor

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

```text
Temperature: 75.20 °F
Temperature: 75.20 °F
Temperature: 77.00 °F
```

Pinch the sensor between two fingers and the value climbs.

## Good to know

* **It reads higher than the room.** The TMP103 sits on the PCB next to the
  ESP32-S3, so it measures the board, not the air.
* **The value repeats on purpose.** The TMP103 converts at 0.25 Hz by default
  while the loop prints every second.
* Badge not detected: hold **BOOT**, tap **RESET**, release **BOOT**, retry.
* `gleam run -m orbital monitor --timeout 0` reads until Ctrl+C, pressed twice.
