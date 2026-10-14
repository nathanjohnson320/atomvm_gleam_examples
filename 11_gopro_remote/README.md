# Exercise 11: GoPro media gallery

Joins the Hero 10’s Wi‑Fi AP, lists JPG files from
`GET /gopro/media/list`, and browses thumbnails with the badge arrow keys.
A thin status bar shows battery, REC/idle, `i/n`, and the filename. This is
**not** live preview — only files already on the SD card.

## Camera setup

1. **Connections → Wi‑Fi Band → 2.4 GHz** (ESP32 cannot join 5 GHz).
2. **Prime the AP with Quik** (phone/iPad): open the camera in Quik and go into
   **media** or **live preview**. That wakes Wi‑Fi *and* DHCP. Then fully leave
   the GoPro SSID / kill Quik’s hold on it so the badge can take the client
   slot. Without this step the badge often associates (`STA_CONNECTED`) but
   never gets an IP — the screen used to sit on “Connecting…” forever; it now
   shows “Assoc OK, no DHCP” and retries.
3. Put SSID/PSK from **Connections → Camera Info** in `src/config.gleam`
   locally — do not commit real values.

Intermittent “stuck connecting” is almost always DHCP, not the password: Quik
still on the SSID, AP not primed, or a stale associate without a lease. Re-open
Quik media once, leave the network, then flash/monitor again.

Sanity check from a laptop on the GoPro network:

```sh
curl "http://10.5.5.9:8080/gopro/camera/state"
curl "http://10.5.5.9:8080/gopro/media/list"
```

## Badge usage

- **Arrow keys** (bottom-right cluster: Left / Right / Up / Down): previous /
  next JPG (wraps). Index in the status bar updates immediately; the thumb
  loads in the background.
- Status strip: battery, idle/REC, index, filename
- Main area: GoPro `/gopro/media/thumbnail` (smallest HTTP image; screennail is
  larger), decoded with the badge AtomVM `jpeg:decode/2` C NIF (esp_jpeg/tjpgd)
  when that firmware is installed; otherwise a slower Gleam DC-only preview

## AtomVM JPEG NIF (once)

Thumbnails need the `atomvm_jpeg` component in the badge VM (not the Gleam
`.avm`). Rebuild the VM, then flash only the app partition at `0x10000`
(keeps NVS and `main.avm`):

```sh
# Badge AtomVM tree; ESP-IDF v5.5.5 (or espressif/idf:v5.5.5 Docker):
src/platforms/esp32/badge/build.sh --vm-only
esptool --chip esp32s3 -b 921600 write-flash 0x10000 \
  src/platforms/esp32/build-badge/out/atomvm-esp32s3-badge.bin
```

`orbital flash` alone does not update the VM — only the app pack.

```sh
gleam test
gleam run -m orbital flash esp32
# DHCP can take a while after association; give the monitor room.
gleam run -m orbital monitor --timeout 60
```
