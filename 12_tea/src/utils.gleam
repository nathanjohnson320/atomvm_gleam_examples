import gleam/bit_array

pub fn drop_last(text: String) -> String {
  let bits = <<text:utf8>>
  let byte_len = bit_array.byte_size(bits)
  case byte_len {
    0 -> ""
    _ ->
      case bit_array.slice(bits, 0, byte_len - 1) {
        Ok(prefix) ->
          case bit_array.to_string(prefix) {
            Ok(s) -> s
            Error(Nil) -> text
          }
        Error(Nil) -> text
      }
  }
}
