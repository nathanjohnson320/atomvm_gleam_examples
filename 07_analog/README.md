# Exercise 7, in Gleam: read the battery voltage

Same badge program as `07_analog`, written in Gleam. Gleam compiles to BEAM,
and the [Orbital fork](https://github.com/nathanjohnson320/orbital)
packs those BEAM files into an `.avm` file and flashes it.

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in `.tool-versions`.

Assumes AtomVM is already installed on the badge, see exercise 1. Gleam does
not replace that firmware.

## The application

`src/power.gleam` is the whole thing. `power.start` is the entry point.
Orbital finds it because the package name in `gleam.toml` is `power`.

ADC init, acquire, and sample go through the
[`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam) package (`atomvm_gleam/adc`).

## The ADC

Two rails are wired to the ADC, each through an even divider: the battery on
GPIO1 and USB VBUS on GPIO2. A channel is acquired once, then sampled:

```gleam
use unit <- result.try(adc.init())
use battery <- result.try(adc.acquire(1, unit, adc.BitMax, adc.Db12))

use reading <- result.try(
  adc.sample_with(
    battery,
    unit,
    adc.SampleOptions(raw: True, voltage: True, samples: 64),
  ),
)
```

Three things are worth knowing about that call:

* `Db12` is the attenuation, and it is what makes the full 3.3 V range
  readable. A smaller setting measures a smaller window and clips.
* `samples: 64` averages 64 reads. The ADC is noisy and a battery moves
  slowly, so there is no reason to trust a single one.
* `reading.millivolts` is already calibrated millivolts, measured **at the
  pin**. The divider halves the rail, so the real voltage is that value
  times 2.

Turning volts into a percentage is a guess about the cell, not a measurement:
this one treats 3300 mV as empty and 4200 mV as full.

## Flash and monitor

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor --timeout 20
```

```text
battery 3960 mV (73%)   vbus 5020 mV   usb true
```

## Good to know

* **VBUS always reads about 5 V here.** You are watching the console over the
  same USB cable that supplies it. To see `usb false`, the badge has to run on
  the battery, which means no console.
* Badge not detected: hold **BOOT**, tap **RESET**, release **BOOT**, retry.
* Several boards connected: add `--port /dev/ttyACM0` to both commands.
