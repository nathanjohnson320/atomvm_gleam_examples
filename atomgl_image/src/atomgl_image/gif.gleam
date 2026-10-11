/// Decode GIF87a/89a into composed rgba8888 frames for AtomGL.
import atomgl_image/sprite.{type Sprite, Rgba8888}
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type GifError {
  NotGif
  Truncated
  BadImage
  BadLzw
  NoFrames
}

pub fn decode(data: BitArray) -> Result(List(Sprite), GifError) {
  case data {
    <<"GIF87a":utf8, rest:bytes>> | <<"GIF89a":utf8, rest:bytes>> ->
      parse_screen(rest)
    _ -> Error(NotGif)
  }
}

fn parse_screen(data: BitArray) -> Result(List(Sprite), GifError) {
  case data {
    <<
      width:size(16)-little,
      height:size(16)-little,
      flags,
      _bg,
      _aspect,
      rest:bytes,
    >> -> {
      let has_gct = int.bitwise_and(flags, 0x80) != 0
      let gct_size =
        3 * int.bitwise_shift_left(1, int.bitwise_and(flags, 7) + 1)
      use #(gct, after_gct) <- result.try(case has_gct {
        False -> Ok(#(<<>>, rest))
        True -> take_bytes(rest, gct_size)
      })
      let canvas =
        bit_array.concat(list.repeat(
          item: <<0, 0, 0, 255>>,
          times: width * height,
        ))
      read_blocks(after_gct, width, height, gct, canvas, None, None, [])
    }
    _ -> Error(Truncated)
  }
}

type GraphicControl {
  GraphicControl(disposal: Int, transparent: Option(Int))
}

fn read_blocks(
  data: BitArray,
  width: Int,
  height: Int,
  gct: BitArray,
  canvas: BitArray,
  control: Option(GraphicControl),
  previous: Option(BitArray),
  frames: List(Sprite),
) -> Result(List(Sprite), GifError) {
  case data {
    <<>> -> finish_frames(frames)
    <<0x3b, _rest:bytes>> -> finish_frames(frames)
    <<0x3b>> -> finish_frames(frames)
    <<0x21, label, rest:bytes>> -> {
      use #(payload, after) <- result.try(read_sub_blocks(rest))
      let control = case label {
        0xf9 -> Some(parse_gce(payload))
        _ -> control
      }
      read_blocks(after, width, height, gct, canvas, control, previous, frames)
    }
    <<
      0x2c,
      left:size(16)-little,
      top:size(16)-little,
      fw:size(16)-little,
      fh:size(16)-little,
      local,
      rest:bytes,
    >> -> {
      let has_lct = int.bitwise_and(local, 0x80) != 0
      let interlaced = int.bitwise_and(local, 0x40) != 0
      let lct_size =
        3 * int.bitwise_shift_left(1, int.bitwise_and(local, 7) + 1)
      use #(table, after_table) <- result.try(case has_lct {
        False -> Ok(#(gct, rest))
        True -> take_bytes(rest, lct_size)
      })
      case after_table {
        <<min_code_size, after_min:bytes>> -> {
          use #(compressed, after_image) <- result.try(read_sub_blocks(
            after_min,
          ))
          use indices <- result.try(lzw_decode(compressed, min_code_size))
          use indices <- result.try(case interlaced {
            False -> Ok(indices)
            True -> deinterlace(indices, fw, fh)
          })
          let GraphicControl(next_disposal, transparent) = case control {
            Some(c) -> c
            None -> GraphicControl(0, None)
          }
          let saved = case next_disposal {
            3 -> Some(canvas)
            _ -> previous
          }
          let painted =
            paint_frame(
              canvas,
              width,
              height,
              left,
              top,
              fw,
              fh,
              indices,
              table,
              transparent,
            )
          let frame = Rgba8888(width, height, painted)
          let cleared = case next_disposal {
            2 -> clear_rect(painted, width, height, left, top, fw, fh)
            3 ->
              case saved {
                Some(bytes) -> bytes
                None -> painted
              }
            _ -> painted
          }
          read_blocks(after_image, width, height, gct, cleared, None, saved, [
            frame,
            ..frames
          ])
        }
        _ -> Error(Truncated)
      }
    }
    _ -> Error(BadImage)
  }
}

fn finish_frames(frames: List(Sprite)) -> Result(List(Sprite), GifError) {
  case list.reverse(frames) {
    [] -> Error(NoFrames)
    ready -> Ok(ready)
  }
}

fn parse_gce(payload: BitArray) -> GraphicControl {
  case payload {
    <<packed, _delay:size(16)-little, transparent_index, _rest:bytes>>
    | <<packed, _delay:size(16)-little, transparent_index>> -> {
      let disposal = int.bitwise_and(int.bitwise_shift_right(packed, 2), 7)
      let transparent = case int.bitwise_and(packed, 1) == 1 {
        True -> Some(transparent_index)
        False -> None
      }
      GraphicControl(disposal, transparent)
    }
    _ -> GraphicControl(0, None)
  }
}

