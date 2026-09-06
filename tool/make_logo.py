"""Generates the Dev Note logo.

The mark is a closed journal: a cover with a spine line near the left edge,
three ruled lines standing in for text, and a notched ribbon bookmark hanging
from the top. It says "notebook" before anything else, which a terminal-style
`>_` glyph never did, and it survives being drawn at 16 pixels because every
element is a straight line or one gentle corner, nothing that turns to mush
when downsampled.

Kept as a script rather than checked-in binaries alone so the icon can be
regenerated at any size, and so its geometry is reviewable like the rest of
the code.

    python tool/make_logo.py
"""

import os
import struct
import zlib

from PIL import Image, ImageDraw

# Blue, not the app's orange accent: the accent is a UI choice the user can
# change per JotAccent, the mark itself is fixed and deliberately does not
# follow it (see AppMark's docstring). Picked to read as ink/cover blue
# rather than violet.
ACCENT_TOP = (76, 141, 245)  # #4C8DF5
ACCENT_BOTTOM = (26, 74, 158)  # #1A4A9E
MARK = (255, 255, 255)

# Geometry on a 256 grid. Supersampled 8x before it is drawn, so these are
# exact rather than pixel-snapped.
SIZE = 256
RADIUS = 58

# The cover outline: two straight top/left/bottom edges, one rounded corner
# top-right (a quadratic bezier, sampled below), closed back to the start.
OUTLINE_START = (70, 52)
OUTLINE_TOP_RIGHT = (188, 52)
OUTLINE_CORNER_CONTROL = (198, 52)
OUTLINE_CORNER_END = (198, 62)
OUTLINE_BOTTOM_RIGHT = (198, 204)
OUTLINE_BOTTOM_LEFT = (70, 204)
OUTLINE_STROKE = 16

SPINE = [(88, 52), (88, 204)]
SPINE_STROKE = 14

RULED_LINES = [
    [(110, 104), (172, 104)],
    [(110, 130), (172, 130)],
    [(110, 156), (150, 156)],
]
RULED_STROKE = 12

# Icons at 32px and below never resolve the ribbon's notch or three separate
# ruled lines, they blur into one smear rather than reading as detail, so the
# smallest sizes drop to two bolder lines and no ribbon instead. The outline
# and the spine, the two things that actually say "book", stay everywhere.
RULED_LINES_SMALL = [
    [(108, 112), (174, 112)],
    [(108, 148), (174, 148)],
]
RULED_STROKE_SMALL = 18
SMALL_CUTOFF = 32

# A ribbon with a notch cut into its bottom edge, like a bookmark peeking out
# from between the pages.
RIBBON = [(146, 52), (146, 92), (134, 80), (122, 92), (122, 52)]

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


def _quad_bezier(p0, p1, p2, steps: int = 10):
    """Samples a quadratic bezier, used for the cover's one rounded corner.

    `_stroke` only draws straight segments, so a smooth corner needs enough
    points along the curve to look round rather than faceted once it is
    scaled up to the largest icon sizes.
    """
    points = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1]
        points.append((x, y))
    return points


def _outline_points():
    return (
        [OUTLINE_START, OUTLINE_TOP_RIGHT]
        + _quad_bezier(OUTLINE_TOP_RIGHT, OUTLINE_CORNER_CONTROL, OUTLINE_CORNER_END)[1:]
        + [OUTLINE_BOTTOM_RIGHT, OUTLINE_BOTTOM_LEFT, OUTLINE_START]
    )


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

    def at_scale(points):
        return [(x * scale, y * scale) for x, y in points]

    _stroke(draw, at_scale(_outline_points()), round(OUTLINE_STROKE * scale))
    _stroke(draw, at_scale(SPINE), round(SPINE_STROKE * scale))
    if size <= SMALL_CUTOFF:
        for line in RULED_LINES_SMALL:
            _stroke(draw, at_scale(line), round(RULED_STROKE_SMALL * scale))
    else:
        for line in RULED_LINES:
            _stroke(draw, at_scale(line), round(RULED_STROKE * scale))
        draw.polygon(at_scale(RIBBON), fill=MARK)

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


def _svg_path_d(points) -> str:
    d = f"M{points[0][0]},{points[0][1]}"
    for x, y in points[1:]:
        d += f" L{x},{y}"
    return d


SVG = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" role="img" aria-label="Dev Note">
  <defs>
    <linearGradient id="a" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#4C8DF5"/>
      <stop offset="1" stop-color="#1A4A9E"/>
    </linearGradient>
  </defs>
  <rect width="256" height="256" rx="58" fill="url(#a)"/>
  <path d="M{OUTLINE_START[0]},{OUTLINE_START[1]} L{OUTLINE_TOP_RIGHT[0]},{OUTLINE_TOP_RIGHT[1]} Q{OUTLINE_CORNER_CONTROL[0]},{OUTLINE_CORNER_CONTROL[1]} {OUTLINE_CORNER_END[0]},{OUTLINE_CORNER_END[1]} L{OUTLINE_BOTTOM_RIGHT[0]},{OUTLINE_BOTTOM_RIGHT[1]} L{OUTLINE_BOTTOM_LEFT[0]},{OUTLINE_BOTTOM_LEFT[1]} Z" fill="none" stroke="#FFFFFF" stroke-width="{OUTLINE_STROKE}" stroke-linejoin="round"/>
  <line x1="{SPINE[0][0]}" y1="{SPINE[0][1]}" x2="{SPINE[1][0]}" y2="{SPINE[1][1]}" stroke="#FFFFFF" stroke-width="{SPINE_STROKE}" stroke-linecap="round"/>
  <g stroke="#FFFFFF" stroke-linecap="round">
{chr(10).join(f'    <line x1="{a[0]}" y1="{a[1]}" x2="{b[0]}" y2="{b[1]}" stroke-width="{RULED_STROKE}"/>' for a, b in RULED_LINES)}
  </g>
  <path d="{_svg_path_d(RIBBON)} Z" fill="#FFFFFF"/>
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
