/// Open GoPro HTTP helpers. Status IDs from the Open GoPro StatusId enum.
import atomvm_gleam/http
import config
import gleam/bit_array
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Fields pulled from `GET /gopro/camera/state` `status` object.
pub type Snapshot {
  Snapshot(
    battery_percent: Int,
    /// 0–3 bars, or 4 = charging (`INTERNAL_BATTERY_BARS`).
    battery_bars: Int,
    encoding: Bool,
  )
}

/// `FOLDER/FILE.JPG` path from `GET /gopro/media/list`.
pub type MediaItem {
  MediaItem(path: String)
}

pub fn fetch_snapshot() -> Result(Snapshot, String) {
  get_ok_body("/gopro/camera/state")
  |> result.try(parse_snapshot)
}

pub fn fetch_media_list() -> Result(List(MediaItem), String) {
  get_ok_body("/gopro/media/list")
  |> result.try(parse_media_list)
}

pub fn fetch_thumbnail(path: String) -> Result(BitArray, String) {
  get_ok_body("/gopro/media/thumbnail?path=" <> path)
}

pub fn parse_media_list(body: BitArray) -> Result(List(MediaItem), String) {
  json.parse_bits(body, media_list_decoder())
  |> result.map_error(fn(_) { "media list JSON failed" })
  |> result.map(flatten_jpgs)
}

/// Wrap `index` into `0 .. count-1` (including negatives). Empty → 0.
pub fn wrap_index(index: Int, count: Int) -> Int {
  case count <= 0 {
    True -> 0
    False -> {
      let r = index % count
      case r < 0 {
        True -> r + count
        False -> r
      }
    }
  }
}

pub fn short_filename(path: String) -> String {
  case string.split(path, "/") {
    [] -> path
    parts ->
      case list.last(parts) {
        Ok(name) -> name
        Error(Nil) -> path
      }
  }
}

pub fn parse_snapshot(body: BitArray) -> Result(Snapshot, String) {
  json.parse_bits(body, snapshot_decoder())
  |> result.map_error(fn(_) { "JSON decode failed" })
}

pub fn battery_label(percent: Int, bars: Int) -> String {
  case bars {
    4 -> int.to_string(percent) <> "% charging"
    _ -> int.to_string(percent) <> "%"
  }
}

fn snapshot_decoder() -> decode.Decoder(Snapshot) {
  use status <- decode.field("status", status_decoder())
  decode.success(status)
}

fn status_decoder() -> decode.Decoder(Snapshot) {
  // StatusId: INTERNAL_BATTERY_BARS=2, ENCODING=10,
  // INTERNAL_BATTERY_PERCENTAGE=70.
  use battery_percent <- decode.optional_field("70", 0, decode.int)
  use battery_bars <- decode.optional_field("2", 0, decode.int)
  use encoding_i <- decode.optional_field("10", 0, decode.int)
  decode.success(Snapshot(
    battery_percent:,
    battery_bars:,
    encoding: encoding_i != 0,
  ))
}

fn get_ok_body(path: String) -> Result(BitArray, String) {
  use conn <- result.try(
    http.connect(http.Http, config.host, config.port, False, None)
    |> map_http("connect"),
  )
  use #(conn, _ref) <- result.try(
    http.request(conn, "GET", path, [], http.Empty)
    |> map_http("request"),
  )
  case recv_body(conn, None, None, <<>>, 400) {
    Error(message) -> {
      let _ = http.close(conn)
      Error(message)
    }
    Ok(#(conn, code, body)) -> {
      let _ = http.close(conn)
      case code {
        200 -> Ok(body)
        _ -> Error("HTTP " <> int.to_string(code))
      }
    }
  }
}

type MediaFolder {
  MediaFolder(d: String, fs: List(MediaFile))
}

type MediaFile {
  MediaFile(n: String)
}

fn media_list_decoder() -> decode.Decoder(List(MediaFolder)) {
  use media <- decode.field("media", decode.list(media_folder_decoder()))
  decode.success(media)
}

fn media_folder_decoder() -> decode.Decoder(MediaFolder) {
  use d <- decode.field("d", decode.string)
  use fs <- decode.field("fs", decode.list(media_file_decoder()))
  decode.success(MediaFolder(d:, fs:))
}

fn media_file_decoder() -> decode.Decoder(MediaFile) {
  use n <- decode.field("n", decode.string)
  decode.success(MediaFile(n:))
}

