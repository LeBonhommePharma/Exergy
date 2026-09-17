#!/usr/bin/env python3
"""Render Exergy App Store icons: remaining-work gauges in brand gold/slate.

Masters are geometric (not a downscaled photo) so 16px Mac slots stay readable.
Requires numpy at render time; CI validates the committed PNGs with stdlib only.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
from icon_png import GOLD, SLATE, TRACK, write_rgb_png  # noqa: E402

ROOT = SCRIPTS.parent


def _annulus_coverage(r: np.ndarray, inner: float, outer: float) -> np.ndarray:
    """Soft coverage in [0, 1] for a ring with ~1px AA at the destination scale."""
    aa = 0.85
    inner_c = np.clip((r - (inner - aa)) / (2 * aa), 0.0, 1.0)
    outer_c = np.clip(((outer + aa) - r) / (2 * aa), 0.0, 1.0)
    return inner_c * outer_c


def render_gauge(
    size: int,
    *,
    content_diameter: float,
    remaining: tuple[float, ...],
    stroke_frac: float,
    gap_frac: float,
) -> bytes:
    """Square RGB8 icon. content_diameter is the outer ring as a fraction of canvas."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float64)
    cx = cy = (size - 1) / 2.0
    dx = xx - cx
    dy = yy - cy
    radius = np.sqrt(dx * dx + dy * dy)
    # 0 at 12 o'clock, clockwise.
    ang = np.mod(np.arctan2(dx, -dy), 2.0 * np.pi)

    canvas = np.empty((size, size, 3), dtype=np.float64)
    canvas[:] = np.array(SLATE, dtype=np.float64)

    outer = (size * content_diameter) / 2.0
    n = len(remaining)
    stroke = outer * stroke_frac
    gap = outer * gap_frac
    # Small empty hub so it reads as a gauge, not a filled pie.
    hub_r = max(size * 0.055, outer * 0.16)

    gold = np.array(GOLD, dtype=np.float64)
    track = np.array(TRACK, dtype=np.float64)

    for i, frac in enumerate(remaining):
        outer_i = outer - i * (stroke + gap)
        inner_i = outer_i - stroke
        if inner_i < hub_r + size * 0.01:
            break
        cover = _annulus_coverage(radius, inner_i, outer_i)
        sweep = max(0.0, min(1.0, frac)) * 2.0 * np.pi
        # 7° opening at 12 o'clock so the remaining arc has a start.
        opening = 0.12
        remaining_mask = (ang >= opening) & (ang <= opening + sweep)
        mix = cover[..., None]
        canvas = canvas * (1.0 - mix) + track * mix
        gold_cover = cover * remaining_mask
        gm = gold_cover[..., None]
        canvas = canvas * (1.0 - gm) + gold * gm

    hub = _annulus_coverage(radius, 0.0, hub_r * 0.55)
    canvas = canvas * (1.0 - hub[..., None]) + gold * hub[..., None]

    out = np.clip(np.rint(canvas), 0, 255).astype(np.uint8)
    return out.tobytes()


def render_ios() -> bytes:
    return render_gauge(
        1024,
        content_diameter=0.74,
        remaining=(0.84, 0.61, 0.38),
        stroke_frac=0.11,
        gap_frac=0.045,
    )


def render_watch() -> bytes:
    # Central 66% so the circular Watch mask has ~8% margin past the outer ring.
    return render_gauge(
        1024,
        content_diameter=0.66,
        remaining=(0.84, 0.58),
        stroke_frac=0.16,
        gap_frac=0.055,
    )


def render_mac(pixel_size: int) -> bytes:
    if pixel_size <= 32:
        return render_gauge(
            pixel_size,
            content_diameter=0.78,
            remaining=(0.75,),
            stroke_frac=0.28,
            gap_frac=0.0,
        )
    if pixel_size <= 128:
        return render_gauge(
            pixel_size,
            content_diameter=0.72,
            remaining=(0.84, 0.55),
            stroke_frac=0.16,
            gap_frac=0.05,
        )
    return render_gauge(
        pixel_size,
        content_diameter=0.74,
        remaining=(0.84, 0.61, 0.38),
        stroke_frac=0.11,
        gap_frac=0.045,
    )


def write_icon(path: Path, rgb: bytes, size: int) -> None:
    write_rgb_png(path, rgb, size, size)
    print(f"wrote {path.relative_to(ROOT)} ({size}x{size}, {path.stat().st_size} bytes)")


def write_mac_contents(iconset: Path, files: dict[tuple[str, str], str]) -> None:
    images = []
    for (size, scale), filename in files.items():
        images.append(
            {
                "filename": filename,
                "idiom": "mac",
                "scale": scale,
                "size": size,
            }
        )
    (iconset / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2)
        + "\n",
        encoding="utf-8",
    )


def main() -> int:
    ios = ROOT / "Apps/iOS/Resources/Assets.xcassets/AppIcon.appiconset"
    watch = ROOT / "Apps/watchOS/Resources/Assets.xcassets/AppIcon.appiconset"
    mac = ROOT / "Apps/Mac/Resources/Assets.xcassets/AppIcon.appiconset"

    write_icon(ios / "AppIcon-1024.png", render_ios(), 1024)
    write_icon(watch / "AppIcon-1024.png", render_watch(), 1024)

    # Pixel-true Mac slots so 16px is not a muddy 1024 downscale.
    sizes = {
        16: "icon_16.png",
        32: "icon_32.png",
        64: "icon_64.png",
        128: "icon_128.png",
        256: "icon_256.png",
        512: "icon_512.png",
        1024: "icon_1024.png",
    }
    for px, name in sizes.items():
        write_icon(mac / name, render_mac(px), px)

    write_mac_contents(
        mac,
        {
            ("16x16", "1x"): "icon_16.png",
            ("16x16", "2x"): "icon_32.png",
            ("32x32", "1x"): "icon_32.png",
            ("32x32", "2x"): "icon_64.png",
            ("128x128", "1x"): "icon_128.png",
            ("128x128", "2x"): "icon_256.png",
            ("256x256", "1x"): "icon_256.png",
            ("256x256", "2x"): "icon_512.png",
            ("512x512", "1x"): "icon_512.png",
            ("512x512", "2x"): "icon_1024.png",
        },
    )
    # Drop the old shared 1024 that was wired into every Mac slot.
    stale = mac / "AppIcon-1024.png"
    if stale.exists():
        stale.unlink()
        print("removed Mac AppIcon-1024.png (replaced by size-true slots)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