fn take_bytes(
  data: BitArray,
  size: Int,
) -> Result(#(BitArray, BitArray), GifError) {
  case bit_array.slice(data, 0, size) {
    Error(Nil) -> Error(Truncated)
    Ok(chunk) ->
      case bit_array.slice(data, size, bit_array.byte_size(data) - size) {
        Error(Nil) -> Error(Truncated)
        Ok(after) -> Ok(#(chunk, after))
      }
  }
}

fn read_sub_blocks(data: BitArray) -> Result(#(BitArray, BitArray), GifError) {
  read_sub_blocks_loop(data, <<>>)
}

fn read_sub_blocks_loop(
  data: BitArray,
  acc: BitArray,
) -> Result(#(BitArray, BitArray), GifError) {
  case data {
    <<0, rest:bytes>> -> Ok(#(acc, rest))
    <<0>> -> Ok(#(acc, <<>>))
    <<size, rest:bytes>> -> {
      use #(chunk, after) <- result.try(take_bytes(rest, size))
      read_sub_blocks_loop(after, bit_array.append(acc, chunk))
    }
    _ -> Error(Truncated)
  }
}

fn lzw_decode(
  data: BitArray,
  min_code_size: Int,
) -> Result(BitArray, GifError) {
  case min_code_size < 2 || min_code_size > 8 {
    True -> Error(BadLzw)
    False -> {
      let clear = int.bitwise_shift_left(1, min_code_size)
      let end = clear + 1
      decode_codes(
        data,
        0,
        0,
        min_code_size + 1,
        clear,
        end,
        end + 1,
        init_table(clear),
        None,
        <<>>,
      )
    }
  }
}

fn init_table(clear: Int) -> Dict(Int, BitArray) {
  int.range(from: 0, to: clear, with: dict.new(), run: fn(table, index) {
    dict.insert(table, index, <<index>>)
  })
}

fn decode_codes(
  data: BitArray,
  bit_pos: Int,
  bit_count: Int,
  code_size: Int,
  clear: Int,
  end: Int,
  next_code: Int,
  table: Dict(Int, BitArray),
  previous: Option(BitArray),
  out: BitArray,
) -> Result(BitArray, GifError) {
  use #(code, data2, bit_pos2, bit_count2) <- result.try(read_code(
    data,
    bit_pos,
    bit_count,
    code_size,
  ))
  case code == clear {
    True ->
      decode_codes(
        data2,
        bit_pos2,
        bit_count2,
        code_size_after_clear(clear),
        clear,
        end,
        end + 1,
        init_table(clear),
        None,
        out,
      )
    False ->
      case code == end {
        True -> Ok(out)
        False -> {
          use #(entry, table2, next2, size2, previous2) <- result.try(
            process_code(code, previous, table, next_code, code_size, clear),
          )
          decode_codes(
            data2,
            bit_pos2,
            bit_count2,
            size2,
            clear,
            end,
            next2,
            table2,
            previous2,
            bit_array.append(out, entry),
          )
        }
      }
  }
}

fn code_size_after_clear(clear: Int) -> Int {
  case clear {
    4 -> 3
    8 -> 4
    16 -> 5
    32 -> 6
    64 -> 7
    128 -> 8
    256 -> 9
    _ -> 3
  }
}

fn process_code(
  code: Int,
  previous: Option(BitArray),
  table: Dict(Int, BitArray),
  next_code: Int,
  code_size: Int,
  clear: Int,
) -> Result(
  #(BitArray, Dict(Int, BitArray), Int, Int, Option(BitArray)),
  GifError,
) {
  case dict.get(table, code) {
    Ok(entry) -> {
      let #(table2, next2) = case previous {
        None -> #(table, next_code)
        Some(prev) ->
          case next_code < 4096 {
            False -> #(table, next_code)
            True ->
              case bit_array.slice(entry, 0, 1) {
                Ok(first) -> #(
                  dict.insert(table, next_code, bit_array.append(prev, first)),
                  next_code + 1,
                )
                Error(Nil) -> #(table, next_code)
              }
          }
      }
      Ok(#(entry, table2, next2, grow_code_size(code_size, next2), Some(entry)))
    }
    Error(Nil) ->
      case previous {
        Some(prev) ->
          case code == next_code {
            False -> Error(BadLzw)
            True ->
              case bit_array.slice(prev, 0, 1) {
                Error(Nil) -> Error(BadLzw)
                Ok(first) -> {
                  let entry = bit_array.append(prev, first)
                  let #(table2, next2) = case next_code < 4096 {
                    True -> #(
                      dict.insert(table, next_code, entry),
                      next_code + 1,
                    )
                    False -> #(table, next_code)
                  }
                  Ok(#(
                    entry,
                    table2,
                    next2,
                    grow_code_size(code_size, next2),
                    Some(entry),
                  ))
                }
              }
          }
        None ->
          case code < clear {
            True -> Ok(#(<<code>>, table, next_code, code_size, Some(<<code>>)))
            False -> Error(BadLzw)
          }
      }
  }
}

