# AtomVM Gleam examples

Gleam programs for the badge, running on [AtomVM](https://www.atomvm.net/). Each numbered directory is a small exercise: console output, sensors, display, Wi-Fi, LEDs, keyboard, and so on.

Gleam compiles to BEAM. [Orbital](https://github.com/nathanjohnson320/orbital) packs those BEAM files into an `.avm` and flashes it. Hardware access goes through [`atomvm_gleam`](https://github.com/nathanjohnson320/atomvm_gleam).

## Requirements

- Gleam 1.18.1 and Erlang/OTP 27+ (pinned in each example’s `.tool-versions`)
- AtomVM already on the badge (Gleam does not replace that firmware)
- Orbital for flash and monitor

Install AtomVM once (from any example that depends on Orbital):

```sh
cd 01_hello_world
gleam run -m orbital info
gleam run -m orbital install
```

## Examples

| Directory | What it does |
|-----------|----------------|
| [`01_hello_world`](01_hello_world) | Console “hello” loop |
| [`02_temperature`](02_temperature) | Read the TMP103 over I²C |
| [`03_atomgl`](03_atomgl) | Show temperature on the display |
| [`04_wifi_mqtt`](04_wifi_mqtt) | Publish temperature over Wi-Fi / MQTT |
| [`05_neopixel`](05_neopixel) | Rainbow on the RGB LEDs |
| [`06_keyboard`](06_keyboard) | Matrix keyboard with interrupts |
| [`07_analog`](07_analog) | Battery / USB voltage via ADC |
| [`08_boot_button`](08_boot_button) | Count boot-button presses on screen |
| [`09_images`](09_images) | PNG/GIF art on AtomGL (decoded on the host) |

Shared helpers:

- [`atomgl_image`](atomgl_image) — sprite / display-list helpers for AtomGL
- [`atomgl_image_dump`](atomgl_image_dump) — host tool to turn PNG/GIF into badge assets

Each example has its own README with pin notes and flash steps.

## Flash and monitor

From an example directory:

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

## Wi-Fi / MQTT

For [`04_wifi_mqtt`](04_wifi_mqtt), put your network details in `src/config.gleam` locally. The repo keeps placeholders only — do not commit real SSIDs or passwords.
