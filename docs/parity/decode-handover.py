#!/usr/bin/env python3
"""
Decode the body text of "Get Gym Done — Master Engineering Handover.pdf".

The PDF (in the Android repo at app/reference/) embeds subsetted fonts with broken
ToUnicode maps, so its extracted text layer is mojibake. Each embedded font has its own
arbitrary glyph->character mapping; the map below covers the *body* face, which carries
almost all of the prose. Headings set in the display face use a different map and come out
as '?' — read those from the rendered page PNGs (app/reference/pages/*.png), which are
perfectly legible.

Usage:
    python3 decode-handover.py <path-to-handover.txt> [> decoded.txt]

Derived by cribbing the known opening sentence ("This document is self-contained; design
system, shared components, iconography, navigation model, ...") and the numbered contents
page, then extending through the section titles.
"""

import sys

BODY_FONT_MAP = {
    # lowercase letters
    '<': 'a', 'I': 'b', '0': 'c', '6': 'd', '.': 'e', ';': 'f', '9': 'g', '-': 'h',
    '8': 'i', 'G': 'k', '4': 'l', '2': 'm', ':': 'n', '1': 'o', '3': 'p', '=': 'r',
    '7': 's', '5': 't', 'H': 'u', 'N': 'v', 'F': 'w', 'R': 'x', 'M': 'y', 's': 'z',
    # uppercase letters
    'E': 'A', 'r': 'C', 'k': 'D', 't': 'E', 'u': 'H', 'n': 'I', '{': 'M', 'p': 'N',
    'y': 'O', 'i': 'P', 'S': 'R', 'm': 'S', ',': 'T', 'x': 'W',
    # digits
    'g': '0', 'Z': '1', '_': '2', 'l': '3', '^': '4', 'o': '5', 'q': '6', '[': '7',
    'a': '8', 'b': '9', 'z': '3',
    # punctuation
    'D': ',', 'J': '.', 'L': ';', 'K': '-', 'Q': '—', 'X': '(', 'Y': ')',
    'j': '·', 'v': '&', 'w': '+',
}

UNKNOWN = '?'


def decode(text: str) -> str:
    return ''.join(
        c if c.isspace() else BODY_FONT_MAP.get(c, UNKNOWN)
        for c in text
    )


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    raw = open(sys.argv[1], encoding='utf-8', errors='replace').read()
    out = decode(raw)
    total = sum(1 for c in raw if not c.isspace())
    unresolved = out.count(UNKNOWN)
    print(out)
    print(
        f'\n--- {unresolved}/{total} glyphs unresolved '
        f'({unresolved / total * 100:.0f}%, mostly display-face headings) ---',
        file=sys.stderr,
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
