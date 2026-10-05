# Exercise 5, in Gleam: rainbows on the RGB LEDs

Same badge program as `05_neopixel`, written in Gleam. Gleam compiles to BEAM,
and the [Orbital fork](https://github.com/nathanjohnson320/orbital)
packs those BEAM files into an `.avm` file and flashes it.

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in `.tool-versions`.

Assumes AtomVM is already installed on the badge, see exercise 1.

## The application

`src/rainbow.gleam` computes colours and runs the loop, `src/sk6812.gleam`
turns them into a bitstream through [`atomvm_gleam/spi`](https://github.com/nathanjohnson320/atomvm_gleam).
`rainbow.start` is the entry point. Orbital finds it because the package name
in `gleam.toml` is `rainbow`.

## Why SPI

These LEDs have no clock line. Each bit is a pulse of fixed width whose high
part carries the value: short is a zero, long is a one. The SPI peripheral
clocks out a prepared waveform in hardware. At 3.2 MHz one SPI bit lasts about
312 ns, so each LED bit is sent as four SPI bits:

```text
LED bit 0  ->  0b1000
LED bit 1  ->  0b1100
```

`sclk` and `cs` are -1 because the chain uses neither, and `miso` is omitted.
Only the data line on GPIO 14 matters.

## The rainbow

The four LEDs sit an equal distance apart on the colour wheel. Colours are
integer HSV. Each LED's brightness is the low 8 bits of `atomvm:random/0`.

## Flash and monitor

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor --timeout 10
```

Nothing is printed. The LEDs are the output.
