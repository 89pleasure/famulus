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

# A closed book with its spine on the left and two lines on the cover.
BOOK = [
    [(7.5, 5.5), (24.5, 5.5), (24.5, 26.5), (7.5, 26.5), (7.5, 5.5)],
    [(12, 5.5), (12, 26.5)],
    [(16, 11.5), (20.5, 11.5)],
    [(16, 16), (20.5, 16)],
]
write_tga("book.tga", 32, stroke(BOOK, PEN))

# A pennant on its pole: a milestone on the way.
FLAG = [
    [(9, 5.5), (9, 27)],
    [(9, 7), (24, 11.5), (9, 16.5)],
]
write_tga("flag.tga", 32, stroke(FLAG, PEN))


# Soft drop shadow, used in nine pieces around a window or menu. The centre
# of the texture is the corner of the shape; alpha falls off outwards.
def shadow(x, y):
    distance = max(0.0, math.hypot(max(0.0, abs(x - 32) - 0), max(0.0, abs(y - 32) - 0)) - 4)
    t = min(1.0, distance / 28)
    return white((1 - t) ** 2.2)


write_tga("shadow.tga", 64, shadow)

# Grain: fine noise laid over the grounds of the window, one texel per screen
# pixel. White with varying alpha. Plain noise only: a cloudy layer on top
# of it looked like stains in the game.
GRAIN = 128


def grain():
    import random

    rng = random.Random(7)  # fixed, so the file is the same on every run
    fine = [[rng.random() for _ in range(GRAIN)] for _ in range(GRAIN)]
    return lambda x, y: white(fine[int(y)][int(x)])


write_tga("grain.tga", GRAIN, grain())

# Logo: a blazing flame with a soft glow, in its own colours (it does not
# follow the colour scheme). logo.tga is the flame alone, for the settings
# window and the addon list; logo-round.tga sets it on a dark disc for the
# minimap button.
#
# The flame is drawn in a 128 x 128 box.
LOGO = 128
SAMPLES = 3  # per axis, for the edges of the filled shapes


