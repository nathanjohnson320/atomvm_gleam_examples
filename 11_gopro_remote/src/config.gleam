/// GoPro AP credentials. Edit these before flashing.
///
/// Keep real passwords out of git — change locally and do not commit.
/// Camera Info password is usually word+digits (e.g. wave3020), not a
/// dashed Quik/pairing code. Use 2.4 GHz on the camera; disconnect the
/// phone from this SSID before the badge connects.
pub const wifi_ssid = "CHANGE ME"

pub const wifi_psk = "CHANGE ME"

/// GoPro Open GoPro HTTP endpoint (camera AP default).
pub const host = "10.5.5.9"

pub const port = 8080

pub const poll_interval_ms = 2000
