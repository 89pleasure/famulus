#!/usr/bin/env python3
"""Generates the handful of textures Famulus ships (Famulus/Media/*.tga).

WoW wants uncompressed 32-bit TGA files with power-of-two sizes. The shapes
are drawn from signed distances, which gives clean anti-aliased edges without
any image library. Run:  python3 tools/make_media.py
"""

import math
import os
import re
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
# The bond ring around a crest: an annulus, inner radius 0.82 of the outer.
write_tga("ring.tga", 128, lambda x, y: white(min(
    coverage(math.hypot(x - 64, y - 64) - 63),
    coverage(63 * 0.82 - math.hypot(x - 64, y - 64)),
)))

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

# A pennant on its pole: a milestone on the way.
FLAG = [
    [(9, 5.5), (9, 27)],
    [(9, 7), (24, 11.5), (9, 16.5)],
]
write_tga("flag.tga", 32, stroke(FLAG, PEN))

# Two people side by side, the second a step behind: fellow travellers.
PEOPLE = [
    arc(11, 28, 8.6, 180, 360),
    arc(23, 24.5, 6.8, 250, 360),
]
write_tga("people.tga", 32, stroke(PEOPLE, PEN, [(11, 12.5, 4.4), (23, 10.5, 3.4)]))


def ellipse(cx, cy, rx, ry, steps=32):
    return [
        (cx + rx * math.cos(2 * math.pi * i / steps), cy + ry * math.sin(2 * math.pi * i / steps))
        for i in range(steps + 1)
    ]


# Icons of the entries in the settings tabs, one per feature or setting
# (feature.icon, GENERAL_ICONS in UI/Options.lua). Drawn like the icons above.
ICONS = {
    # Two arrows, one each way: sharing with friends.
    "share": ([
        [(6, 11), (25, 11)], [(20.5, 6.5), (25, 11), (20.5, 15.5)],
        [(26, 21), (7, 21)], [(11.5, 16.5), (7, 21), (11.5, 25.5)],
    ], []),
    # A bell: events shown on screen.
    "bell": ([
        arc(16, 14.5, 7, 180, 360) + [(23, 20), (26, 23.5), (6, 23.5), (9, 20), (9, 14.5)],
        arc(16, 24.5, 2.8, 0, 180, 12),
        [(16, 7.5), (16, 5)],
    ], []),
    # A speech bubble with two lines of text: chat.
    "chat": ([
        [(5.5, 7), (26.5, 7), (26.5, 21), (14, 21), (8.5, 26), (9.5, 21), (5.5, 21), (5.5, 7)],
        [(10, 12), (22, 12)], [(10, 16), (18, 16)],
    ], []),
    # A shield: the guild (Guildy).
    "shield": ([
        [(16, 4.5), (26, 8), (26, 15.5), (22.5, 22), (16, 27.5), (9.5, 22), (6, 15.5), (6, 8), (16, 4.5)],
    ], []),
    # A box of text beside the mouse pointer: a tooltip.
    "tooltip": ([
        [(11, 4.5), (27, 4.5), (27, 15), (11, 15), (11, 4.5)],
        [(15, 9.75), (23, 9.75)],
        [(5, 13.5), (5, 27), (8.6, 23.6), (11, 28.5), (13.4, 27.4), (11, 22.6), (15.5, 22.5), (5, 13.5)],
    ], []),
    # A list with a dot before each line: a context menu.
    "menu": ([
        [(11, 9), (26, 9)], [(11, 16), (26, 16)], [(11, 23), (21, 23)],
        [(5.8, 9), (6.2, 9)], [(5.8, 16), (6.2, 16)], [(5.8, 23), (6.2, 23)],
    ], []),
    # Two rings of a chain: one alias for all characters of an account.
    "link": ([], [(12, 20, 6.5), (20, 12, 6.5)]),
    # A bin: tidying up.
    "trash": ([
        [(6, 9), (26, 9)], [(12.5, 9), (13.5, 5), (18.5, 5), (19.5, 9)],
        [(8.5, 9), (10, 27), (22, 27), (23.5, 9)],
        [(13.5, 13.5), (14, 22.5)], [(18.5, 13.5), (18, 22.5)],
    ], []),
    # A globe: the language.
    "globe": ([[(5, 16), (27, 16)], ellipse(16, 16, 4.8, 11)], [(16, 16, 11)]),
    # A compass: the minimap.
    "compass": ([[(16, 8), (19.5, 16), (16, 24), (12.5, 16), (16, 8)]], [(16, 16, 11)]),
    # One person: this character only.
    "person": ([arc(16, 29, 9.5, 180, 360)], [(16, 11, 4.8)]),
    # A drop of paint: the colour scheme.
    "drop": ([[(16, 4.5)] + arc(16, 19.5, 7.5, -30, 210) + [(16, 4.5)]], []),
    # Two corners pulled apart: the window's size.
    "resize": ([
        [(5.5, 13), (5.5, 5.5), (13, 5.5)], [(26.5, 19), (26.5, 26.5), (19, 26.5)],
        [(6.5, 6.5), (25.5, 25.5)],
    ], []),
    # A clock face with its two hands: the time format.
    "clock": ([[(16, 9), (16, 16), (21, 19)]], [(16, 16, 11)]),
    # A calendar page with its two rings and two rows of days: the date format.
    "calendar": ([
        [(5.5, 7.5), (26.5, 7.5), (26.5, 26.5), (5.5, 26.5), (5.5, 7.5)],
        [(5.5, 13), (26.5, 13)],
        [(11, 4.5), (11, 9.5)], [(21, 4.5), (21, 9.5)],
        [(10.8, 18), (11.2, 18)], [(15.8, 18), (16.2, 18)], [(20.8, 18), (21.2, 18)],
        [(10.8, 22.5), (11.2, 22.5)], [(15.8, 22.5), (16.2, 22.5)],
    ], []),
}
for name, (paths, circles) in ICONS.items():
    write_tga(name + ".tga", 32, stroke(paths, PEN, circles))


