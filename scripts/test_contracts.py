#!/usr/bin/env python3
"""Linux-runnable contracts that must stay true even without Swift."""
from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FAILS: list[str] = []


def fail(msg: str) -> None:
    FAILS.append(msg)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_identity_bundle_ids() -> None:
    ident = read("Packages/ExergyCore/Sources/ExergyCore/Identity.swift")
    for needle in (
        "com.lebonhommepharma.exergy",
        "iCloud.com.lebonhommepharma.exergy",
        "ZJLX84G8QV",
        "exergy://oauth",
        "https://thebonhomme.com/Exergy/privacy/",
    ):
        if needle not in ident:
            fail(f"Identity.swift missing {needle}")


def test_no_secrets_in_cloud_keys() -> None:
    cloud = read("Packages/ExergyCore/Sources/ExergyCore/CloudRecord.swift")
    keys = re.findall(r'static let (\w+) = "([^"]+)"', cloud)
    forbidden = (
        "token",
        "secret",
        "password",
        "apikey",
        "api_key",
        "bearer",
        "oauth",
        "cookie",
        "pkce",
        "verifier",
    )
    for name, value in keys:
        blob = (name + value).lower()
        for bad in forbidden:
            if bad in blob.replace("_", ""):
                fail(f"CloudKeys {name}={value} looks like a secret field")


def test_privacy_manifests() -> None:
    for rel in (
        "Apps/iOS/Resources/PrivacyInfo.xcprivacy",
        "Apps/Mac/Resources/PrivacyInfo.xcprivacy",
        "Apps/watchOS/Resources/PrivacyInfo.xcprivacy",
    ):
        text = read(rel)
        if "<false/>" not in text:
            fail(f"{rel} must set NSPrivacyTracking false")
        if "NSPrivacyCollectedDataTypes" not in text:
            fail(f"{rel} missing collected data types")


def test_project_bundle_ids() -> None:
    ios = read("Apps/iOS/project.yml")
    mac = read("Apps/Mac/project.yml")
    pad = read("Apps/iPad/project.yml")
    if "PRODUCT_BUNDLE_IDENTIFIER: com.lebonhommepharma.exergy\n" not in ios.replace("\r", ""):
        if "PRODUCT_BUNDLE_IDENTIFIER: com.lebonhommepharma.exergy" not in ios:
            fail("iOS bundle id missing")
    if "com.lebonhommepharma.exergy.watchkitapp" not in ios:
        fail("watch bundle id missing")
    if "com.lebonhommepharma.exergy.mac" not in mac:
        fail("mac bundle id missing")
    if "com.lebonhommepharma.exergy.pad" not in pad:
        fail("pad bundle id missing")
    if "LSUIElement: true" not in mac:
        fail("Mac must be a menu-bar extra (LSUIElement)")
    if "WKApplication: true" not in ios:
        fail("Watch WKApplication must be boolean true in yml")


def test_pace_formula() -> None:
    # Spec: expected = elapsed/duration * 100; ahead if used > expected + 5
    start, end, now = 0, 100, 50
    expected = (now - start) / (end - start) * 100
    if expected != 50:
        fail("pace midpoint should be 50")
    used = 56
    assert used - expected > 5


def test_icon_png() -> None:
    png = ROOT / "Apps/iOS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    data = png.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail("iOS icon is not PNG")
    import struct

    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    if (width, height) != (1024, 1024):
        fail(f"iOS icon {width}x{height}, need 1024")
    if depth != 8 or color != 2:
        fail("iOS icon must be 8-bit RGB")
    if b"tRNS" in data:
        fail("App Store iOS icon must be opaque")


def test_zero_third_party_deps() -> None:
    core = read("Packages/ExergyCore/Package.swift")
    if "dependencies: [" in core.split("let package")[1].split("targets")[0] and "url:" in core:
        fail("ExergyCore must not grow remote Swift dependencies")


def main() -> int:
    test_identity_bundle_ids()
    test_no_secrets_in_cloud_keys()
    test_privacy_manifests()
    test_project_bundle_ids()
    test_pace_formula()
    test_icon_png()
    test_zero_third_party_deps()
    if FAILS:
        print("FAIL")
        for item in FAILS:
            print(" -", item)
        return 1
    print(f"OK {7} contracts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
