import atomvm_gleam/spi.{type Spi}
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result

const data_pin = 14

const peripheral = "spi3"

const device = "pixels"

const clock_speed_hz = 3_200_000

/// Idle bytes, long enough to hold the line low past the reset threshold.
const latch = <<
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
>>

/// Open SPI3 as a waveform generator for the SK6812 chain.
///
/// The chain has no clock or chip-select, so `sclk` and `cs` are -1 and
/// `miso` is omitted. Only GPIO 14 (MOSI) carries the data.
pub fn open() -> Result(Spi, String) {
  spi.open(
    spi.Params(
      bus_config: spi.BusConfig(
        peripheral: Some(peripheral),
        sclk: Some(-1),
        mosi: Some(data_pin),
        miso: None,
        pico: None,
        poci: None,
      ),
      device_config: [
        spi.DeviceConfig(
          name: device,
          cs: -1,
          clock_speed_hz: Some(clock_speed_hz),
          mode: Some(0),
          address_len_bits: Some(0),
          command_len_bits: Some(0),
        ),
      ],
    ),
  )
  |> result.map_error(fn(error) {
    "SPI open failed: " <> spi.error_to_string(error)
  })
}

/// Encode pixels as the SK6812 bitstream and clock them out.
pub fn write(spi_bus: Spi, pixels: List(#(Int, Int, Int))) -> Result(Nil, String) {
  let frame =
    pixels
    |> list.map(encode_pixel)
    |> bit_array.concat
    |> bit_array.append(latch)
  spi.write(
    spi_bus,
    device,
    spi.Transaction(
      command: None,
      address: None,
      write_data: Some(frame),
      write_bits: None,
      read_bits: None,
    ),
  )
  |> result.map_error(fn(error) {
    "SPI write failed: " <> spi.error_to_string(error)
  })
}

/// SK6812 and WS2812 both take green first.
pub fn encode_pixel(pixel: #(Int, Int, Int)) -> BitArray {
  let #(red, green, blue) = pixel
  bit_array.concat([encode_byte(green), encode_byte(red), encode_byte(blue)])
}

/// At 3.2 MHz each LED bit is four SPI bits: `0b1000` is zero, `0b1100` is one.
pub fn encode_byte(byte: Int) -> BitArray {
  <<
    expand(int.bitwise_shift_right(byte, 6)):size(8),
    expand(int.bitwise_shift_right(byte, 4)):size(8),
    expand(int.bitwise_shift_right(byte, 2)):size(8),
    expand(byte):size(8),
  >>
}

fn expand(bits: Int) -> Int {
  case int.bitwise_and(bits, 0x03) {
    0 -> 0x88
    1 -> 0x8c
    2 -> 0xc8
    _ -> 0xcc
  }
}
