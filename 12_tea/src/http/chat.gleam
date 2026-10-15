import api
import atomvm_gleam/http
import atomvm_gleam/network
import config.{type Config}
import effect.{type Effect}
import gleam/erlang/process
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result

/// `POST /messages` with a plain-text body. No-ops when `api_host` is still
/// the placeholder. Runs off-actor so the UI stays responsive.
pub fn create_message(
  config: Config,
  text: String,
  to_msg: fn(Result(Nil, String)) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    process.spawn(fn() { dispatch(to_msg(send(config, text))) })
    Nil
  })
}

fn send(config: Config, text: String) -> Result(Nil, String) {
  case config.api_host {
    "YOUR_HOST" -> Ok(Nil)
    _ -> {
      use _ <- result.try(ensure_wifi(config))
      post(config, text)
    }
  }
}

fn ensure_wifi(config: Config) -> Result(Nil, String) {
  case config.wifi_ssid {
    "YOUR_WIFI" -> Error("set wifi in config.gleam")
    _ ->
      case network.wait_for_sta(config.wifi_ssid, config.wifi_psk, 18_000) {
        Ok(_) -> Ok(Nil)
        Error(error) -> Error(network.error_to_string(error))
      }
  }
}

fn post(config: Config, text: String) -> Result(Nil, String) {
  let protocol = case config.api_tls {
    True -> http.Https
    False -> http.Http
  }
  let verify = case config.api_tls {
    True -> Some(http.VerifyNone)
    False -> None
  }
  use conn <- result.try(
    http.connect(protocol, config.api_host, config.api_port, False, verify)
    |> map_http("connect"),
  )
  use #(conn, _ref) <- result.try(
    http.request(
      conn,
      "POST",
      api.messages_path(),
      [#("content-type", "text/plain")],
      http.Bytes(<<text:utf8>>),
    )
    |> map_http("request"),
  )
  case recv_status(conn, None, 200) {
    Error(message) -> {
      let _ = http.close(conn)
      Error(message)
    }
    Ok(#(conn, code)) -> {
      let _ = http.close(conn)
      case code >= 200 && code < 300 {
        True -> Ok(Nil)
        False -> Error("HTTP " <> int.to_string(code))
      }
    }
  }
}

fn map_http(value: Result(a, http.Error), step: String) -> Result(a, String) {
  result.map_error(value, fn(error) {
    step <> ": " <> http.error_to_string(error)
  })
}

fn recv_status(
  conn: http.Connection,
  status: Option(Int),
  remaining: Int,
) -> Result(#(http.Connection, Int), String) {
  case remaining <= 0 {
    True -> Error("HTTP recv timeout")
    False ->
      case http.recv(conn, 0) {
        Ok(#(conn2, responses)) -> {
          let #(status2, done) = fold_status(responses, status, False)
          case status2, done {
            Some(code), True -> Ok(#(conn2, code))
            Some(code), False ->
              case responses {
                [] -> {
                  process.sleep(20)
                  recv_status(conn2, Some(code), remaining - 1)
                }
                _ -> recv_status(conn2, Some(code), remaining - 1)
              }
            None, _ ->
              case responses {
                [] -> {
                  process.sleep(20)
                  recv_status(conn2, None, remaining - 1)
                }
                _ -> recv_status(conn2, None, remaining - 1)
              }
          }
        }
        Error(http.Other("closed")) ->
          case status {
            Some(code) -> Ok(#(conn, code))
            None -> Error("HTTP closed before Status")
          }
        Error(reason) -> Error("recv: " <> http.error_to_string(reason))
      }
  }
}

fn fold_status(
  responses: List(http.Response),
  status: Option(Int),
  done: Bool,
) -> #(Option(Int), Bool) {
  case responses {
    [] -> #(status, done)
    [http.Status(_, code), ..rest] -> fold_status(rest, Some(code), done)
    [http.Done(_), ..rest] -> fold_status(rest, status, True)
    [_, ..rest] -> fold_status(rest, status, done)
  }
}