# Pictures of the chronicle: drawn in a 32 px box like the icons, but written
# at twice the size, because they are shown larger. pen: the line's width at
# that size.
def picture(name, paths, circles=(), pen=3.6):
    paths = [[(x * 2, y * 2) for x, y in path] for path in paths]
    circles = [(cx * 2, cy * 2, r * 2) for cx, cy, r in circles]
    write_tga(name, 64, stroke(paths, pen, circles))


# A skull: the dome, the jaw with two teeth, the eyes.
SKULL = [
    arc(16, 14, 9, 150, 390) + [(21.5, 21), (21.5, 25), (10.5, 25), (10.5, 21), (8.2, 18.5)],
    [(14, 25), (14, 23)],
    [(18, 25), (18, 23)],
]
picture("skull.tga", SKULL, [(12.5, 14.5, 2), (19.5, 14.5, 2)])

# Two crossed swords with their guards and pommels.
SWORDS = [
    [(7, 7), (21, 21)],
    [(25, 7), (11, 21)],
    [(5, 21), (11, 27)],
    [(27, 21), (21, 27)],
    [(9, 25), (6, 28)],
    [(23, 25), (26, 28)],
]
picture("swords.tga", SWORDS)

# Mountains under a sun: a new land.
PEAKS = [[(4, 24), (11, 13), (16, 20), (19, 16), (28, 24), (4, 24)]]
picture("peaks.tga", PEAKS, [(22, 8.5, 2.5)])

# A five-pointed star: a challenge mastered.
STAR = [
    (16 + (10.5 if i % 2 == 0 else 4.4) * math.sin(math.radians(36 * i)),
     16.5 - (10.5 if i % 2 == 0 else 4.4) * math.cos(math.radians(36 * i)))
    for i in range(11)
]  # fmt: skip
picture("star.tga", [STAR])

# A hammer: a craft learned.
HAMMER = [
    [(7, 25), (17.7, 14.3)],
    [(27.2, 14.7), (22.7, 19.2), (12.8, 9.3), (17.3, 4.8), (27.2, 14.7)],
]
picture("hammer.tga", HAMMER)

# A chest with its lid and lock: a special item.
CHEST = [
    [(6, 11.5), (26, 11.5), (26, 25), (6, 25), (6, 11.5)],
    [(6, 11.5), (9, 6.5), (23, 6.5), (26, 11.5)],
    [(6, 17), (13.5, 17)],
    [(18.5, 17), (26, 17)],
]
picture("chest.tga", CHEST, [(16, 17, 2.2)])

# A horseshoe with two nail holes: learned to ride.
picture("horseshoe.tga", [arc(16, 14.5, 9.5, 115, 425)], [(8.6, 12, 1.1), (23.4, 12, 1.1)])


