/// Status strip + thumbnail (or text) for the GoPro media gallery.
import atomgl_image/item.{type Item, Default16px, Image, Rect, Text, Transparent}
import atomgl_image/sprite.{type Sprite, Rgba8888}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gopro.{type Snapshot}

const background = 0x000000

const status_bg = 0x101010

const label = 0x808080

const value = 0xffffff

const warn = 0xff5252

const status_h = 28

pub type View {
  /// Progress line while joining the GoPro AP / waiting for DHCP.
  Connecting(String)
  LoadingList
  Empty
  Error(String)
  Gallery(
    snapshot: Option(Snapshot),
    index: Int,
    count: Int,
    filename: String,
    thumb: Option(Sprite),
    thumb_note: Option(String),
  )
}

/// First item is on top; background rects stay last.
///
/// AtomGL's damage box **skips** a single full-screen `rect` (it assumes that
/// is a static clear). Split into two halves so the whole panel is in the
/// content box and old pixels (other apps / larger thumbs) get wiped.
pub fn render(width: Int, height: Int, view: View) -> List(Item) {
  let mid = height / 2
  list.append(content(width, height, view), [
    Rect(0, 0, width, mid, background),
    Rect(0, mid, width, height - mid, background),
  ])
}

pub fn image_region_height(height: Int) -> Int {
  case height > status_h {
    True -> height - status_h
    False -> height
  }
}

fn content(width: Int, height: Int, view: View) -> List(Item) {
  case view {
    Connecting(message) -> [
      Text(12, 56, Default16px, value, Transparent, utf8(message)),
    ]
    LoadingList -> [
      Text(12, 56, Default16px, value, Transparent, <<
        "Loading media...":utf8,
      >>),
    ]
    Empty -> [
      Text(12, 56, Default16px, value, Transparent, <<"No JPG files":utf8>>),
    ]
    Error(message) -> [
      Text(12, 56, Default16px, warn, Transparent, utf8(message)),
    ]
    Gallery(snapshot:, index:, count:, filename:, thumb:, thumb_note:) ->
      list.append(thumb_items(width, height, thumb, thumb_note), [
        status_line(snapshot, index, count, filename),
        Rect(0, 0, width, status_h, status_bg),
      ])
  }
}

fn status_line(
  snapshot: Option(Snapshot),
  index: Int,
  count: Int,
  filename: String,
) -> Item {
  let batt = case snapshot {
    Some(s) -> gopro.battery_label(s.battery_percent, s.battery_bars)
    None -> "--"
  }
  let rec = case snapshot {
    Some(s) ->
      case s.encoding {
        True -> "REC"
        False -> "idle"
      }
    None -> "?"
  }
  let colour = case snapshot {
    Some(s) if s.encoding -> warn
    _ -> value
  }
  let counter = int.to_string(index + 1) <> "/" <> int.to_string(count)
  let line =
    batt <> " " <> rec <> " " <> counter <> " " <> truncate(filename, 16)
  Text(6, 6, Default16px, colour, Transparent, utf8(line))
}

fn thumb_items(
  width: Int,
  height: Int,
  thumb: Option(Sprite),
  note: Option(String),
) -> List(Item) {
  let region_h = image_region_height(height)
  // Opaque wipe of the image band (not full-screen, so it counts as damage).
  let clear = Rect(0, status_h, width, region_h, background)
  case thumb {
    Some(sprite) -> {
      let Rgba8888(sw, _sh, _) = sprite
      let x = case width > sw {
        True -> { width - sw } / 2
        False -> 0
      }
      [Image(x, status_h, Transparent, sprite), clear]
    }
    None -> {
      let msg = case note {
        Some(text) -> text
        None -> "No thumbnail"
      }
      [
        Text(12, status_h + 40, Default16px, label, Transparent, utf8(msg)),
        clear,
      ]
    }
  }
}

fn truncate(text: String, max: Int) -> String {
  case string.length(text) <= max {
    True -> text
    False -> string.slice(text, 0, max - 1) <> ".."
  }
}

fn utf8(text: String) -> BitArray {
  <<text:utf8>>
}
