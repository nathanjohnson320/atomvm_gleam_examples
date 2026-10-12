/// Minimal zlib inflate for PNG IDAT.
///
/// Supports stored (uncompressed) deflate blocks, which is what the embedded
/// demo PNG uses. Other block types return an error.
import gleam/bit_array
import gleam/int
import gleam/result

pub type InflateError {
  BadZlibHeader
  BadLength
  Truncated
  UnsupportedBlock
  BadAdler32
}

pub fn inflate(data: BitArray) -> Result(BitArray, InflateError) {
  case data {
    <<cmf, flg, rest:bytes>> -> {
      let cm = int.bitwise_and(cmf, 0x0f)
      let window = int.bitwise_shift_right(cmf, 4)
      let check = { int.bitwise_shift_left(cmf, 8) + flg } % 31
      let preset = int.bitwise_and(flg, 0x20) != 0
      case cm == 8 && window <= 7 && check == 0 && !preset {
        False -> Error(BadZlibHeader)
        True -> inflate_blocks(rest, <<>>)
      }
    }
    _ -> Error(Truncated)
  }
}

fn inflate_blocks(
  data: BitArray,
  out: BitArray,
) -> Result(BitArray, InflateError) {
  case data {
    <<header, rest:bytes>> -> {
      let bfinal = int.bitwise_and(header, 0x01)
      let btype = int.bitwise_and(int.bitwise_shift_right(header, 1), 0x03)
      case btype {
        0 -> {
          use #(chunk, after) <- result.try(read_stored(rest))
          let next = bit_array.append(out, chunk)
          case bfinal == 1 {
            True -> finish(after, next)
            False -> inflate_blocks(after, next)
          }
        }
        _ -> Error(UnsupportedBlock)
      }
    }
    _ -> Error(Truncated)
  }
}

fn read_stored(data: BitArray) -> Result(#(BitArray, BitArray), InflateError) {
  case data {
    <<len:size(16)-little, nlen:size(16)-little, rest:bytes>> -> {
      let expect = int.bitwise_and(int.bitwise_not(len), 0xffff)
      case nlen == expect {
        False -> Error(BadLength)
        True ->
          case bit_array.slice(rest, 0, len) {
            Error(Nil) -> Error(Truncated)
            Ok(chunk) ->
              case bit_array.slice(rest, len, bit_array.byte_size(rest) - len) {
                Error(Nil) -> Error(Truncated)
                Ok(after) -> Ok(#(chunk, after))
              }
          }
      }
    }
    _ -> Error(Truncated)
  }
}

fn finish(data: BitArray, out: BitArray) -> Result(BitArray, InflateError) {
  case data {
    <<adler:size(32), _rest:bytes>> -> check_adler(adler, out)
    <<adler:size(32)>> -> check_adler(adler, out)
    _ -> Error(Truncated)
  }
}

fn check_adler(adler: Int, out: BitArray) -> Result(BitArray, InflateError) {
  case adler32(out) == adler {
    True -> Ok(out)
    False -> Error(BadAdler32)
  }
}

fn adler32(data: BitArray) -> Int {
  adler_loop(data, 1, 0)
}

fn adler_loop(data: BitArray, a: Int, b: Int) -> Int {
  case data {
    <<>> ->
      int.bitwise_or(
        int.bitwise_shift_left(int.bitwise_and(b, 0xffff), 16),
        int.bitwise_and(a, 0xffff),
      )
    <<c, rest:bytes>> -> {
      let a2 = { a + c } % 65_521
      let b2 = { b + a2 } % 65_521
      adler_loop(rest, a2, b2)
    }
    _ ->
      int.bitwise_or(
        int.bitwise_shift_left(int.bitwise_and(b, 0xffff), 16),
        int.bitwise_and(a, 0xffff),
      )
  }
}
