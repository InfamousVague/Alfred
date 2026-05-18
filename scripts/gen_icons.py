#!/usr/bin/env python3
"""Generate Alfred's icons, dependency-free (stdlib zlib+struct only).

Emits three PNGs:
  - Sources/Alfred/Resources/AppIcon.png   1024  dark tile + light mark
  - Sources/Alfred/Resources/MenuBarIcon.png 144  white mark, transparent
                                                  (NSStatusItem template)
  - art/AppIcon-source.png                  1024  copy for make-app.sh
                                                  (sips → .iconset → .icns)

Mark: a broom (clean sweep) + a sparkle — "tidy your machine".
"""
import math
import os
import struct
import zlib


def canvas(s):
    return bytearray(s * s * 4)


def px(buf, s, x, y, r, g, b, a=255):
    if 0 <= x < s and 0 <= y < s:
        i = (y * s + x) * 4
        ba = buf[i + 3]
        if a >= 255 or ba == 0:
            buf[i:i + 4] = bytes((r, g, b, a))
        else:
            na = a / 255.0
            buf[i] = int(r * na + buf[i] * (1 - na))
            buf[i + 1] = int(g * na + buf[i + 1] * (1 - na))
            buf[i + 2] = int(b * na + buf[i + 2] * (1 - na))
            buf[i + 3] = max(buf[i + 3], a)


def rrect(buf, s, x0, y0, x1, y1, rad, col):
    r, g, b = col
    for y in range(y0, y1):
        for x in range(x0, x1):
            cx = min(max(x, x0 + rad), x1 - rad)
            cy = min(max(y, y0 + rad), y1 - rad)
            d = math.hypot(x - cx, y - cy)
            if d <= rad:
                a = 255 if d <= rad - 1.5 else int(255 * (rad - d) / 1.5)
                px(buf, s, x, y, r, g, b, max(0, min(255, a)))


def disc(buf, s, cx, cy, rad, col, a=255):
    r, g, b = col
    for y in range(int(cy - rad - 2), int(cy + rad + 2)):
        for x in range(int(cx - rad - 2), int(cx + rad + 2)):
            d = math.hypot(x - cx, y - cy)
            if d <= rad:
                aa = a if d <= rad - 1.5 else int(a * (rad - d) / 1.5)
                px(buf, s, x, y, r, g, b, max(0, min(255, aa)))


def line(buf, s, x0, y0, x1, y1, w, col):
    n = int(math.hypot(x1 - x0, y1 - y0)) + 1
    for k in range(n + 1):
        t = k / n
        disc(buf, s, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, w / 2, col)


def draw_mark(buf, s, col):
    """Broom + sparkle, centred, sized to canvas s."""
    u = s / 1024.0
    # Handle.
    line(buf, s, 360 * u, 360 * u, 600 * u, 600 * u, 46 * u, col)
    hx, hy = 600 * u, 600 * u
    for k in range(-4, 5):
        ang = math.radians(135 + k * 7)
        ex = hx + math.cos(ang) * 250 * u
        ey = hy + math.sin(ang) * 250 * u
        line(buf, s, hx, hy, ex, ey, (26 - abs(k) * 1.5) * u, col)
    disc(buf, s, hx, hy, 52 * u, col)
    # Sparkle, upper-right.
    sx, sy = 690 * u, 358 * u
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        line(buf, s, sx, sy, sx + dx * 96 * u, sy + dy * 96 * u, 22 * u, col)
    disc(buf, s, sx, sy, 30 * u, col)


def write_png(path, s, buf):
    raw = bytearray()
    for y in range(s):
        raw.append(0)
        raw += buf[y * s * 4:(y + 1) * s * 4]

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", s, s, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print("wrote", path)


root = os.path.join(os.path.dirname(__file__), "..")
LIGHT = (245, 245, 247)

# App icon: dark rounded tile + light mark.
S = 1024
app = canvas(S)
rrect(app, S, 40, 40, S - 40, S - 40, 210, (12, 12, 14))
draw_mark(app, S, LIGHT)
write_png(os.path.join(root, "Sources/Alfred/Resources/AppIcon.png"), S, app)
write_png(os.path.join(root, "art/AppIcon-source.png"), S, app)

# Menu-bar icon: white mark on transparent (template; macOS tints it).
M = 144
mb = canvas(M)
draw_mark(mb, M, (255, 255, 255))
write_png(os.path.join(root, "Sources/Alfred/Resources/MenuBarIcon.png"), M, mb)
