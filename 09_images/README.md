# Exercise 9: show PNG/GIF art on AtomGL

Decodes Lucy (PNG + spinning GIF) on the host, embeds rgba8888 dumps, and
draws them on AtomGL.

Regenerate after changing `assets/src/`:

```sh
cd ../atomgl_image_dump
gleam run -- \
  --png ../09_images/assets/src/lucy.png \
  --gif ../09_images/assets/src/lucy_spin.gif \
  --decoded ../09_images/assets/decoded \
  --module ../09_images/src/assets.gleam \
  --png-stem lucy --gif-stem lucy_spin \
  --png-fn lucy_png --gif-fn lucy_spin_frames
```

```sh
gleam test
gleam run -m orbital flash esp32
gleam run -m orbital monitor
```

Lucy is part of [Gleam’s branding](https://gleam.run/branding/)
([Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0)).
