/// Decode 8-bit RGBA non-interlaced PNGs into AtomGL rgba8888 sprites.
import atomgl_image/sprite.{type Sprite, Rgba8888}
import atomgl_image/zlib_inflate
import gleam/bit_array
import gleam/int
import gleam/result

pub type PngError {
  NotPng
  Truncated
  Unsupported
  BadChunk
  Inflate(zlib_inflate.InflateError)
  BadFilter
  BadSize
}

pub fn decode(data: BitArray) -> Result(Sprite, PngError) {
  case data {
    <<0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, rest:bytes>> ->
      decode_chunks(rest, NoneHeader, <<>>)
    _ -> Error(NotPng)
  }
}

type Header {
  NoneHeader
  Header(width: Int, height: Int)
}

fn decode_chunks(
  data: BitArray,
  header: Header,
  idat: BitArray,
) -> Result(Sprite, PngError) {
  case data {
    <<len:size(32), type_a, type_b, type_c, type_d, rest:bytes>> -> {
      let tag = <<type_a, type_b, type_c, type_d>>
      case bit_array.slice(rest, 0, len) {
        Error(Nil) -> Error(Truncated)
        Ok(payload) ->
          case bit_array.slice(rest, len, 4) {
            Error(Nil) -> Error(Truncated)
            Ok(_crc) -> {
              let next_start = len + 4
              let next = case
                bit_array.slice(
                  rest,
                  next_start,
                  bit_array.byte_size(rest) - next_start,
                )
              {
                Ok(bytes) -> bytes
                Error(Nil) -> <<>>
              }
              handle_chunk(tag, payload, next, header, idat)
            }
          }
      }
    }
    _ -> Error(Truncated)
  }
}

fn handle_chunk(
  tag: BitArray,
  payload: BitArray,
  next: BitArray,
  header: Header,
  idat: BitArray,
) -> Result(Sprite, PngError) {
  case tag {
    <<"IHDR":utf8>> -> {
      use header <- result.try(parse_ihdr(payload))
      decode_chunks(next, header, idat)
    }
    <<"IDAT":utf8>> ->
      decode_chunks(next, header, bit_array.append(idat, payload))
    <<"IEND":utf8>> -> finish(header, idat)
    _ -> decode_chunks(next, header, idat)
  }
}

fn parse_ihdr(payload: BitArray) -> Result(Header, PngError) {
  case payload {
    <<width:size(32), height:size(32), 8, 6, 0, 0, 0>>
      if width > 0 && height > 0
    -> Ok(Header(width:, height:))
    <<_:size(32), _:size(32), _, _, _, _, _>> -> Error(Unsupported)
    _ -> Error(BadChunk)
  }
}

fn finish(header: Header, idat: BitArray) -> Result(Sprite, PngError) {
  case header {
    NoneHeader -> Error(BadChunk)
    Header(width:, height:) -> {
      use raw <- result.try(
        zlib_inflate.inflate(idat)
        |> result.map_error(Inflate),
      )
      use pixels <- result.try(unfilter(raw, width, height))
      case bit_array.byte_size(pixels) == width * height * 4 {
        True -> Ok(Rgba8888(width, height, pixels))
        False -> Error(BadSize)
      }
    }
  }
}

fn unfilter(
  raw: BitArray,
  width: Int,
  height: Int,
) -> Result(BitArray, PngError) {
  let stride = width * 4
  let expect = height * { stride + 1 }
  case bit_array.byte_size(raw) == expect {
    False -> Error(BadSize)
    True -> unfilter_rows(raw, stride, height, <<>>, <<>>)
  }
}

fn unfilter_rows(
  raw: BitArray,
  stride: Int,
  rows_left: Int,
  prev: BitArray,
  out: BitArray,
) -> Result(BitArray, PngError) {
  case rows_left {
    0 -> Ok(out)
    _ ->
      case raw {
        <<filter, rest:bytes>> ->
          case bit_array.slice(rest, 0, stride) {
            Error(Nil) -> Error(Truncated)
            Ok(row) -> {
              use decoded <- result.try(apply_filter(filter, row, prev))
              let after = case
                bit_array.slice(
                  rest,
                  stride,
                  bit_array.byte_size(rest) - stride,
                )
              {
                Ok(bytes) -> bytes
                Error(Nil) -> <<>>
              }
              unfilter_rows(
                after,
                stride,
                rows_left - 1,
                decoded,
                bit_array.append(out, decoded),
              )
            }
          }
        _ -> Error(Truncated)
      }
  }
}

fn apply_filter(
  filter: Int,
  row: BitArray,
  prev: BitArray,
) -> Result(BitArray, PngError) {
  case filter {
    0 -> Ok(row)
    1 -> Ok(rebuild(row, prev, 0, bit_array.byte_size(row), <<>>, sub))
    2 -> Ok(rebuild(row, prev, 0, bit_array.byte_size(row), <<>>, up))
    3 -> Ok(rebuild(row, prev, 0, bit_array.byte_size(row), <<>>, average))
    4 -> Ok(rebuild(row, prev, 0, bit_array.byte_size(row), <<>>, paeth_filter))
    _ -> Error(BadFilter)
  }
}

fn sub(_index: Int, x: Int, left: Int, _up: Int, _up_left: Int) -> Int {
  int.bitwise_and(x + left, 0xff)
}

fn up(_index: Int, x: Int, _left: Int, up: Int, _up_left: Int) -> Int {
  int.bitwise_and(x + up, 0xff)
}

fn average(_index: Int, x: Int, left: Int, up: Int, _up_left: Int) -> Int {
  int.bitwise_and(x + { left + up } / 2, 0xff)
}

fn paeth_filter(_index: Int, x: Int, left: Int, up: Int, up_left: Int) -> Int {
  int.bitwise_and(x + paeth(left, up, up_left), 0xff)
}

fn rebuild(
  row: BitArray,
  prev: BitArray,
  index: Int,
  stride: Int,
  out: BitArray,
  combine: fn(Int, Int, Int, Int, Int) -> Int,
) -> BitArray {
  case index >= stride {
    True -> out
    False -> {
      let assert Ok(<<x>>) = bit_array.slice(row, index, 1)
      let left = byte_at(out, index - 4)
      let up_byte = byte_at(prev, index)
      let up_left = byte_at(prev, index - 4)
      let value = combine(index, x, left, up_byte, up_left)
      rebuild(
        row,
        prev,
        index + 1,
        stride,
        bit_array.append(out, <<value>>),
        combine,
      )
    }
  }
}

fn byte_at(data: BitArray, index: Int) -> Int {
  case index < 0 {
    True -> 0
    False ->
      case bit_array.slice(data, index, 1) {
        Ok(<<b>>) -> b
        _ -> 0
      }
  }
}

fn paeth(a: Int, b: Int, c: Int) -> Int {
  let p = a + b - c
  let pa = int.absolute_value(p - a)
  let pb = int.absolute_value(p - b)
  let pc = int.absolute_value(p - c)
  case pa <= pb && pa <= pc {
    True -> a
    False ->
      case pb <= pc {
        True -> b
        False -> c
      }
  }
}
