/// Wi-Fi association and DHCP around AtomVM's `network` API.
///
/// See [`network:wait_for_sta/2`](https://doc.atomvm.org/latest/apidocs/erlang/eavmlib/network.html#wait-for-sta-2).

pub type Error {
  Timeout
  Disconnected
  Other(String)
}

pub fn error_to_string(error: Error) -> String {
  case error {
    Timeout -> "timeout"
    Disconnected -> "disconnected"
    Other(reason) -> reason
  }
}

/// Associate with `ssid`, run DHCP, return the IPv4 address string.
pub fn connect(ssid: String, psk: String) -> Result(String, Error) {
  connect_ffi(ssid, psk)
}

@external(erlang, "wifi_ffi", "connect")
fn connect_ffi(ssid: String, psk: String) -> Result(String, Error)
