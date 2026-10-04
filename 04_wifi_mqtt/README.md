# Exercise 4, in Gleam: publish the temperature over MQTT

Same badge program as `04_wifi_mqtt`, written in Gleam. Gleam compiles to BEAM,
and the [Orbital fork](https://github.com/nathanjohnson320/orbital/tree/flash-offset-and-monitor)
packs those BEAM files into an `.avm` file and flashes it.

Requires Gleam 1.18.1. This directory pins it in `.tool-versions`.

Assumes AtomVM is already installed on the badge, see exercise 1.

## Before flashing

Everything worth changing is in `src/config.gleam`:

```gleam
pub const wifi_ssid = "YOUR_WIFI"
pub const wifi_psk = "YOUR_PASSWORD"
pub const mqtt_host = "test.mosquitto.org"
pub const mqtt_port = 1883
pub const topic_prefix = "goatmire/badge"
```

## The application

`src/publisher.gleam` orchestrates and publishes, `src/wifi.gleam` wraps
`network:wait_for_sta/2`, `src/mqtt.gleam` wraps the vendored
[`amqtt_client`](https://github.com/atomvm/amqtt) Erlang sources in `src/`,
and `src/tmp103.gleam` talks to the sensor over
[`atomvm_gleam/i2c`](../packages/atomvm_gleam). `publisher.start` is the entry
point. Orbital finds it because the package name in `gleam.toml` is
`publisher`.

## Wi-Fi

Associating and DHCP are both covered by `wifi.connect/2`, which calls
`network:wait_for_sta/2` with a 30s timeout. A wrong passphrase typically
shows up as `disconnected`.

## MQTT

`:amqtt_client` is plain Erlang MQTT 3.1.1, packed into the `.avm` with the
rest of the app (the `.erl` files live under `src/`). Connecting is
asynchronous: `mqtt.connect` waits up to 15s for CONNACK.

## The topic

Every badge publishes to its own topic from the last three bytes of the
factory MAC:

```text
goatmire/badge/a1b2c3/temperature
```

Watch it from a laptop with:

```sh
mosquitto_sub -h test.mosquitto.org -t 'goatmire/badge/+/temperature' -v
```

## Flash and monitor

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor --timeout 20
```

```text
Connecting to YOUR_WIFI...
Connected, IP 192.168.1.42
MQTT connected to test.mosquitto.org
Publishing to goatmire/badge/a1b2c3/temperature
goatmire/badge/a1b2c3/temperature 28
```

## Good to know

* Badge not detected: hold **BOOT**, tap **RESET**, release **BOOT**, retry.
* Edit `src/config.gleam` for your network before flashing.