# Reactions to a friend's event (ChronicleService.REACTION_SETS).
# They are shown small (16-18 px), where our own line pictures looked like
# runes, so they come from Phosphor Icons in the Bold weight (MIT, see
# tools/phosphor/LICENSE), a set drawn for small sizes. Each SVG is filled
# paths on a 256 grid; they are flattened to polygons and filled with the
# nonzero rule.
PHOSPHOR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "phosphor")
SVG_NUMBER = re.compile(r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")


def svg_tokens(d):
    """Commands and numbers of a path; arc flags may stand without separators."""
    tokens, i, arc_index = [], 0, -1
    while i < len(d):
        ch = d[i]
        if ch.isalpha():
            tokens.append(ch)
            arc_index = 0 if ch in "Aa" else -1
            i += 1
        elif ch in " ,\t\r\n":
            i += 1
        elif arc_index in (3, 4) and ch in "01":
            tokens.append(float(ch))
            arc_index += 1
            i += 1
        else:
            match = SVG_NUMBER.match(d, i)
            tokens.append(float(match.group()))
            if arc_index >= 0:
                arc_index = (arc_index + 1) % 7
            i = match.end()
    return tokens


def svg_arc(p0, rx, ry, rotation, large, sweep, p1, steps=16):
    """Points of an SVG elliptical arc after p0, ending in p1 (SVG 1.1, F.6.5)."""
    if rx == 0 or ry == 0 or p0 == p1:
        return [p1]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(rotation)
    c, s = math.cos(phi), math.sin(phi)
    dx, dy = (p0[0] - p1[0]) / 2, (p0[1] - p1[1]) / 2
    x1, y1 = c * dx + s * dy, -s * dx + c * dy
    scale = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
    if scale > 1:
        rx, ry = rx * math.sqrt(scale), ry * math.sqrt(scale)
    num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    den = rx * rx * y1 * y1 + ry * ry * x1 * x1
    root = math.sqrt(max(0.0, num / den)) * (-1 if large == sweep else 1)
    cx1, cy1 = root * rx * y1 / ry, -root * ry * x1 / rx
    cx = c * cx1 - s * cy1 + (p0[0] + p1[0]) / 2
    cy = s * cx1 + c * cy1 + (p0[1] + p1[1]) / 2
    start = math.atan2((y1 - cy1) / ry, (x1 - cx1) / rx)
    end = math.atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx)
    delta = end - start
    if sweep and delta < 0:
        delta += 2 * math.pi
    elif not sweep and delta > 0:
        delta -= 2 * math.pi
    points = []
    for k in range(1, steps + 1):
        t = start + delta * k / steps
        ex, ey = rx * math.cos(t), ry * math.sin(t)
        points.append((cx + c * ex - s * ey, cy + s * ex + c * ey))
    points[-1] = p1
    return points


def bezier(points, steps):
    """Points of a quadratic or cubic Bezier curve after its start."""
    out = []
    for k in range(1, steps + 1):
        t = k / steps
        u = 1 - t
        w = (u * u, 2 * u * t, t * t) if len(points) == 3 else (u**3, 3 * u * u * t, 3 * u * t * t, t**3)
        out.append(tuple(sum(wj * p[axis] for wj, p in zip(w, points)) for axis in (0, 1)))
    return out


def svg_polygons(d, steps=16):
    """Closed polygons of an SVG path (every command; curves flattened)."""
    tokens = svg_tokens(d)
    polygons, current = [], []
    pos = start = (0.0, 0.0)
    control = None  # the last control point, for S and T
    command, i = None, 0

    def take(n):
        nonlocal i
        values = tokens[i : i + n]
        i += n
        return values

    while i < len(tokens):
        if isinstance(tokens[i], str):
            command = tokens[i]
            i += 1
            if command in "Zz":
                if len(current) > 2:
                    polygons.append(current)
                current, pos, control = [], start, None
                continue
        relative = command.islower()
        ox, oy = pos if relative else (0.0, 0.0)
        kind = command.upper()
        if kind == "M":
            x, y = take(2)
            if len(current) > 2:
                polygons.append(current)
            pos = start = (ox + x, oy + y)
            current, control = [pos], None
            command = "l" if relative else "L"  # further pairs are lines
            continue
        if kind == "L":
            x, y = take(2)
            new = [(ox + x, oy + y)]
        elif kind == "H":
            (x,) = take(1)
            new = [(ox + x, pos[1])]
        elif kind == "V":
            (y,) = take(1)
            new = [(pos[0], oy + y)]
        elif kind == "C":
            v = take(6)
            c1, c2, end = (ox + v[0], oy + v[1]), (ox + v[2], oy + v[3]), (ox + v[4], oy + v[5])
            new, control = bezier([pos, c1, c2, end], steps), c2
        elif kind == "S":
            v = take(4)
            c1 = (2 * pos[0] - control[0], 2 * pos[1] - control[1]) if control else pos
            c2, end = (ox + v[0], oy + v[1]), (ox + v[2], oy + v[3])
            new, control = bezier([pos, c1, c2, end], steps), c2
        elif kind == "Q":
            v = take(4)
            c1, end = (ox + v[0], oy + v[1]), (ox + v[2], oy + v[3])
            new, control = bezier([pos, c1, end], steps), c1
        elif kind == "T":
            v = take(2)
            c1 = (2 * pos[0] - control[0], 2 * pos[1] - control[1]) if control else pos
            new, control = bezier([pos, c1, (ox + v[0], oy + v[1])], steps), c1
        elif kind == "A":
            rx, ry, rotation, large, sweep, x, y = take(7)
            new = svg_arc(pos, rx, ry, rotation, int(large), int(sweep), (ox + x, oy + y), steps)
        else:
            raise ValueError("unknown path command " + command)
        if kind not in "CSQT":
            control = None
        if not current:
            current = [pos]
        current += new
        pos = new[-1]
    if len(current) > 2:
        polygons.append(current)
    return polygons


