/// Thin Gleam wrapper around the vendored `:amqtt_client` Erlang library.
pub type Client

pub type Error {
  Failed
  Timeout
  Other(String)
}

pub fn error_to_string(error: Error) -> String {
  case error {
    Failed -> "error"
    Timeout -> "timeout"
    Other(reason) -> reason
  }
}

/// Connect and wait for CONNACK. Host is a hostname string; the FFI turns it
/// into a charlist for AtomVM's TCP stack.
pub fn connect(
  host: String,
  port: Int,
  client_id: String,
) -> Result(Client, Error) {
  connect_ffi(host, port, client_id)
}

@external(erlang, "mqtt_ffi", "connect")
fn connect_ffi(
  host: String,
  port: Int,
  client_id: String,
) -> Result(Client, Error)

/// Publish at QoS 0 (fire and forget).
pub fn publish(
  client: Client,
  topic: String,
  payload: String,
) -> Result(Nil, Error) {
  publish_ffi(client, topic, payload)
}

@external(erlang, "mqtt_ffi", "publish")
fn publish_ffi(
  client: Client,
  topic: String,
  payload: String,
) -> Result(Nil, Error)
