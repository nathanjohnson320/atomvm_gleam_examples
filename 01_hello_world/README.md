# Exercise 1, in Gleam: console hello world

Same badge program as `01_hello_world`, written in Gleam. Gleam compiles to
BEAM, and the [Orbital fork](https://github.com/nathanjohnson320/orbital)
packs those BEAM files into an `.avm` file and flashes it.

Requires Gleam 1.18.1 and Erlang/OTP 27+. This directory pins both in `.tool-versions`.

Assumes AtomVM is already installed on the badge. Gleam does not replace
that firmware. To install AtomVM with Orbital:

```sh
gleam run -m orbital info
gleam run -m orbital install
```

## The application

`src/hello_world.gleam` is the whole application. `hello_world.start` is the
entry point. Orbital finds it because the package name in `gleam.toml` is
`hello_world`.

`start` must not return: when it does, AtomVM stops the application and the
board goes to sleep. The loop keeps it alive.

## Flash and monitor

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

`flash` reads the badge's partition table and writes the application at the
`main.avm` address (`0x2b8000` on the exercise 1 image). Esptool auto-detects
the serial port. `monitor` reads the console for 10 seconds.

```text
Hello from AtomVM!
Still alive, 0 seconds
Still alive, 1 seconds
```

## Good to know

* Badge not detected: hold **BOOT**, tap **RESET**, release **BOOT**, retry.
* Several boards connected: add `--port /dev/ttyACM0` to both commands.
* `gleam run -m orbital monitor --timeout 0` reads until Ctrl+C, pressed twice.
