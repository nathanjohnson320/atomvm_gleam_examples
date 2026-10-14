/// Decode baseline Huffman JPEG (SOF0/SOF1, 8-bit, grayscale or YCbCr) into
/// rgba8888 sprites for AtomGL. Prefers the AtomVM `jpeg:decode/2` C NIF
/// (esp_jpeg/tjpgd) when present; otherwise Gleam + Erlang Huffman FFI.
import atomgl_image/sprite.{type Sprite, Rgba8888}
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

/// With the Erlang Huffman FFI, a few more MCU rows are affordable on AtomVM.
const preview_max_mcu_rows = 8

pub type JpegError {
  NotJpeg
  Truncated
  Unsupported
  DecodeFailed
}

/// tjpgd scale: 0=full, 1=half, 2=quarter, 3=eighth.
@external(erlang, "atomgl_image_jpeg_nif", "decode")
fn decode_nif(data: BitArray, scale: Int) -> Result(#(Int, Int, BitArray), Nil)

pub fn decode(data: BitArray) -> Result(Sprite, JpegError) {
  case decode_nif(data, 0) {
    Ok(#(w, h, pixels)) -> Ok(Rgba8888(w, h, pixels))
    Error(Nil) -> decode_mode(data, Full)
  }
}

/// Fast path: C NIF full/scaled decode when available; else DC-only Huffman
/// preview for constrained AtomVM builds without `atomvm_jpeg`.
pub fn decode_preview(
  data: BitArray,
  max_width: Int,
  max_height: Int,
) -> Result(Sprite, JpegError) {
  decode_preview_with(data, max_width, max_height, fn(_) { Nil })
}

/// Like [`decode_preview`]. With the C NIF, decode is one-shot (no partials).
/// The Gleam fallback still paints after each MCU row.
pub fn decode_preview_with(
  data: BitArray,
  max_width: Int,
  max_height: Int,
  on_partial: fn(Sprite) -> Nil,
) -> Result(Sprite, JpegError) {
  case try_nif_fit(data, max_width, max_height) {
    Ok(sprite) -> {
      on_partial(sprite)
      Ok(sprite)
    }
    Error(Nil) -> {
      let on_scaled = fn(partial: Sprite) {
        case fit(partial, max_width, max_height, True) {
          Ok(scaled) -> on_partial(scaled)
          Error(_) -> Nil
        }
      }
      use sprite <- result.try(decode_mode(data, Preview(on_scaled)))
      fit(sprite, max_width, max_height, True)
    }
  }
}

/// Decode, then nearest-neighbor downscale so neither side exceeds the limits
/// while keeping aspect ratio. Smaller images are returned unchanged.
pub fn decode_scaled(
  data: BitArray,
  max_width: Int,
  max_height: Int,
) -> Result(Sprite, JpegError) {
  case try_nif_fit(data, max_width, max_height) {
    Ok(sprite) -> Ok(sprite)
    Error(Nil) -> {
      use sprite <- result.try(decode(data))
      fit(sprite, max_width, max_height, False)
    }
  }
}

fn try_nif_fit(
  data: BitArray,
  max_width: Int,
  max_height: Int,
) -> Result(Sprite, Nil) {
  use sprite <- result.try(decode_nif_best(data, max_width, max_height))
  // Never upscale in Gleam on AtomVM — bit-array resample is too slow.
  fit(sprite, max_width, max_height, False)
  |> result.replace_error(Nil)
}

fn decode_nif_best(
  data: BitArray,
  max_width: Int,
  max_height: Int,
) -> Result(Sprite, Nil) {
  // Finest → coarsest until it fits the display budget (avoids Gleam resample).
  decode_nif_at_scale(data, max_width, max_height, 0)
}

fn decode_nif_at_scale(
  data: BitArray,
  max_width: Int,
  max_height: Int,
  scale: Int,
) -> Result(Sprite, Nil) {
  case decode_nif(data, scale) {
    Error(Nil) -> Error(Nil)
    Ok(#(w, h, pixels)) ->
      case w <= max_width && h <= max_height || scale >= 3 {
        True -> Ok(Rgba8888(w, h, pixels))
        False -> decode_nif_at_scale(data, max_width, max_height, scale + 1)
      }
  }
}

type Mode {
  Full
  Preview(fn(Sprite) -> Nil)
}

type HuffmanMap

type BlockCtx

@external(erlang, "atomgl_image_jpeg_ffi", "map_from_list")
fn map_from_list(pairs: List(#(Int, Int))) -> HuffmanMap

@external(erlang, "atomgl_image_jpeg_ffi", "make_block_ctx")
fn make_block_ctx(
  dc: HuffmanMap,
  ac: HuffmanMap,
  dc_quant: Int,
  pred: Int,
) -> BlockCtx

@external(erlang, "atomgl_image_jpeg_ffi", "decode_dc_and_discard_ac")
fn decode_dc_and_discard_ac_ffi(
  data: BitArray,
  buf: Int,
  cnt: Int,
  pad: Int,
  ctx: BlockCtx,
) -> Result(#(Int, Int, BitArray, Int, Int, Int), Nil)

fn decode_mode(data: BitArray, mode: Mode) -> Result(Sprite, JpegError) {
  case data {
    <<0xFF, 0xD8, rest:bytes>> ->
      parse_segments(rest, None, Tables(dict.new(), dict.new(), 0), mode)
    _ -> Error(NotJpeg)
  }
}

fn fit(
  sprite: Sprite,
  max_width: Int,
  max_height: Int,
  allow_upscale: Bool,
) -> Result(Sprite, JpegError) {
  case max_width < 1 || max_height < 1 {
    True -> Error(Unsupported)
    False -> {
      let Rgba8888(width, height, pixels) = sprite
      let #(new_width, new_height) = case
        width * max_height >= height * max_width
      {
        True -> #(max_width, int.max(1, height * max_width / width))
        False -> #(int.max(1, width * max_height / height), max_height)
      }
      case new_width == width && new_height == height {
        True -> Ok(sprite)
        False ->
          case new_width < width || new_height < height {
            True -> resample(pixels, width, height, new_width, new_height)
            False ->
              case allow_upscale {
                True -> resample(pixels, width, height, new_width, new_height)
                False -> Ok(sprite)
              }
          }
      }
    }
  }
}

fn resample(
  pixels: BitArray,
  width: Int,
  height: Int,
  new_width: Int,
  new_height: Int,
) -> Result(Sprite, JpegError) {
  let x_offsets =
    indices(new_width)
    |> list.map(fn(x) { { 2 * x + 1 } * width / { 2 * new_width } * 4 })
  let rows =
    indices(new_height)
    |> list.try_map(fn(y) {
      let source_y = { 2 * y + 1 } * height / { 2 * new_height }
      use row <- result.try(
        bit_array.slice(pixels, source_y * width * 4, width * 4)
        |> result.replace_error(DecodeFailed),
      )
      list.try_map(x_offsets, fn(offset) {
        bit_array.slice(row, offset, 4)
        |> result.replace_error(DecodeFailed)
      })
      |> result.map(bit_array.concat)
    })
  use rows <- result.map(rows)
  Rgba8888(new_width, new_height, bit_array.concat(rows))
}

type FrameComp {
  FrameComp(id: Int, h: Int, v: Int, tq: Int)
}

type Frame {
  Frame(width: Int, height: Int, comps: List(FrameComp))
}

type Tables {
  Tables(
    quant: Dict(Int, List(Int)),
    huff: Dict(Int, Dict(Int, Int)),
    restart: Int,
  )
}

type Comp {
  Comp(
    h: Int,
    v: Int,
    dc: Dict(Int, Int),
    ac: Dict(Int, Int),
    dc_map: HuffmanMap,
    ac_map: HuffmanMap,
    quant: Dict(Int, #(Int, Int)),
    pred: Int,
  )
}

type Layout {
  Layout(
    width: Int,
    height: Int,
    hmax: Int,
    vmax: Int,
    mcus_x: Int,
    mcus_y: Int,
    restart: Int,
  )
}

const zigzag = [
  0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48,
  41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22,
  15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55,
  62, 63,
]

fn indices(count: Int) -> List(Int) {
  int.range(0, count, [], fn(acc, i) { [i, ..acc] }) |> list.reverse
}

fn shr(value: Int, bits: Int) -> Int {
  int.bitwise_shift_right(value, bits)
}

fn shl(value: Int, bits: Int) -> Int {
  int.bitwise_shift_left(value, bits)
}

fn band(a: Int, b: Int) -> Int {
  int.bitwise_and(a, b)
}

fn parse_segments(
  data: BitArray,
  frame: Option(Frame),
  tables: Tables,
  mode: Mode,
) -> Result(Sprite, JpegError) {
  case data {
    <<0xFF, rest:bytes>> ->
      case rest {
        <<0xFF, _:bytes>> -> parse_segments(rest, frame, tables, mode)
        <<marker, after:bytes>> ->
          handle_marker(marker, after, frame, tables, mode)
        _ -> Error(Truncated)
      }
    <<>> -> Error(Truncated)
    _ -> Error(DecodeFailed)
  }
}

fn handle_marker(
  marker: Int,
  after: BitArray,
  frame: Option(Frame),
  tables: Tables,
  mode: Mode,
) -> Result(Sprite, JpegError) {
  case marker {
    0x00 | 0x01 | 0xD8 -> parse_segments(after, frame, tables, mode)
    _ if marker >= 0xD0 && marker <= 0xD7 ->
      parse_segments(after, frame, tables, mode)
    0xD9 -> Error(DecodeFailed)
    0xC2
    | 0xC3
    | 0xC5
    | 0xC6
    | 0xC7
    | 0xC9
    | 0xCA
    | 0xCB
    | 0xCD
    | 0xCE
    | 0xCF -> Error(Unsupported)
    _ -> {
      use #(payload, rest) <- result.try(take_segment(after))
      case marker {
        0xC0 | 0xC1 -> {
          use frame <- result.try(parse_sof(payload))
          parse_segments(rest, Some(frame), tables, mode)
        }
        0xC4 -> {
          use tables <- result.try(parse_dht(payload, tables))
          parse_segments(rest, frame, tables, mode)
        }
        0xDB -> {
          use tables <- result.try(parse_dqt(payload, tables))
          parse_segments(rest, frame, tables, mode)
        }
        0xDD ->
          case payload {
            <<interval:size(16), _:bytes>> ->
              parse_segments(
                rest,
                frame,
                Tables(..tables, restart: interval),
                mode,
              )
            _ -> Error(DecodeFailed)
          }
        0xDA ->
          case frame {
            Some(frame) -> start_scan(payload, rest, frame, tables, mode)
            None -> Error(DecodeFailed)
          }
        _ -> parse_segments(rest, frame, tables, mode)
      }
    }
  }
}

fn take_segment(data: BitArray) -> Result(#(BitArray, BitArray), JpegError) {
  case data {
    <<length:size(16), rest:bytes>> if length >= 2 -> {
      let size = length - 2
      case rest {
        <<payload:bytes-size(size), after:bytes>> -> Ok(#(payload, after))
        _ -> Error(Truncated)
      }
    }
    <<_:size(16), _:bytes>> -> Error(DecodeFailed)
    _ -> Error(Truncated)
  }
}

fn bytes_to_list(data: BitArray, acc: List(Int)) -> List(Int) {
  case data {
    <<byte, rest:bytes>> -> bytes_to_list(rest, [byte, ..acc])
    _ -> list.reverse(acc)
  }
}

fn parse_sof(payload: BitArray) -> Result(Frame, JpegError) {
  case payload {
    <<precision, height:size(16), width:size(16), count, rest:bytes>> -> {
      case precision == 8 && width > 0 && height > 0 {
        False -> Error(Unsupported)
        True ->
          case count {
            1 | 3 -> {
              use comps <- result.try(parse_frame_comps(rest, count, count, []))
              Ok(Frame(width, height, comps))
            }
            _ -> Error(Unsupported)
          }
      }
    }
    _ -> Error(Truncated)
  }
}

fn parse_frame_comps(
  data: BitArray,
  remaining: Int,
  count: Int,
  acc: List(FrameComp),
) -> Result(List(FrameComp), JpegError) {
  case remaining {
    0 -> Ok(list.reverse(acc))
    _ ->
      case data {
        <<id, sampling, tq, rest:bytes>> -> {
          let #(h, v) = case count {
            1 -> #(1, 1)
            _ -> #(shr(sampling, 4), band(sampling, 15))
          }
          case h >= 1 && v >= 1 {
            False -> Error(DecodeFailed)
            True ->
              parse_frame_comps(rest, remaining - 1, count, [
                FrameComp(id, h, v, tq),
                ..acc
              ])
          }
        }
        _ -> Error(Truncated)
      }
  }
}

fn parse_dqt(payload: BitArray, tables: Tables) -> Result(Tables, JpegError) {
  case payload {
    <<>> -> Ok(tables)
    <<info, rest:bytes>> -> {
      let precision = shr(info, 4)
      let id = band(info, 15)
      case precision {
        0 ->
          case rest {
            <<table:bytes-size(64), after:bytes>> ->
              parse_dqt(after, put_quant(tables, id, bytes_to_list(table, [])))
            _ -> Error(Truncated)
          }
        1 ->
          case rest {
            <<table:bytes-size(128), after:bytes>> ->
              parse_dqt(after, put_quant(tables, id, wide_values(table, [])))
            _ -> Error(Truncated)
          }
        _ -> Error(DecodeFailed)
      }
    }
    _ -> Error(Truncated)
  }
}

fn wide_values(data: BitArray, acc: List(Int)) -> List(Int) {
  case data {
    <<value:size(16), rest:bytes>> -> wide_values(rest, [value, ..acc])
    _ -> list.reverse(acc)
  }
}

fn put_quant(tables: Tables, id: Int, values: List(Int)) -> Tables {
  Tables(..tables, quant: dict.insert(tables.quant, id, values))
}

fn parse_dht(payload: BitArray, tables: Tables) -> Result(Tables, JpegError) {
  case payload {
    <<>> -> Ok(tables)
    <<info, counts:bytes-size(16), rest:bytes>> -> {
      let count_list = bytes_to_list(counts, [])
      let total = int.sum(count_list)
      case rest {
        <<symbols:bytes-size(total), after:bytes>> -> {
          let table =
            build_huffman(
              count_list,
              bytes_to_list(symbols, []),
              1,
              0,
              dict.new(),
            )
          let key = shr(info, 4) * 16 + band(info, 15)
          parse_dht(
            after,
            Tables(..tables, huff: dict.insert(tables.huff, key, table)),
          )
        }
        _ -> Error(Truncated)
      }
    }
    _ -> Error(Truncated)
  }
}

fn build_huffman(
  counts: List(Int),
  symbols: List(Int),
  length: Int,
  code: Int,
  acc: Dict(Int, Int),
) -> Dict(Int, Int) {
  case counts {
    [] -> acc
    [count, ..more] -> {
      let #(these, remaining) = list.split(symbols, count)
      let acc =
        list.index_fold(these, acc, fn(acc, symbol, index) {
          dict.insert(acc, length * 65_536 + code + index, symbol)
        })
      build_huffman(more, remaining, length + 1, shl(code + count, 1), acc)
    }
  }
}

fn start_scan(
  payload: BitArray,
  data: BitArray,
  frame: Frame,
  tables: Tables,
  mode: Mode,
) -> Result(Sprite, JpegError) {
  case payload {
    <<count, rest:bytes>> ->
      case count == list.length(frame.comps) {
        False -> Error(Unsupported)
        True -> {
          use comps <- result.try(
            scan_components(rest, frame.comps, tables, []),
          )
          decode_mcus(frame, comps, tables.restart, data, mode)
        }
      }
    _ -> Error(Truncated)
  }
}

fn scan_components(
  data: BitArray,
  frame_comps: List(FrameComp),
  tables: Tables,
  acc: List(Comp),
) -> Result(List(Comp), JpegError) {
  case frame_comps {
    [] -> Ok(list.reverse(acc))
    [fc, ..more] ->
      case data {
        <<id, selectors, rest:bytes>> if id == fc.id -> {
          use dc <- result.try(lookup(tables.huff, shr(selectors, 4)))
          use ac <- result.try(lookup(tables.huff, 16 + band(selectors, 15)))
          use qt <- result.try(lookup(tables.quant, fc.tq))
          let quant =
            list.zip(zigzag, qt)
            |> list.index_map(fn(entry, k) { #(k, entry) })
            |> dict.from_list
          let comp =
            Comp(
              fc.h,
              fc.v,
              dc,
              ac,
              map_from_list(dict.to_list(dc)),
              map_from_list(dict.to_list(ac)),
              quant,
              0,
            )
          scan_components(rest, more, tables, [comp, ..acc])
        }
        <<_, _, _:bytes>> -> Error(Unsupported)
        _ -> Error(Truncated)
      }
  }
}

fn lookup(table: Dict(Int, a), key: Int) -> Result(a, JpegError) {
  dict.get(table, key) |> result.replace_error(DecodeFailed)
}

fn ceil_div(a: Int, b: Int) -> Int {
  { a + b - 1 } / b
}

fn decode_mcus(
  frame: Frame,
  comps: List(Comp),
  restart: Int,
  data: BitArray,
  mode: Mode,
) -> Result(Sprite, JpegError) {
  let hmax = list.fold(comps, 1, fn(m, c) { int.max(m, c.h) })
  let vmax = list.fold(comps, 1, fn(m, c) { int.max(m, c.v) })
  case list.all(comps, fn(c) { hmax % c.h == 0 && vmax % c.v == 0 }) {
    False -> Error(Unsupported)
    True -> {
      let mcus_x = ceil_div(frame.width, hmax * 8)
      let full_mcus_y = ceil_div(frame.height, vmax * 8)
      let mcus_y = case mode {
        Full -> full_mcus_y
        Preview(_) -> int.min(full_mcus_y, preview_max_mcu_rows)
      }
      let #(width, height) = case mode {
        Full -> #(frame.width, frame.height)
        // One sample per 8×8 block (chroma still upsampled by H/V).
        Preview(_) -> #(mcus_x * hmax, mcus_y * vmax)
      }
      case mode {
        Preview(_) ->
          io.println(
            "jpeg preview "
            <> int.to_string(frame.width)
            <> "x"
            <> int.to_string(frame.height)
            <> " -> "
            <> int.to_string(width)
            <> "x"
            <> int.to_string(height)
            <> " ("
            <> int.to_string(mcus_y)
            <> "/"
            <> int.to_string(full_mcus_y)
            <> " mcu rows)",
          )
        Full -> Nil
      }
      let layout = Layout(width, height, hmax, vmax, mcus_x, mcus_y, restart)
      decode_rows(layout, 0, Reader(data, 0, 0, 0), comps, 0, [], mode)
    }
  }
}

fn decode_rows(
  layout: Layout,
  row: Int,
  reader: Reader,
  comps: List(Comp),
  index: Int,
  out: List(BitArray),
  mode: Mode,
) -> Result(Sprite, JpegError) {
  case row >= layout.mcus_y {
    True -> {
      let pixels = bit_array.concat(list.reverse(out))
      use pixels <- result.map(
        bit_array.slice(pixels, 0, layout.width * layout.height * 4)
        |> result.replace_error(DecodeFailed),
      )
      Rgba8888(layout.width, layout.height, pixels)
    }
    False -> {
      case mode {
        Preview(_) ->
          io.println(
            "jpeg mcu row "
            <> int.to_string(row + 1)
            <> "/"
            <> int.to_string(layout.mcus_y),
          )
        Full -> Nil
      }
      use #(mcus, reader, comps, index) <- result.try(decode_row_mcus(
        layout,
        0,
        reader,
        comps,
        index,
        [],
        mode,
      ))
      use pixels <- result.try(mcu_row_pixels(layout, comps, mcus))
      let out = [pixels, ..out]
      case mode {
        Preview(on_partial) -> {
          let height_so_far = { row + 1 } * layout.vmax
          let partial = bit_array.concat(list.reverse(out))
          case bit_array.slice(partial, 0, layout.width * height_so_far * 4) {
            Ok(bytes) ->
              on_partial(Rgba8888(layout.width, height_so_far, bytes))
            Error(Nil) -> Nil
          }
        }
        Full -> Nil
      }
      decode_rows(layout, row + 1, reader, comps, index, out, mode)
    }
  }
}

fn decode_row_mcus(
  layout: Layout,
  mx: Int,
  reader: Reader,
  comps: List(Comp),
  index: Int,
  acc: List(List(List(BitArray))),
  mode: Mode,
) -> Result(#(List(List(List(BitArray))), Reader, List(Comp), Int), JpegError) {
  case mx == layout.mcus_x {
    True -> Ok(#(list.reverse(acc), reader, comps, index))
    False -> {
      let #(reader, comps) = case
        layout.restart > 0 && index > 0 && index % layout.restart == 0
      {
        True -> #(restart_reader(reader), reset_preds(comps))
        False -> #(reader, comps)
      }
      use #(strips, comps, reader) <- result.try(decode_mcu(
        reader,
        comps,
        [],
        [],
        mode,
      ))
      case reader.pad > 2 {
        True ->
          case reader.data {
            <<>> -> Error(Truncated)
            _ -> Error(DecodeFailed)
          }
        False ->
          decode_row_mcus(
            layout,
            mx + 1,
            reader,
            comps,
            index + 1,
            [strips, ..acc],
            mode,
          )
      }
    }
  }
}

fn reset_preds(comps: List(Comp)) -> List(Comp) {
  list.map(comps, fn(comp) { Comp(..comp, pred: 0) })
}

fn decode_mcu(
  reader: Reader,
  comps: List(Comp),
  done: List(Comp),
  strips: List(List(BitArray)),
  mode: Mode,
) -> Result(#(List(List(BitArray)), List(Comp), Reader), JpegError) {
  case comps {
    [] -> Ok(#(list.reverse(strips), list.reverse(done), reader))
    [comp, ..rest] -> {
      use #(blocks, pred, reader) <- result.try(decode_blocks(
        reader,
        comp,
        comp.pred,
        comp.h * comp.v,
        [],
        mode,
      ))
      decode_mcu(
        reader,
        rest,
        [Comp(..comp, pred: pred), ..done],
        [block_strips(blocks, comp.h), ..strips],
        mode,
      )
    }
  }
}

fn decode_blocks(
  reader: Reader,
  comp: Comp,
  pred: Int,
  remaining: Int,
  acc: List(List(BitArray)),
  mode: Mode,
) -> Result(#(List(List(BitArray)), Int, Reader), JpegError) {
  case remaining {
    0 -> Ok(#(list.reverse(acc), pred, reader))
    _ -> {
      use #(rows, pred, reader) <- result.try(decode_block(
        reader,
        comp,
        pred,
        mode,
      ))
      decode_blocks(reader, comp, pred, remaining - 1, [rows, ..acc], mode)
    }
  }
}

fn block_strips(blocks: List(List(BitArray)), h: Int) -> List(BitArray) {
  list.sized_chunk(blocks, h)
  |> list.flat_map(fn(group) { transpose(group) |> list.map(bit_array.concat) })
}

fn transpose(rows: List(List(a))) -> List(List(a)) {
  case rows {
    [] -> []
    [[], ..] -> []
    _ -> {
      let heads = list.filter_map(rows, list.first)
      let tails = list.map(rows, fn(row) { list.drop(row, 1) })
      [heads, ..transpose(tails)]
    }
  }
}

fn mcu_row_pixels(
  layout: Layout,
  comps: List(Comp),
  mcus: List(List(List(BitArray))),
) -> Result(BitArray, JpegError) {
  let planes =
    transpose(mcus)
    |> list.map(fn(per_mcu) { transpose(per_mcu) |> list.map(bit_array.concat) })
    |> list.map2(comps, fn(rows, comp) {
      let hf = layout.hmax / comp.h
      let vf = layout.vmax / comp.v
      list.flat_map(rows, fn(row) { list.repeat(expand_row(row, hf, <<>>), vf) })
    })
  case planes {
    [y] ->
      Ok(
        list.map(y, fn(row) { gray_row(row, layout.width, <<>>) })
        |> bit_array.concat,
      )
    [y, cb, cr] ->
      Ok(
        list.zip(y, list.zip(cb, cr))
        |> list.map(fn(rows) {
          let #(y, #(cb, cr)) = rows
          ycc_row(y, cb, cr, layout.width, <<>>)
        })
        |> bit_array.concat,
      )
    _ -> Error(DecodeFailed)
  }
}

fn expand_row(row: BitArray, factor: Int, acc: BitArray) -> BitArray {
  case factor {
    1 -> row
    _ ->
      case row {
        <<byte, rest:bytes>> ->
          expand_row(rest, factor, repeat_byte(byte, factor, acc))
        _ -> acc
      }
  }
}

fn repeat_byte(byte: Int, times: Int, acc: BitArray) -> BitArray {
  case times {
    0 -> acc
    _ -> repeat_byte(byte, times - 1, <<acc:bits, byte>>)
  }
}

fn gray_row(row: BitArray, remaining: Int, acc: BitArray) -> BitArray {
  case remaining, row {
    0, _ -> acc
    _, <<value, rest:bytes>> ->
      gray_row(rest, remaining - 1, <<acc:bits, value, value, value, 255>>)
    _, _ -> acc
  }
}

fn clamp(value: Int) -> Int {
  int.clamp(value, 0, 255)
}

fn ycc_row(
  y: BitArray,
  cb: BitArray,
  cr: BitArray,
  remaining: Int,
  acc: BitArray,
) -> BitArray {
  case remaining, y, cb, cr {
    0, _, _, _ -> acc
    _,
      <<luma, y_rest:bytes>>,
      <<blue_diff, cb_rest:bytes>>,
      <<red_diff, cr_rest:bytes>>
    -> {
      let cb_off = blue_diff - 128
      let cr_off = red_diff - 128
      let red = clamp(luma + shr(91_881 * cr_off + 32_768, 16))
      let green =
        clamp(luma + shr(32_768 - 22_554 * cb_off - 46_802 * cr_off, 16))
      let blue = clamp(luma + shr(116_130 * cb_off + 32_768, 16))
      ycc_row(y_rest, cb_rest, cr_rest, remaining - 1, <<
        acc:bits,
        red,
        green,
        blue,
        255,
      >>)
    }
    _, _, _, _ -> acc
  }
}

type Reader {
  Reader(data: BitArray, buf: Int, cnt: Int, pad: Int)
}

fn restart_reader(reader: Reader) -> Reader {
  Reader(skip_to_restart(reader.data), 0, 0, 0)
}

fn skip_to_restart(data: BitArray) -> BitArray {
  case data {
    <<0xFF, marker, rest:bytes>> if marker >= 0xD0 && marker <= 0xD7 -> rest
    <<_, rest:bytes>> -> skip_to_restart(rest)
    _ -> <<>>
  }
}

// Past EOF or a marker the reader feeds zero bytes and counts them in `pad`.
fn fill(reader: Reader) -> Reader {
  let kept = shl(band(reader.buf, shl(1, reader.cnt) - 1), 8)
  case reader.data {
    <<0xFF, 0x00, rest:bytes>> ->
      Reader(rest, kept + 0xFF, reader.cnt + 8, reader.pad)
    <<0xFF, _:bytes>> | <<>> ->
      Reader(reader.data, kept, reader.cnt + 8, reader.pad + 1)
    <<byte, rest:bytes>> ->
      Reader(rest, kept + byte, reader.cnt + 8, reader.pad)
    _ -> Reader(reader.data, kept, reader.cnt + 8, reader.pad + 1)
  }
}

fn read_bits(reader: Reader, count: Int) -> #(Int, Reader) {
  case reader.cnt < count {
    True -> read_bits(fill(reader), count)
    False -> {
      let remaining = reader.cnt - count
      let value = band(shr(reader.buf, remaining), shl(1, count) - 1)
      #(value, Reader(..reader, cnt: remaining))
    }
  }
}

fn decode_huffman(
  reader: Reader,
  table: Dict(Int, Int),
  code: Int,
  length: Int,
) -> Result(#(Int, Reader), JpegError) {
  case length >= 16 {
    True -> Error(DecodeFailed)
    False -> {
      let #(bit, reader) = read_bits(reader, 1)
      let code = code * 2 + bit
      let length = length + 1
      case dict.get(table, length * 65_536 + code) {
        Ok(symbol) -> Ok(#(symbol, reader))
        Error(_) -> decode_huffman(reader, table, code, length)
      }
    }
  }
}

fn receive_extend(
  reader: Reader,
  size: Int,
) -> Result(#(Int, Reader), JpegError) {
  case size {
    0 -> Ok(#(0, reader))
    _ if size > 15 -> Error(DecodeFailed)
    _ -> {
      let #(value, reader) = read_bits(reader, size)
      case value < shl(1, size - 1) {
        True -> Ok(#(value - shl(1, size) + 1, reader))
        False -> Ok(#(value, reader))
      }
    }
  }
}

fn decode_block(
  reader: Reader,
  comp: Comp,
  pred: Int,
  mode: Mode,
) -> Result(#(List(BitArray), Int, Reader), JpegError) {
  use #(_, dc_quant) <- result.try(lookup(comp.quant, 0))
  case mode {
    Preview(_) -> {
      let ctx = make_block_ctx(comp.dc_map, comp.ac_map, dc_quant, pred)
      case
        decode_dc_and_discard_ac_ffi(
          reader.data,
          reader.buf,
          reader.cnt,
          reader.pad,
          ctx,
        )
      {
        Ok(#(value, new_pred, data, buf, cnt, pad)) ->
          Ok(#([<<value>>], new_pred, Reader(data, buf, cnt, pad)))
        Error(Nil) -> Error(DecodeFailed)
      }
    }
    Full -> {
      use #(size, reader) <- result.try(decode_huffman(reader, comp.dc, 0, 0))
      use #(diff, reader) <- result.try(receive_extend(reader, size))
      let pred = pred + diff
      let dc = pred * dc_quant
      use #(coefs, reader) <- result.map(decode_ac(
        reader,
        comp,
        1,
        dict.from_list([#(0, dc)]),
      ))
      #(idct(coefs), pred, reader)
    }
  }
}

fn decode_ac(
  reader: Reader,
  comp: Comp,
  k: Int,
  coefs: Dict(Int, Int),
) -> Result(#(Dict(Int, Int), Reader), JpegError) {
  case k > 63 {
    True -> Ok(#(coefs, reader))
    False -> {
      use #(symbol, reader) <- result.try(decode_huffman(reader, comp.ac, 0, 0))
      let run = shr(symbol, 4)
      let size = band(symbol, 15)
      case size {
        0 ->
          case run {
            15 -> decode_ac(reader, comp, k + 16, coefs)
            _ -> Ok(#(coefs, reader))
          }
        _ -> {
          let k = k + run
          case k > 63 {
            True -> Error(DecodeFailed)
            False -> {
              use #(value, reader) <- result.try(receive_extend(reader, size))
              use #(natural, quant) <- result.try(lookup(comp.quant, k))
              decode_ac(
                reader,
                comp,
                k + 1,
                dict.insert(coefs, natural, value * quant),
              )
            }
          }
        }
      }
    }
  }
}

fn idct(coefs: Dict(Int, Int)) -> List(BitArray) {
  case dict.size(coefs) {
    1 -> {
      let dc = dict.get(coefs, 0) |> result.unwrap(0)
      let value = clamp(shr(dc + 4, 3) + 128)
      list.repeat(<<value, value, value, value, value, value, value, value>>, 8)
    }
    _ -> {
      let columns =
        indices(8)
        |> list.map(fn(i) {
          let s = fn(row) { dict.get(coefs, row * 8 + i) |> result.unwrap(0) }
          let #(x0, x1, x2, x3, t0, t1, t2, t3) =
            idct_1d(s(0), s(1), s(2), s(3), s(4), s(5), s(6), s(7))
          [
            shr(x0 + t3 + 512, 10),
            shr(x1 + t2 + 512, 10),
            shr(x2 + t1 + 512, 10),
            shr(x3 + t0 + 512, 10),
            shr(x3 - t0 + 512, 10),
            shr(x2 - t1 + 512, 10),
            shr(x1 - t2 + 512, 10),
            shr(x0 - t3 + 512, 10),
          ]
        })
      transpose(columns)
      |> list.map(fn(row) {
        case row {
          [s0, s1, s2, s3, s4, s5, s6, s7] -> {
            let #(x0, x1, x2, x3, t0, t1, t2, t3) =
              idct_1d(s0, s1, s2, s3, s4, s5, s6, s7)
            let bias = 65_536 + shl(128, 17)
            <<
              clamp(shr(x0 + t3 + bias, 17)),
              clamp(shr(x1 + t2 + bias, 17)),
              clamp(shr(x2 + t1 + bias, 17)),
              clamp(shr(x3 + t0 + bias, 17)),
              clamp(shr(x3 - t0 + bias, 17)),
              clamp(shr(x2 - t1 + bias, 17)),
              clamp(shr(x1 - t2 + bias, 17)),
              clamp(shr(x0 - t3 + bias, 17)),
            >>
          }
          _ -> <<>>
        }
      })
    }
  }
}

fn idct_1d(
  s0: Int,
  s1: Int,
  s2: Int,
  s3: Int,
  s4: Int,
  s5: Int,
  s6: Int,
  s7: Int,
) -> #(Int, Int, Int, Int, Int, Int, Int, Int) {
  let p1 = { s2 + s6 } * 2217
  let t2 = p1 + s6 * -7567
  let t3 = p1 + s2 * 3135
  let t0 = shl(s0 + s4, 12)
  let t1 = shl(s0 - s4, 12)
  let x0 = t0 + t3
  let x3 = t0 - t3
  let x1 = t1 + t2
  let x2 = t1 - t2

  let q3 = s7 + s3
  let q4 = s5 + s1
  let q1 = s7 + s1
  let q2 = s5 + s3
  let q5 = { q3 + q4 } * 4816
  let u0 = s7 * 1223
  let u1 = s5 * 8410
  let u2 = s3 * 12_586
  let u3 = s1 * 6149
  let q1 = q5 + q1 * -3685
  let q2 = q5 + q2 * -10_497
  let q3 = q3 * -8034
  let q4 = q4 * -1597
  #(x0, x1, x2, x3, u0 + q1 + q3, u1 + q2 + q4, u2 + q2 + q3, u3 + q1 + q4)
}
