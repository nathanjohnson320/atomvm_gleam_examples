import config.{type Config}
import gleam/int

pub fn url(config: Config, path: String) -> String {
  let scheme = case config.api_tls {
    True -> "https"
    False -> "http"
  }
  let path = case path {
    "" -> ""
    _ ->
      case string_starts_with_slash(path) {
        True -> path
        False -> "/" <> path
      }
  }
  scheme
  <> "://"
  <> config.api_host
  <> ":"
  <> int.to_string(config.api_port)
  <> path
}

pub fn messages_path() -> String {
  "/messages"
}

fn string_starts_with_slash(path: String) -> Bool {
  case path {
    "/" <> _ -> True
    _ -> False
  }
}
