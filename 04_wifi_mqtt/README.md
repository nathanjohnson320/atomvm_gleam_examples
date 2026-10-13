# Exercise 4: publish the temperature over MQTT

Joins Wi-Fi, reads the TMP103, and publishes Celsius to MQTT.

Edit `src/config.gleam` for your network before flashing (placeholders only in git):

```gleam
pub const wifi_ssid = "YOUR_WIFI"
pub const wifi_psk = "YOUR_PASSWORD"
pub const mqtt_host = "test.mosquitto.org"
pub const mqtt_port = 1883
pub const topic_prefix = "goatmire/badge"
```

```sh
gleam run -m orbital flash esp32
gleam run -m orbital monitor --timeout 20
```
