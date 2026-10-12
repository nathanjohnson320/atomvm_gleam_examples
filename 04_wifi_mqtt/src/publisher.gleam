import atomvm_gleam/i2c
import config
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/result
import mqtt
import tmp103
import wifi

@external(erlang, "badge_ffi", "id")
fn badge_id() -> String

pub fn start() -> Nil {
  case run() {
    Ok(Nil) -> Nil
    Error(message) -> {
      io.println(message)
      Nil
    }
  }
}

fn run() -> Result(Nil, String) {
  io.println("Connecting to " <> config.wifi_ssid <> "...")

  use address <- result.try(
    wifi.connect(config.wifi_ssid, config.wifi_psk)
    |> result.map_error(fn(error) {
      "Failed to connect to "
      <> config.wifi_ssid
      <> ": "
      <> wifi.error_to_string(error)
    }),
  )
  io.println("Connected, IP " <> address)

  use client <- result.try(
    mqtt.connect(config.mqtt_host, config.mqtt_port, "badge-" <> badge_id())
    |> result.map_error(fn(error) {
      case error {
        mqtt.Timeout ->
          "No answer from "
          <> config.mqtt_host
          <> ", is it reachable from this network?"
        _ -> "MQTT connect failed: " <> mqtt.error_to_string(error)
      }
    }),
  )
  io.println("MQTT connected to " <> config.mqtt_host)

  use bus <- result.try(
    i2c.open(i2c.Config(scl: 10, sda: 11, clock_speed_hz: 100_000))
    |> result.map_error(fn(error) {
      "I2C open failed: " <> i2c.error_to_string(error)
    }),
  )

  let topic = temperature_topic(config.topic_prefix, badge_id())
  io.println("Publishing to " <> topic)
  loop(bus, client, topic)
}

pub fn temperature_topic(prefix: String, id: String) -> String {
  prefix <> "/" <> id <> "/temperature"
}

fn loop(
  bus: i2c.Bus,
  client: mqtt.Client,
  topic: String,
) -> Result(Nil, String) {
  use celsius <- result.try(tmp103.read_celsius(bus))
  let payload = int.to_string(celsius)

  use Nil <- result.try(
    mqtt.publish(client, topic, payload)
    |> result.map_error(fn(error) {
      "MQTT publish failed: " <> mqtt.error_to_string(error)
    }),
  )
  io.println(topic <> " " <> payload)
  process.sleep(config.publish_interval_ms)
  loop(bus, client, topic)
}
