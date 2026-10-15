/// Edit locally before flashing. Keep real secrets out of git.
pub const wifi_ssid = "YOUR_WIFI"

pub const wifi_psk = "YOUR_PASSWORD"

/// Plain HTTP chat API. Leave `YOUR_HOST` to skip network on Submit.
pub const api_host = "YOUR_HOST"

pub const api_port = 80

pub const api_tls = False

pub type Config {
  Config(
    wifi_ssid: String,
    wifi_psk: String,
    api_host: String,
    api_port: Int,
    api_tls: Bool,
  )
}

pub fn load() -> Config {
  Config(wifi_ssid:, wifi_psk:, api_host:, api_port:, api_tls:)
}
