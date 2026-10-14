import atomvm_gleam/display
import atomvm_gleam/network
import atomvm_gleam/spi
import config
import gallery
import gallery_scene
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gopro

const width = 320

const height = 240

pub fn start() -> Nil {
  case run() {
    Ok(Nil) -> Nil
    Error(message) -> io.println(message)
  }
}

fn run() -> Result(Nil, String) {
  use bus <- result.try(
    spi.open(
      spi.Params(
        bus_config: spi.BusConfig(
          peripheral: Some("spi2"),
          sclk: Some(5),
          mosi: Some(8),
          miso: Some(9),
          pico: None,
          poci: None,
        ),
        device_config: [],
      ),
    )
    |> result.map_error(fn(error) {
      "SPI open failed: " <> spi.error_to_string(error)
    }),
  )

  let screen =
    display.open(display.Config(
      compatible: "sitronix,st7789",
      init_seq_type: "alt_gamma_2",
      enable_tft_invon: True,
      width:,
      height:,
      rotation: 3,
      reset: 6,
      dc: 4,
      cs: 7,
      backlight: 3,
      backlight_active: display.Low,
      backlight_enabled: True,
      clock_speed_hz: None,
      spi_host: bus,
    ))

  show(screen, gallery_scene.Connecting("Connecting Wi-Fi..."))

  io.println("Connecting to " <> config.wifi_ssid <> "...")
  io.println("(Quik-prime media/preview, then leave the SSID — need DHCP)")

  use info <- result.try(
    connect_sta(screen, attempts: 5)
    |> result.map_error(fn(message) {
      show(screen, gallery_scene.Error(message))
      message
    }),
  )
  io.println("Connected, IP " <> ipv4_string(info.address))

  show(screen, gallery_scene.LoadingList)

  use items <- result.try(
    gopro.fetch_media_list()
    |> result.map_error(fn(message) {
      show(screen, gallery_scene.Error(message))
      message
    }),
  )
  io.println("JPG files: " <> int.to_string(list.length(items)))

  let snapshot = case gopro.fetch_snapshot() {
    Ok(s) -> Some(s)
    Error(message) -> {
      io.println("status: " <> message)
      None
    }
  }

  case items {
    [] -> {
      show(screen, gallery_scene.Empty)
      process.sleep_forever()
      Ok(Nil)
    }
    _ -> {
      gallery.start(screen, items, snapshot)
      Ok(Nil)
    }
  }
}

fn show(screen: display.Display, view: gallery_scene.View) -> Nil {
  display.update(screen, gallery_scene.render(width, height, view))
}

/// GoPro often associates (`STA_CONNECTED`) but never DHCP-leases until Quik
/// has primed the AP and no other client holds the single slot. Association
/// alone is not enough — we need `GOT_IP`. Short hostname avoids a DHCP stall
/// on AtomVM's long default `atomvm-<mac>` name.
fn connect_sta(
  screen: display.Display,
  attempts attempts: Int,
) -> Result(network.IpInfo, String) {
  let try_n = 6 - attempts
  show(
    screen,
    gallery_scene.Connecting("Wi-Fi try " <> int.to_string(try_n) <> "/5..."),
  )
  io.println("Wi-Fi attempt " <> int.to_string(try_n) <> "/5")

  let started =
    network.start(
      network.StaConfig(
        managed: False,
        ssid: Some(config.wifi_ssid),
        psk: Some(config.wifi_psk),
        dhcp_hostname: Some("badge"),
        notify: process.self(),
      ),
      None,
    )

  case started {
    Error(error) ->
      fail_or_retry(screen, attempts, network.error_to_string(error))
    Ok(Nil) ->
      // If DHCP is going to work it usually answers within ~10–15s after
      // associate; hanging 45s just looks "stuck" with no screen update.
      case await_got_ip(18_000) {
        Ok(info) -> Ok(info)
        Error(detail) -> {
          let _ = network.stop()
          fail_or_retry(screen, attempts, detail)
        }
      }
  }
}

fn fail_or_retry(
  screen: display.Display,
  attempts: Int,
  detail: String,
) -> Result(network.IpInfo, String) {
  let hint = dhcp_hint(detail)
  io.println("Wi-Fi failed (" <> detail <> ")")
  case attempts <= 1 {
    True ->
      Error(
        "No IP from " <> config.wifi_ssid <> " (" <> detail <> "). " <> hint,
      )
    False -> {
      show(screen, gallery_scene.Connecting(hint))
      process.sleep(2500)
      connect_sta(screen, attempts: attempts - 1)
    }
  }
}

fn dhcp_hint(detail: String) -> String {
  // AtomGL default16px is ASCII-ish; Unicode dashes garble on screen.
  case detail {
    "associated_no_ip" -> "Assoc OK, no DHCP - Quik again"
    "disconnected" -> "Dropped - retrying"
    _ -> "Waiting for DHCP..."
  }
}

@external(erlang, "gopro_net_ffi", "await_got_ip")
fn await_got_ip_ffi(
  timeout_ms: Int,
) -> Result(
  #(#(Int, Int, Int, Int), #(Int, Int, Int, Int), #(Int, Int, Int, Int)),
  String,
)

fn await_got_ip(timeout_ms: Int) -> Result(network.IpInfo, String) {
  case await_got_ip_ffi(timeout_ms) {
    Ok(#(address, netmask, gateway)) ->
      Ok(network.IpInfo(
        address: tuple_ip(address),
        netmask: tuple_ip(netmask),
        gateway: tuple_ip(gateway),
      ))
    Error(detail) -> Error(detail)
  }
}

fn tuple_ip(octets: #(Int, Int, Int, Int)) -> network.Ipv4Address {
  let #(a, b, c, d) = octets
  network.Ipv4Address(a, b, c, d)
}

pub fn ipv4_string(address: network.Ipv4Address) -> String {
  let network.Ipv4Address(a:, b:, c:, d:) = address
  int.to_string(a)
  <> "."
  <> int.to_string(b)
  <> "."
  <> int.to_string(c)
  <> "."
  <> int.to_string(d)
}
