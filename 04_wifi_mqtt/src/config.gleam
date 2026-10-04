/// Credentials and broker settings. Edit these before flashing.
///
/// Keep real passwords out of git — change locally and do not commit.

pub const wifi_ssid = "YOUR_WIFI"

pub const wifi_psk = "YOUR_PASSWORD"

/// Hostname only. AtomVM's TCP stack expects a charlist; the FFI converts this.
pub const mqtt_host = "test.mosquitto.org"

pub const mqtt_port = 1883

pub const topic_prefix = "goatmire/badge"

pub const publish_interval_ms = 5000