fn grow_code_size(code_size: Int, next_code: Int) -> Int {
  case code_size < 12 && next_code == int.bitwise_shift_left(1, code_size) {
    True -> code_size + 1
    False -> code_size
  }
}

fn read_code(
  data: BitArray,
  bit_pos: Int,
  bit_count: Int,
  code_size: Int,
) -> Result(#(Int, BitArray, Int, Int), GifError) {
  read_code_loop(data, bit_pos, bit_count, code_size, 0, 0)
}

fn read_code_loop(
  data: BitArray,
  bit_pos: Int,
  bit_count: Int,
  code_size: Int,
  value: Int,
  got: Int,
) -> Result(#(Int, BitArray, Int, Int), GifError) {
  case got >= code_size {
    True -> Ok(#(value, data, bit_pos, bit_count))
    False ->
      case bit_count == 0 {
        True ->
          case data {
            <<byte, rest:bytes>> ->
              read_code_loop(rest, byte, 8, code_size, value, got)
            _ -> Error(Truncated)
          }
        False -> {
          let bit = int.bitwise_and(bit_pos, 1)
          let value2 = int.bitwise_or(value, int.bitwise_shift_left(bit, got))
          read_code_loop(
            data,
            int.bitwise_shift_right(bit_pos, 1),
            bit_count - 1,
            code_size,
            value2,
            got + 1,
          )
        }
      }
  }
}

fn deinterlace(
  indices: BitArray,
  width: Int,
  height: Int,
) -> Result(BitArray, GifError) {
  case bit_array.byte_size(indices) == width * height {
    False -> Error(BadImage)
    True -> {
      let order =
        list.flatten([
          collect_pass(height, 0, 8),
          collect_pass(height, 4, 8),
          collect_pass(height, 2, 4),
          collect_pass(height, 1, 2),
        ])
      let slots = list.repeat(item: <<>>, times: height)
      let filled =
        list.index_fold(order, slots, fn(rows, target, source) {
          case bit_array.slice(indices, source * width, width) {
            Ok(row) -> replace_at(rows, target, row)
            Error(Nil) -> rows
          }
        })
      Ok(bit_array.concat(filled))
    }
  }
}

fn collect_pass(height: Int, start: Int, step: Int) -> List(Int) {
  int.range(from: start, to: height, with: [], run: fn(acc, y) {
    case { y - start } % step == 0 {
      True -> [y, ..acc]
      False -> acc
    }
  })
  |> list.reverse
}

fn replace_at(
  items: List(BitArray),
  index: Int,
  value: BitArray,
) -> List(BitArray) {
  list.index_map(items, fn(item, i) {
    case i == index {
      True -> value
      False -> item
    }
  })
}

fn paint_frame(
  canvas: BitArray,
  width: Int,
  height: Int,
  left: Int,
  top: Int,
  fw: Int,
  fh: Int,
  indices: BitArray,
  table: BitArray,
  transparent: Option(Int),
) -> BitArray {
  int.range(from: 0, to: fh, with: canvas, run: fn(acc, y) {
    int.range(from: 0, to: fw, with: acc, run: fn(canvas, x) {
      let cx = left + x
      let cy = top + y
      case cx >= width || cy >= height {
        True -> canvas
        False ->
          case bit_array.slice(indices, y * fw + x, 1) {
            Error(Nil) -> canvas
            Ok(<<index>>) ->
              case transparent == Some(index) {
                True -> canvas
                False ->
                  case bit_array.slice(table, index * 3, 3) {
                    Ok(<<r, g, b>>) ->
                      put_pixel(canvas, width, cx, cy, <<r, g, b, 255>>)
                    _ -> canvas
                  }
              }
            Ok(_) -> canvas
          }
      }
    })
  })
}

fn clear_rect(
  canvas: BitArray,
  width: Int,
  height: Int,
  left: Int,
  top: Int,
  fw: Int,
  fh: Int,
) -> BitArray {
  int.range(from: 0, to: fh, with: canvas, run: fn(acc, y) {
    int.range(from: 0, to: fw, with: acc, run: fn(canvas, x) {
      let cx = left + x
      let cy = top + y
      case cx >= width || cy >= height {
        True -> canvas
        False -> put_pixel(canvas, width, cx, cy, <<0, 0, 0, 255>>)
      }
    })
  })
}

fn put_pixel(
  canvas: BitArray,
  width: Int,
  x: Int,
  y: Int,
  pixel: BitArray,
) -> BitArray {
  let offset = { y * width + x } * 4
  let prefix = case bit_array.slice(canvas, 0, offset) {
    Ok(bytes) -> bytes
    Error(Nil) -> <<>>
  }
  let suffix = case
    bit_array.slice(
      canvas,
      offset + 4,
      bit_array.byte_size(canvas) - offset - 4,
    )
  {
    Ok(bytes) -> bytes
    Error(Nil) -> <<>>
  }
  bit_array.concat([prefix, pixel, suffix])
}
