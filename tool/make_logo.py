"""Generates the Dev Note logo.

The mark is a terminal prompt: a caret and a line, `>_`. It says "developer"
without a single literal symbol of the trade (no gear, no brackets, no
lightbulb), and it survives being drawn at 16 pixels, which most marks do not.

Kept as a script rather than checked-in binaries alone so the icon can be
regenerated at any size, and so its geometry is reviewable like the rest of
the code.

    python tool/make_logo.py
"""

import os
import struct
import zlib

from PIL import Image, ImageDraw

# The accent from the design's palette: #FF6A3D over #E0511F, top to bottom.
# A flat fill reads dull at large sizes and the gradient is invisible at 16px,
# so it costs nothing where it cannot help.
ACCENT_TOP = (255, 106, 61)
ACCENT_BOTTOM = (224, 81, 31)
MARK = (255, 255, 255)

# Geometry on a 256 grid. Supersampled 8x before it is drawn, so these are
# exact rather than pixel-snapped.
SIZE = 256
RADIUS = 58
STROKE = 30

CARET = [(74, 76), (126, 128), (74, 180)]
LINE = [(150, 180), (196, 180)]

SS = 8  # supersampling factor


def _gradient(size: int) -> Image.Image:
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        grad.putpixel(
            (0, y),
            tuple(
                round(a + (b - a) * t) for a, b in zip(ACCENT_TOP, ACCENT_BOTTOM)
            ),
        )
    return grad.resize((size, size), Image.BILINEAR)


def _stroke(draw: ImageDraw.ImageDraw, points, width: int) -> None:
    """A polyline with round caps and joins, which PIL will not do alone."""
    draw.line(points, fill=MARK, width=width, joint="curve")
    for x, y in points:
        r = width / 2
        draw.ellipse([x - r, y - r, x + r, y + r], fill=MARK)


def render(size: int) -> Image.Image:
    s = SIZE * SS
    scale = s / SIZE

    tile = _gradient(s).convert("RGBA")

    # The rounded square as a mask, so the corners are antialiased by the
    # downscale rather than by a hand-rolled blend.
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, s - 1, s - 1], radius=RADIUS * scale, fill=255
    )

    icon = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    icon.paste(tile, (0, 0), mask)

    draw = ImageDraw.Draw(icon)
    _stroke(draw, [(x * scale, y * scale) for x, y in CARET], round(STROKE * scale))
    _stroke(draw, [(x * scale, y * scale) for x, y in LINE], round(STROKE * scale))

    return icon.resize((size, size), Image.LANCZOS)


def write_ico(path: str, sizes) -> None:
    """Writes a PNG-compressed .ico.

    Pillow's own ICO writer re-samples from one bitmap; rendering each size
    from the geometry keeps the 16px variant sharp instead of mushy.
    """
    images = []
    for size in sizes:
        raw = render(size)
        buf = bytearray()
        # PNG, hand-assembled to avoid a temp file per size.
        buf += b"\x89PNG\r\n\x1a\n"

        def chunk(tag, data):
            out = struct.pack(">I", len(data)) + tag + data
            return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        buf += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        rows = b"".join(
            b"\x00" + raw.crop((0, y, size, y + 1)).tobytes() for y in range(size)
        )
        buf += chunk(b"IDAT", zlib.compress(rows, 9))
        buf += chunk(b"IEND", b"")
        images.append(bytes(buf))

    header = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    entries = b""
    for size, data in zip(sizes, images):
        entries += struct.pack(
            "<BBBBHHII",
            size if size < 256 else 0,
            size if size < 256 else 0,
            0,
            0,
            1,
            32,
            len(data),
            offset,
        )
        offset += len(data)

    with open(path, "wb") as f:
        f.write(header + entries + b"".join(images))


SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" role="img" aria-label="Dev Note">
  <defs>
    <linearGradient id="a" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FF6A3D"/>
      <stop offset="1" stop-color="#E0511F"/>
    </linearGradient>
  </defs>
  <rect width="256" height="256" rx="58" fill="url(#a)"/>
  <g fill="none" stroke="#FFFFFF" stroke-width="30" stroke-linecap="round" stroke-linejoin="round">
    <polyline points="74,76 126,128 74,180"/>
    <line x1="150" y1="180" x2="196" y2="180"/>
  </g>
</svg>
"""


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    def out(*parts):
        path = os.path.join(root, *parts)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        return path

    ico_sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    write_ico(out("assets", "icons", "tray.ico"), ico_sizes)
    write_ico(out("windows", "runner", "resources", "app_icon.ico"), ico_sizes)

    for size in (64, 128, 256, 512, 1024):
        render(size).save(out("assets", "icons", f"logo_{size}.png"))
    render(512).save(out("assets", "icons", "logo.png"))

    with open(out("assets", "icons", "logo.svg"), "w", encoding="utf-8") as f:
        f.write(SVG)

    print("logo written")


if __name__ == "__main__":
    main()