def rgb(value):
    return tuple(int(value[i : i + 2], 16) / 255 for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def ramp(stops, t):
    """Colour at t along [(position, colour), ...]."""
    if t <= stops[0][0]:
        return stops[0][1]
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if t <= p1:
            return lerp(c0, c1, (t - p0) / (p1 - p0))
    return stops[-1][1]


def cubic_path(start, *controls, steps=14):
    """Closed outline along cubic Bezier segments; controls come in threes."""
    points = [start]
    for i in range(0, len(controls), 3):
        p0, (c1, c2, p3) = points[-1], controls[i : i + 3]
        for step in range(1, steps + 1):
            t = step / steps
            u = 1 - t
            points.append(
                tuple(
                    u**3 * p0[k] + 3 * u * u * t * c1[k] + 3 * u * t * t * c2[k] + t**3 * p3[k]
                    for k in (0, 1)
                )
            )
    return points


def inside_polygon(x, y, polygon):
    hit = False
    xj, yj = polygon[-1]
    for xi, yi in polygon:
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        xj, yj = xi, yi
    return hit


def bounds(polygon):
    xs, ys = [p[0] for p in polygon], [p[1] for p in polygon]
    return min(xs), min(ys), max(xs), max(ys)


FLAME_OUTER = cubic_path(
    (66, 10), (72, 30), (98, 44), (98, 76), (98, 98), (83, 114), (64, 114), (45, 114), (30, 99), (30, 78),
    (30, 62), (40, 54), (44, 40), (48, 50), (54, 54), (58, 50), (64, 42), (60, 24), (66, 10),
)  # fmt: skip
FLAME_LICK = cubic_path((33, 40), (36, 49), (32, 56), (29, 63), (25, 56), (27, 47), (33, 40))
FLAME_MID = cubic_path(
    (66, 44), (70, 58), (84, 66), (84, 84), (84, 98), (75, 108), (64, 108), (53, 108), (44, 99), (44, 86),
    (44, 76), (51, 72), (54, 62), (57, 68), (61, 69), (63, 66), (66, 60), (64, 52), (66, 44),
)  # fmt: skip
FLAME_CORE = cubic_path(
    (64, 76), (68, 84), (74, 88), (74, 96), (74, 103), (69, 108), (64, 108), (59, 108), (54, 103), (54, 97),
    (54, 90), (60, 86), (64, 76),
)  # fmt: skip
SPARKS = [(96, 30, 3.2), (106, 50, 2.2), (26, 26, 2.4)]

# From the tip of the flame down to its base.
FIRE = [(0.0, rgb("fff3a6")), (0.45, rgb("f2d640")), (1.0, rgb("cf9a12"))]
FIRE_TOP, FIRE_BOTTOM = 10, 114


def fire(x, y):
    return ramp(FIRE, (y - FIRE_TOP) / (FIRE_BOTTOM - FIRE_TOP))


# Painted in this order; each is (outline, its bounds, colour at a point).
LAYERS = [
    (shape, bounds(shape), colour)
    for shape, colour in (
        (FLAME_OUTER, fire),
        (FLAME_LICK, fire),
        (FLAME_MID, lambda x, y: rgb("fff0a0")),
        (FLAME_CORE, lambda x, y: rgb("fffce8")),
    )
]

# Ground of the tile: lighter behind the flame, darker towards the corners.
GROUND = [(0.0, rgb("24403f")), (0.62, rgb("142022")), (1.0, rgb("0f1719"))]
RIM = rgb("2f4447")
GLOW = rgb("f2d640")


def over(colour, alpha, paint, amount):
    """Lays `paint` with opacity `amount` over a colour that has its own alpha."""
    total = amount + alpha * (1 - amount)
    if total <= 0:
        return colour, 0.0
    return lerp(colour, paint, amount / total), total


def logo(disc, view_min, view_size):
    """The flame with its glow; on a dark disc if `disc`, else on nothing."""
    half = LOGO / 2

    def pixel(px, py):
        # Drawing coordinates of this pixel.
        x = view_min + px / LOGO * view_size
        y = view_min + py / LOGO * view_size
        step = view_size / LOGO

        if disc:
            edge = math.hypot(px - half, py - half) - half  # negative inside
            alpha = coverage(edge + 0.5)
            if alpha <= 0:
                return (0.0, 0.0, 0.0, 0.0)
            colour = ramp(GROUND, math.hypot(px - half, py - LOGO * 0.62) / (LOGO * 0.8))
            colour = lerp(colour, RIM, max(0.0, min(1.0, edge + 2.5)))  # hairline along the edge
        else:
            colour, alpha = GLOW, 0.0

        # The glow must fade out before the edge of the texture.
        halo = max(0.0, 1 - math.hypot(x - 64, y - 72) / (70 if disc else 54)) * 0.38
        colour, alpha = over(colour, alpha, GLOW, halo)

        for shape, (left, top, right, bottom), paint in LAYERS:
            if x < left - step or x > right + step or y < top - step or y > bottom + step:
                continue
            hits = 0
            for i in range(SAMPLES):
                for j in range(SAMPLES):
                    sx = x + ((i + 0.5) / SAMPLES - 0.5) * step
                    sy = y + ((j + 0.5) / SAMPLES - 0.5) * step
                    if inside_polygon(sx, sy, shape):
                        hits += 1
            if hits:
                colour, alpha = over(colour, alpha, paint(x, y), hits / (SAMPLES * SAMPLES))

        for cx, cy, r in SPARKS:
            spark = coverage((math.hypot(x - cx, y - cy) - r) / step)
            if spark > 0:
                colour, alpha = over(colour, alpha, GLOW, spark)

        return colour + (alpha,)

    return pixel


# The free flame fills its texture; on the disc it keeps a margin.
write_tga("logo.tga", LOGO, logo(False, 2.0, 124.0))
write_tga("logo-round.tga", LOGO, logo(True, -10.0, 148.0))

print("wrote", ", ".join(sorted(os.listdir(OUT))))
