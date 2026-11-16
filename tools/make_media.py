#!/usr/bin/env python3
"""Generates the handful of textures Schnitzel ships (Schnitzel/Media/*.tga).

WoW wants uncompressed 32-bit TGA files with power-of-two sizes. The shapes
are drawn from signed distances, which gives clean anti-aliased edges without
any image library. Run:  python3 tools/make_media.py
"""

import math
import os
import struct

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Schnitzel", "Media")


def write_tga(name, size, pixel):
    """pixel(x, y) -> (r, g, b, a) with 0..1 floats; y grows downwards."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 8)
    rows = []
    for y in range(size - 1, -1, -1):  # TGA stores the bottom row first
        row = bytearray()
        for x in range(size):
            r, g, b, a = pixel(x + 0.5, y + 0.5)
            row += bytes(int(max(0.0, min(1.0, c)) * 255 + 0.5) for c in (b, g, r, a))
        rows.append(bytes(row))
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "wb") as handle:
        handle.write(header + b"".join(rows))


def coverage(distance):
    """Signed distance in pixels (negative = inside) -> alpha."""
    return max(0.0, min(1.0, 0.5 - distance))


def segment_distance(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def polyline_distance(px, py, points):
    return min(segment_distance(px, py, *points[i], *points[i + 1]) for i in range(len(points) - 1))


def arc(cx, cy, radius, start_deg, end_deg, steps=24):
    return [
        (
            cx + radius * math.cos(math.radians(start_deg + (end_deg - start_deg) * i / steps)),
            cy + radius * math.sin(math.radians(start_deg + (end_deg - start_deg) * i / steps)),
        )
        for i in range(steps + 1)
    ]


def white(alpha):
    return (1.0, 1.0, 1.0, alpha)


# White shapes; the addon tints them at runtime.
write_tga("circle.tga", 64, lambda x, y: white(coverage(math.hypot(x - 32, y - 32) - 31)))

CHEVRON = [(9, 12.5), (16, 19.5), (23, 12.5)]
write_tga("chevron.tga", 32, lambda x, y: white(coverage(polyline_distance(x, y, CHEVRON) - 1.5)))

CROSS_A = [(10, 10), (22, 22)]
CROSS_B = [(22, 10), (10, 22)]
write_tga(
    "close.tga",
    32,
    lambda x, y: white(coverage(min(polyline_distance(x, y, CROSS_A), polyline_distance(x, y, CROSS_B)) - 1.4)),
)

# Logo: golden disc with a dark "S". Used for the addon list and minimap.
GOLD = (0.96, 0.70, 0.33)
DARK = (0.10, 0.08, 0.05)
LETTER = arc(32, 24, 8, -25, -270) + arc(32, 40, 8, -90, 155)[1:]


def logo(x, y):
    disc = coverage(math.hypot(x - 32, y - 32) - 30)
    ink = coverage(polyline_distance(x, y, LETTER) - 2.7)
    return tuple(GOLD[i] * (1 - ink) + DARK[i] * ink for i in range(3)) + (disc,)


write_tga("logo.tga", 64, logo)

print("wrote", ", ".join(sorted(os.listdir(OUT))))
