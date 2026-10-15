# Exercise 12: TEA chat on AtomGL

Elm-shaped **init / update / view** + **effects**,

## Pages

Top bar uses the badge’s shape glyphs (■ Square, ▲ Triangle, ♦ Diamond):

| Key | Page |
|-----|------|
| **■ Square** | Home / profile. If unset, opens edit. |
| **♦ Diamond** | Edit profile (from home). Enter saves. |
| **▲ Triangle** | Chat (needs a username). |

Chat still `POST /messages` on Enter when `api_host` is configured.

```sh
gleam test
gleam run -m orbital flash esp32
gleam run -m orbital monitor --timeout 0
```

Edit `src/config.gleam` for Wi‑Fi + `api_host` (leave `YOUR_HOST` to skip HTTP).