fn flatten_jpgs(folders: List(MediaFolder)) -> List(MediaItem) {
  list.flat_map(folders, fn(folder) {
    list.filter_map(folder.fs, fn(file) {
      case is_jpeg_name(file.n) {
        True -> Ok(MediaItem(path: folder.d <> "/" <> file.n))
        False -> Error(Nil)
      }
    })
  })
}

fn is_jpeg_name(name: String) -> Bool {
  // AtomVM has no `string:uppercase/1` — check common suffixes directly.
  string.ends_with(name, ".JPG")
  || string.ends_with(name, ".jpg")
  || string.ends_with(name, ".JPEG")
  || string.ends_with(name, ".jpeg")
}

fn map_http(value: Result(a, http.Error), step: String) -> Result(a, String) {
  result.map_error(value, fn(error) {
    step <> ": " <> http.error_to_string(error)
  })
}

fn recv_body(
  conn: http.Connection,
  status: Option(Int),
  content_length: Option(Int),
  body: BitArray,
  remaining: Int,
) -> Result(#(http.Connection, Int, BitArray), String) {
  case remaining <= 0 {
    True -> Error("HTTP recv timeout")
    False ->
      case http.recv(conn, 0) {
        Ok(#(conn2, responses)) -> {
          let #(status2, length2, body2, done) =
            fold_responses(responses, status, content_length, body, False)
          let got = bit_array.byte_size(body2)
          let complete = case length2 {
            Some(n) -> got >= n || done
            None -> done
          }
          case complete {
            True ->
              case status2 {
                Some(code) -> Ok(#(conn2, code, trim_body(body2, length2)))
                None -> Error("HTTP Done without Status")
              }
            False ->
              case responses {
                [] -> {
                  // Passive recv returned nothing; yield before polling again.
                  process.sleep(20)
                  recv_body(conn2, status2, length2, body2, remaining - 1)
                }
                _ -> recv_body(conn2, status2, length2, body2, remaining - 1)
              }
          }
        }
        Error(http.Other("closed")) ->
          case status {
            Some(code) -> Ok(#(conn, code, trim_body(body, content_length)))
            None -> Error("HTTP closed before Status")
          }
        Error(reason) -> Error("recv: " <> http.error_to_string(reason))
      }
  }
}

fn trim_body(body: BitArray, content_length: Option(Int)) -> BitArray {
  case content_length {
    Some(n) ->
      case bit_array.slice(body, 0, n) {
        Ok(trimmed) -> trimmed
        Error(Nil) -> body
      }
    None -> body
  }
}

fn fold_responses(
  responses: List(http.Response),
  status: Option(Int),
  content_length: Option(Int),
  body: BitArray,
  done: Bool,
) -> #(Option(Int), Option(Int), BitArray, Bool) {
  case responses {
    [] -> #(status, content_length, body, done)
    [http.Status(_ref, code), ..rest] ->
      fold_responses(rest, Some(code), content_length, body, done)
    [http.Data(_ref, chunk), ..rest] ->
      fold_responses(
        rest,
        status,
        content_length,
        bit_array.append(body, chunk),
        done,
      )
    [http.Done(_ref), ..rest] ->
      fold_responses(rest, status, content_length, body, True)
    [http.Header(_, name, value), ..rest]
    | [http.HeaderContinuation(_, name, value), ..rest] -> {
      let length = case content_length {
        Some(_) -> content_length
        None -> parse_content_length(name, value)
      }
      fold_responses(rest, status, length, body, done)
    }
    [http.TrailerHeader(_, _, _), ..rest] ->
      fold_responses(rest, status, content_length, body, done)
  }
}

fn parse_content_length(name: BitArray, value: BitArray) -> Option(Int) {
  case name {
    <<"content-length">> | <<"Content-Length">> | <<"CONTENT-LENGTH">> ->
      // Avoid `string.trim` / `to_string` — both have hit AtomVM badargs.
      parse_decimal_bytes(value, 0, False)
    _ -> None
  }
}

fn parse_decimal_bytes(
  data: BitArray,
  acc: Int,
  seen_digit: Bool,
) -> Option(Int) {
  case data {
    <<>> ->
      case seen_digit {
        True -> Some(acc)
        False -> None
      }
    <<byte, rest:bytes>> ->
      case byte {
        b if b >= 0x30 && b <= 0x39 ->
          parse_decimal_bytes(rest, acc * 10 + { b - 0x30 }, True)
        0x20 | 0x09 ->
          case seen_digit {
            True -> Some(acc)
            False -> parse_decimal_bytes(rest, 0, False)
          }
        _ ->
          case seen_digit {
            True -> Some(acc)
            False -> None
          }
      }
    _ -> None
  }
}
