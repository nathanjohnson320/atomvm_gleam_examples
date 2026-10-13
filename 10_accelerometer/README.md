# Exercise 10: tilt Lucy with the accelerometer

Tilt the badge and Lucy slides on the display until she hits an edge.

SC7A20 on I²C (`0x19`, SCL=10, SDA=11). ST7789 320×240 via SPI. Assumes the
AtomGL image from exercise 1 is already on the badge.

```sh
gleam test
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

Lucy is part of [Gleam’s branding](https://gleam.run/branding/)
([Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0)).
