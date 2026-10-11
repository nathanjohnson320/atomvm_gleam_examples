#!/usr/bin/env python3
"""Generate AtomGL-friendly Lucy PNG + spinning GIF from the official SVG.

Requires: pip install pillow cairosvg

PNG uses stored (uncompressed) zlib blocks so `atomgl_image/png` can decode it.
GIF is GIF89a for `atomgl_image/gif`.

Source SVG: https://gleam.run/images/lucy/lucy.svg (Apache-2.0; see README).
"""

from __future__ import annotations

import struct
import zlib
from io import BytesIO
from pathlib import Path

from cairosvg import svg2png
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "assets" / "src"
SVG = ROOT / "lucy.svg"
SIZE = 32
FRAMES = 8  # 45° steps
DELAY_MS = 120


def write_stored_png(path: Path, rgba: bytes, width: int, height: int) -> None:
    assert len(rgba) == width * height * 4
    raw = b"".join(
        b"\x00" + rgba[y * width * 4 : (y + 1) * width * 4] for y in range(height)
    )
    cmf, flg = 0x78, 0x01
    assert ((cmf << 8) + flg) % 31 == 0
    chunks: list[bytes] = []
    offset = 0
    while offset < len(raw):
        piece = raw[offset : offset + 0xFFFF]
        offset += len(piece)
        bfinal = 1 if offset >= len(raw) else 0
        nlen = len(piece) ^ 0xFFFF
        chunks.append(
            bytes([bfinal]) + struct.pack("<HH", len(piece), nlen) + piece
        )
    zdata = (
        bytes([cmf, flg])
        + b"".join(chunks)
        + struct.pack(">I", zlib.adler32(raw) & 0xFFFFFFFF)
    )

    def chunk(tag: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zdata)
        + chunk(b"IEND", b"")
    )


def render_lucy(size: int) -> Image.Image:
    png_bytes = svg2png(
        url=str(SVG),
        output_width=size,
        output_height=size,
        background_color="rgba(0,0,0,0)",
    )
    img = Image.open(BytesIO(png_bytes)).convert("RGBA")
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    x = (size - img.width) // 2
    y = (size - img.height) // 2
    canvas.paste(img, (x, y), img)
    return canvas


def quantize_for_gif(frames: list[Image.Image]) -> list[Image.Image]:
    bg = (32, 32, 32, 255)
    composited = []
    for fr in frames:
        base = Image.new("RGBA", fr.size, bg)
        base.alpha_composite(fr)
        composited.append(base)

    sheet = Image.new("RGBA", (SIZE * len(composited), SIZE))
    for i, fr in enumerate(composited):
        sheet.paste(fr, (i * SIZE, 0))
    pal = sheet.convert("P", palette=Image.Palette.ADAPTIVE, colors=255)

    return [
        fr.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE)
        for fr in composited
    ]


def main() -> None:
    if not SVG.is_file():
        raise SystemExit(f"missing {SVG}; download from https://gleam.run/images/lucy/lucy.svg")

    base = render_lucy(SIZE)
    write_stored_png(ROOT / "lucy.png", base.tobytes(), SIZE, SIZE)

    frames_rgba = [
        base.rotate(-i * (360 / FRAMES), resample=Image.Resampling.BICUBIC, expand=False)
        for i in range(FRAMES)
    ]
    gif_frames = quantize_for_gif(frames_rgba)
    gif_path = ROOT / "lucy_spin.gif"
    gif_frames[0].save(
        gif_path,
        save_all=True,
        append_images=gif_frames[1:],
        duration=DELAY_MS,
        loop=0,
        optimize=False,
        disposal=2,
    )
    print(f"wrote {ROOT / 'lucy.png'} ({SIZE}x{SIZE})")
    print(f"wrote {gif_path} ({FRAMES} frames @ {DELAY_MS}ms)")


if __name__ == "__main__":
    main()
