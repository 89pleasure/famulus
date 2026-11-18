#!/usr/bin/env python3
"""Builds the fonts Schnitzel ships (Schnitzel/Media/Fonts/*.ttf) from Inter.

Inter (https://rsms.me/inter, SIL Open Font License 1.1) is cut down to the
scripts the addon can show: Latin, Greek and Cyrillic plus punctuation. That
keeps each file small; the window loads them only when it is first opened.

Needs fontTools (pip install fonttools) and the static TTFs of an Inter
release (Inter-<version>.zip, folder extras/ttf). Run:

    python3 tools/make_fonts.py path/to/Inter/extras/ttf
"""

import os
import shutil
import sys

from fontTools import subset

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Schnitzel", "Media", "Fonts")

WEIGHTS = ["Regular", "Medium", "SemiBold"]

UNICODES = [
    (0x0020, 0x007E),  # Basic Latin
    (0x00A0, 0x00FF),  # Latin-1 Supplement (umlauts, ß, ·)
    (0x0100, 0x024F),  # Latin Extended-A and -B
    (0x0370, 0x03FF),  # Greek
    (0x0400, 0x04FF),  # Cyrillic
    (0x2000, 0x206F),  # General Punctuation (– — „ “ … •)
    (0x20A0, 0x20CF),  # Currency
    (0x2122, 0x2122),  # ™
    (0x2190, 0x21FF),  # Arrows
    (0x2212, 0x2212),  # Minus
]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    source = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    codepoints = [c for start, end in UNICODES for c in range(start, end + 1)]
    for weight in WEIGHTS:
        options = subset.Options()
        options.layout_features = ["kern"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        options.hinting = False
        font = subset.load_font(os.path.join(source, "Inter-%s.ttf" % weight), options)
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=codepoints)
        subsetter.subset(font)
        target = os.path.join(OUT, "Inter-%s.ttf" % weight)
        subset.save_font(font, target, options)
        print("wrote", os.path.relpath(target), os.path.getsize(target) // 1024, "KB")

    license_file = os.path.join(source, "..", "..", "LICENSE.txt")
    if os.path.exists(license_file):
        shutil.copyfile(license_file, os.path.join(OUT, "LICENSE.txt"))
        print("copied LICENSE.txt")


if __name__ == "__main__":
    main()
