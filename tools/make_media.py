#!/usr/bin/env python3
"""Generates the handful of textures Famulus ships (Famulus/Media/*.tga).

WoW wants uncompressed 32-bit TGA files with power-of-two sizes. The shapes
are drawn from signed distances, which gives clean anti-aliased edges without
any image library. Run:  python3 tools/make_media.py
"""

import math
import os
import struct

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Famulus", "Media")


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


def supersample(inside, n=4):
    """Coverage of a filled shape given as inside(x, y) -> bool."""

    def pixel(x, y):
        hits = 0
        for i in range(n):
            for j in range(n):
                if inside(x - 0.5 + (i + 0.5) / n, y - 0.5 + (j + 0.5) / n):
                    hits += 1
        return white(hits / (n * n))

    return pixel


def stroke(paths, width, circles=()):
    """Line icon: polylines and circles (cx, cy, r) drawn with one pen."""

    def pixel(x, y):
        distance = min(polyline_distance(x, y, path) for path in paths) if paths else 1e9
        for cx, cy, r in circles:
            distance = min(distance, abs(math.hypot(x - cx, y - cy) - r))
        return white(coverage(distance - width / 2))

    return pixel


PEN = 2.6  # icons are drawn at 32 px for about 16 px on screen

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

write_tga("check.tga", 32, stroke([[(8.5, 16.5), (13.5, 21.5), (23.5, 10.5)]], PEN))
write_tga("search.tga", 32, stroke([[(19.5, 19.5), (26, 26)]], PEN, [(14, 14, 8)]))
write_tga("info.tga", 32, stroke([[(16, 15), (16, 22.5)], [(16, 10.2), (16, 10.4)]], PEN, [(16, 16, 12)]))
write_tga("reset.tga", 32, stroke([arc(16, 16, 9, 200, 470), [(4.6, 9.2), (7.6, 15.6), (13.8, 13.0)]], PEN))

SUN_RAYS = [
    [(16 + 10 * math.cos(a), 16 + 10 * math.sin(a)), (16 + 13 * math.cos(a), 16 + 13 * math.sin(a))]
    for a in (math.radians(45 * i) for i in range(8))
]
write_tga("sun.tga", 32, stroke(SUN_RAYS, PEN, [(16, 16, 5.2)]))


def moon(x, y):
    return math.hypot(x - 15, y - 17) <= 11 and math.hypot(x - 21, y - 11) > 9


write_tga("moon.tga", 32, supersample(moon))


def gear(x, y):
    dx, dy = x - 16, y - 16
    r = math.hypot(dx, dy)
    if r <= 4.2:
        return False
    if r <= 9.5:
        return True
    if r > 13.2:
        return False
    angle = (math.degrees(math.atan2(dy, dx)) + 360) % 45
    return angle < 14 or angle > 31


write_tga("gear.tga", 32, supersample(gear))


def sparkle_inside(x, y, cx, cy, radius):
    dx, dy = abs(x - cx) / radius, abs(y - cy) / radius
    return dx**0.55 + dy**0.55 <= 1


write_tga(
    "sparkle.tga",
    32,
    supersample(lambda x, y: sparkle_inside(x, y, 13, 18, 11.5) or sparkle_inside(x, y, 24.5, 7.5, 6)),
)

TAG = [(5.5, 5.5), (15.5, 5.5), (27, 17), (17, 27), (5.5, 15.5), (5.5, 5.5)]
write_tga("tag.tga", 32, stroke([TAG], PEN, [(11.2, 11.2, 1.6)]))


# Soft drop shadow, used in nine pieces around a window or menu. The centre
# of the texture is the corner of the shape; alpha falls off outwards.
def shadow(x, y):
    distance = max(0.0, math.hypot(max(0.0, abs(x - 32) - 0), max(0.0, abs(y - 32) - 0)) - 4)
    t = min(1.0, distance / 28)
    return white((1 - t) ** 2.2)


write_tga("shadow.tga", 64, shadow)

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
