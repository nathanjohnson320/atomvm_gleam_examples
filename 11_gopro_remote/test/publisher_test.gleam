import atomvm_gleam/network
import gallery
import gleeunit
import gopro
import publisher

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn ipv4_string_test() {
  assert publisher.ipv4_string(network.Ipv4Address(10, 5, 5, 9)) == "10.5.5.9"
}

pub fn parse_snapshot_test() {
  let body = <<
    "{\"status\":{\"2\":4,\"10\":0,\"30\":\"GP50091424\",\"35\":75555,\"54\":500444672,\"70\":85,\"75\":0,\"82\":1},\"settings\":{}}":utf8,
  >>
  let assert Ok(snapshot) = gopro.parse_snapshot(body)
  assert snapshot.name == "GP50091424"
  assert snapshot.battery_percent == 85
  assert snapshot.battery_bars == 4
  assert snapshot.encoding == False
  assert snapshot.ready == True
  assert snapshot.remaining_video_s == 75_555
  assert snapshot.sd_remaining_bytes == 500_444_672
  assert snapshot.zoom == 0
}

pub fn parse_media_list_jpgs_only_test() {
  let body = <<
    "{\"id\":\"x\",\"media\":[{\"d\":\"100GOPRO\",\"fs\":[{\"n\":\"GOPR0001.JPG\"},{\"n\":\"GX010002.MP4\"},{\"n\":\"GOPR0003.jpeg\"}]},{\"d\":\"101GOPRO\",\"fs\":[{\"n\":\"GOPR0010.JPG\"}]}]}":utf8,
  >>
  let assert Ok(items) = gopro.parse_media_list(body)
  assert items
    == [
      gopro.MediaItem("100GOPRO/GOPR0001.JPG", "100GOPRO", "GOPR0001.JPG"),
      gopro.MediaItem("100GOPRO/GOPR0003.jpeg", "100GOPRO", "GOPR0003.jpeg"),
      gopro.MediaItem("101GOPRO/GOPR0010.JPG", "101GOPRO", "GOPR0010.JPG"),
    ]
}

pub fn wrap_index_test() {
  assert gopro.wrap_index(0, 3) == 0
  assert gopro.wrap_index(3, 3) == 0
  assert gopro.wrap_index(-1, 3) == 2
  assert gopro.wrap_index(5, 0) == 0
}

pub fn short_filename_test() {
  assert gopro.short_filename("100GOPRO/GOPR0001.JPG") == "GOPR0001.JPG"
  assert gopro.short_filename("alone.JPG") == "alone.JPG"
}

pub fn key_changes_edge_test() {
  let prev = [#(5, 10)]
  let curr = [#(5, 10), #(5, 12)]
  let #(presses, releases) = gallery.changes(prev, curr)
  assert presses == [#(5, 12)]
  assert releases == []
}

pub fn format_video_remaining_test() {
  assert gopro.format_video_remaining(75_555) == "20h 59m"
  assert gopro.format_video_remaining(90) == "1m"
}

pub fn format_sd_remaining_test() {
  assert gopro.format_sd_remaining(500_444_672) == "500 MB"
  assert gopro.format_sd_remaining(1_500_000_000) == "1.5 GB"
}

pub fn battery_label_test() {
  assert gopro.battery_label(85, 4) == "85% charging"
  assert gopro.battery_label(85, 3) == "85%"
}
