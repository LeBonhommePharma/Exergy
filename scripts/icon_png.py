#!/usr/bin/env python3
"""Stdlib PNG read/write for Exergy App Store icons (RGB8, no alpha)."""
from __future__ import annotations

import struct
import zlib
from collections import Counter
from pathlib import Path

PNG_SIG = b"\x89PNG\r\n\x1a\n"
# Palette v2, mirroring ExergyPalette. The icon is tangerine-on-ink: tangerine
# is dG, the work still available, which is what the gauge shows.
ACCENT = (0xFF, 0x93, 0x00)   # --tangerine
INK = (0x08, 0x09, 0x1A)      # --bg
TRACK = (0x11, 0x12, 0x26)    # --bg-card, the spent arc
# Must never appear: the retired v1 hues, and the invented gold this icon used
# to be drawn in (plus the one-digit drift of it that reached ProviderKind).
RETIRED_GOLD = (0xFB, 0xBF, 0x24)
RETIRED_CYAN = (0x22, 0xD3, 0xEE)
INVENTED_GOLD = (0xC4, 0xA3, 0x59)
INVENTED_GOLD_DRIFT = (0xC4, 0xA3, 0x5A)
INVENTED_GOLD_LIGHT = (0x8A, 0x6E, 0x2F)
# Back-compat aliases so nothing silently keeps the old spelling.
GOLD = ACCENT
SLATE = INK


def dist(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def chunk(tag: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)


def write_rgb_png(path: Path, rgb: bytes, width: int, height: int) -> None:
    if len(rgb) != width * height * 3:
        raise ValueError("RGB buffer size mismatch")
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw.extend(rgb[y * stride : (y + 1) * stride])
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    payload = (
        PNG_SIG
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def read_ihdr(data: bytes) -> tuple[int, int, int, int]:
    if data[:8] != PNG_SIG:
        raise ValueError("not a PNG")
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    return width, height, depth, color


def decode_rgb(data: bytes) -> tuple[int, int, bytes]:
    if data[:8] != PNG_SIG:
        raise ValueError("not a PNG")
    i = 8
    idat = b""
    width = height = depth = color = 0
    while i < len(data):
        ln = struct.unpack(">I", data[i : i + 4])[0]
        typ = data[i + 4 : i + 8]
        chunk_data = data[i + 8 : i + 8 + ln]
        if typ == b"IHDR":
            width, height, depth, color, _c, _f, inter = struct.unpack(">IIBBBBB", chunk_data)
            if inter:
                raise ValueError("interlaced PNG not supported")
        elif typ == b"IDAT":
            idat += chunk_data
        elif typ == b"tRNS":
            raise ValueError("tRNS (transparency) not allowed on App Store iOS icons")
        i += 12 + ln
    if depth != 8 or color != 2:
        raise ValueError(f"need 8-bit RGB, got depth={depth} color={color}")
    raw = zlib.decompress(idat)
    bpp = 3
    prev = bytearray(width * bpp)
    img = bytearray(width * height * 3)
    off = 0

    def paeth(a: int, b: int, c: int) -> int:
        p = a + b - c
        pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
        if pa <= pb and pa <= pc:
            return a
        if pb <= pc:
            return b
        return c

    for y in range(height):
        ft = raw[off]
        off += 1
        row = bytearray(raw[off : off + width * bpp])
        off += width * bpp
        if ft == 1:
            for x in range(len(row)):
                a = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + a) & 255
        elif ft == 2:
            for x in range(len(row)):
                row[x] = (row[x] + prev[x]) & 255
        elif ft == 3:
            for x in range(len(row)):
                a = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + ((a + prev[x]) // 2)) & 255
        elif ft == 4:
            for x in range(len(row)):
                a = row[x - bpp] if x >= bpp else 0
                b = prev[x]
                c = prev[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + paeth(a, b, c)) & 255
        elif ft != 0:
            raise ValueError(f"unknown PNG filter {ft}")
        prev = row
        img[y * width * 3 : (y + 1) * width * 3] = row
    return width, height, bytes(img)


def has_trns(data: bytes) -> bool:
    return b"tRNS" in data


def color_counts(rgb: bytes) -> Counter[tuple[int, int, int]]:
    ctr: Counter[tuple[int, int, int]] = Counter()
    for i in range(0, len(rgb), 3):
        ctr[(rgb[i], rgb[i + 1], rgb[i + 2])] += 1
    return ctr
