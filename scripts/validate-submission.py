#!/usr/bin/env python3
"""Offline App Store configuration checks for Exergy."""
from __future__ import annotations

import json
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit("FAIL: " + message)


def check_icon(iconset: pathlib.Path, platform: str) -> None:
    catalog = json.loads((iconset / "Contents.json").read_text())
    require(len(catalog["images"]) >= 1, platform + " icon entries")
    for entry in catalog["images"]:
        if "platform" in entry:
            require(entry["platform"] == platform, platform + " icon platform")
        data = (iconset / entry["filename"]).read_bytes()
        require(data[:8] == b"\x89PNG\r\n\x1a\n", platform + " icon must be PNG")
        width, height, depth, color = struct.unpack(">IIBB", data[16:26])
        require((width, height) == (1024, 1024), platform + " icon must be 1024")
        require(depth == 8 and color == 2, platform + " icon must be RGB")
        require(b"tRNS" not in data, platform + " icon must be opaque")


def check_privacy(path: pathlib.Path) -> None:
    text = path.read_text()
    require("NSPrivacyTracking" in text, str(path) + " tracking key")
    require("<false/>" in text, str(path) + " tracking false")
    require("NSPrivacyCollectedDataTypes" in text, str(path) + " collected types")


def main() -> None:
    check_icon(ROOT / "Apps/iOS/Resources/Assets.xcassets/AppIcon.appiconset", "ios")
    check_icon(ROOT / "Apps/watchOS/Resources/Assets.xcassets/AppIcon.appiconset", "watchos")
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