def fill_nonzero(polygons, size, n=8):
    """Coverage grid [y][x] of polygons (in pixels) under the nonzero rule."""
    edges = []
    for polygon in polygons:
        for k in range(len(polygon)):
            (ax, ay), (bx, by) = polygon[k - 1], polygon[k]
            if ay != by:
                edges.append((ax, ay, bx, by, 1 if by > ay else -1))
    grid = [[0.0] * size for _ in range(size)]
    for row in range(size * n):
        sy = (row + 0.5) / n
        crossings = sorted(
            (ax + (sy - ay) * (bx - ax) / (by - ay), w)
            for ax, ay, bx, by, w in edges
            if min(ay, by) <= sy < max(ay, by)
        )
        winding, line = 0, grid[row // n]
        for k in range(len(crossings) - 1):
            winding += crossings[k][1]
            if winding != 0:  # samples whose centre lies in [x, next x)
                first = max(0, math.ceil(crossings[k][0] * n - 0.5))
                last = min(size * n - 1, math.ceil(crossings[k + 1][0] * n - 0.5) - 1)
                for col in range(first, last + 1):
                    line[col // n] += 1.0 / (n * n)
    return grid


def phosphor(name, icon, size=64):
    """Writes the Phosphor icon tools/phosphor/<icon>.svg as a white texture."""
    with open(os.path.join(PHOSPHOR, icon + ".svg"), encoding="utf-8") as handle:
        svg = handle.read()
    view = float(re.search(r'viewBox="0 0 ([\d.]+)', svg).group(1))
    polygons = []
    for d in re.findall(r'\sd="([^"]+)"', svg):
        polygons += [[(x * size / view, y * size / view) for x, y in p] for p in svg_polygons(d)]
    grid = fill_nonzero(polygons, size)
    write_tga(name, size, lambda x, y: white(grid[int(y)][int(x)]))


phosphor("sad.tga", "smiley-sad-bold")  # a death
phosphor("cheer.tga", "confetti-bold")  # a level, a special event: a party popper
phosphor("strong.tga", "hand-fist-bold")  # a boss
phosphor("clap.tga", "hands-clapping-bold")  # a profession

# Heart and flame are still our own line drawings, with a stronger pen.
REACTION_PEN = 5


# A heart: comfort after a death. The classic heart curve, closed at its
# notch on top.
HEART = []
for i in range(49):
    t = 2 * math.pi * i / 48
    hx = 16 * math.sin(t) ** 3
    hy = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
    HEART.append((16 + 0.7 * hx, 14.5 - 0.7 * hy))
picture("heart.tga", [HEART], (), REACTION_PEN)

# A flame with a second tongue and a small flame inside: that was hot.
FIRE = [
    [(14, 3.5), (17.5, 8.5), (19.5, 11.5), (22.5, 8), (24.4, 14)] + arc(16, 20, 8.5, -25, 205, 20)
    + [(8, 13.5), (10.5, 9), (14, 3.5)],
    [(16, 15)] + arc(16, 22.5, 3.6, -40, 220, 12) + [(16, 15)],
]
picture("fire.tga", FIRE, (), REACTION_PEN)


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
