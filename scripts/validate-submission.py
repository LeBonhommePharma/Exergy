#!/usr/bin/env python3
"""Offline App Store configuration checks for Exergy."""
from __future__ import annotations

import json
import pathlib
import sys

SCRIPTS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
from icon_png import has_trns, read_ihdr  # noqa: E402

ROOT = SCRIPTS.parent


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit("FAIL: " + message)


def check_master_icon(path: pathlib.Path, platform: str) -> None:
    catalog = json.loads((path.parent / "Contents.json").read_text())
    require(len(catalog["images"]) >= 1, platform + " icon entries")
    for entry in catalog["images"]:
        if "platform" in entry:
            require(entry["platform"] == platform, platform + " icon platform")
        data = (path.parent / entry["filename"]).read_bytes()
        width, height, depth, color = read_ihdr(data)
        require((width, height) == (1024, 1024), platform + " icon must be 1024")
        require(depth == 8 and color == 2, platform + " icon must be RGB")
        require(not has_trns(data), platform + " icon must be opaque")


def check_mac_iconset(iconset: pathlib.Path) -> None:
    catalog = json.loads((iconset / "Contents.json").read_text())
    require(len(catalog["images"]) == 10, "Mac must list 10 AppIcon slots")
    for entry in catalog["images"]:
        w, h = (int(p) for p in entry["size"].split("x"))
        scale = int(str(entry["scale"]).rstrip("x"))
        px = w * scale
        data = (iconset / entry["filename"]).read_bytes()
        width, height, depth, color = read_ihdr(data)
        require((width, height) == (px, px), f"Mac {entry['filename']} must be {px}px")
        require(depth == 8 and color == 2, "Mac icon must be RGB")
        require(not has_trns(data), "Mac icon must be opaque RGB (no tRNS)")


def check_privacy(path: pathlib.Path) -> None:
    text = path.read_text()
    require("NSPrivacyTracking" in text, str(path) + " tracking key")
    require("<false/>" in text, str(path) + " tracking false")
    require("NSPrivacyCollectedDataTypes" in text, str(path) + " collected types")


def main() -> None:
    check_master_icon(
        ROOT / "Apps/iOS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
        "ios",
    )
    check_master_icon(
        ROOT / "Apps/watchOS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
        "watchos",
    )
    check_mac_iconset(ROOT / "Apps/Mac/Resources/Assets.xcassets/AppIcon.appiconset")
    check_privacy(ROOT / "Apps/iOS/Resources/PrivacyInfo.xcprivacy")
    check_privacy(ROOT / "Apps/Mac/Resources/PrivacyInfo.xcprivacy")
    check_privacy(ROOT / "Apps/watchOS/Resources/PrivacyInfo.xcprivacy")
    yml = (ROOT / "Apps/iOS/project.yml").read_text()
    require("WKApplication: true" in yml, "WKApplication must be Boolean true")
    require(
        "WKCompanionAppBundleIdentifier: com.lebonhommepharma.exergy" in yml,
        "Watch companion mismatch",
    )
    require("ITSAppUsesNonExemptEncryption: NO" in yml, "export compliance flag")
    mac = (ROOT / "Apps/Mac/project.yml").read_text()
    require("com.apple.security.app-sandbox: true" in mac, "Mac sandbox")
    print("OK Exergy submission contracts")


if __name__ == "__main__":
    sys.exit(main() or 0)
