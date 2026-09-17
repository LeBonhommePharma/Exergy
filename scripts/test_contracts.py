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
    if used - expected <= 5:
        fail("used 56 vs expected 50 should be ahead")
    # 5h window, 1 min remaining, used 90 → expected ≈ 99.67 → behind
    duration = 300 * 60
    remaining = 60
    elapsed = duration - remaining
    expected_end = elapsed / duration * 100
    if 90 - expected_end >= -5:
        fail("90% used with 1 min left of 5h is behind linear spend")


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


def test_design_system_and_tokens() -> None:
    master = ROOT / "design-system/exergy/MASTER.md"
    if not master.is_file():
        fail("design-system/exergy/MASTER.md missing")
    theme = read("Packages/ExergyTheme/Sources/ExergyTheme/ExergyTheme.swift")
    for needle in (
        "0xC4A359",
        "0x0F172A",
        "accessibilityReduceMotion",
        "gauge.with.needle",
        "ExergyPalette",
    ):
        if needle not in theme:
            fail(f"ExergyTheme missing {needle}")
    metering = read("Packages/ExergyCore/Sources/ExergyCore/Metering.swift")
    if "RemainingBand" not in metering or "remainingChip" not in metering:
        fail("Metering must expose RemainingBand and remainingChip")
    for rel in (
        "Apps/Mac/Sources/ExergyMacApp.swift",
        "Apps/iOS/Sources/ExergyPhoneApp.swift",
        "Apps/iPad/Sources/ExergyPadApp.swift",
        "Apps/watchOS/Sources/ExergyWatchApp.swift",
    ):
        text = read(rel)
        if "Color(.sRGB" in text:
            fail(f"{rel} uses raw sRGB instead of tokens")
        if any(ch in text for ch in ("🎨", "🚀", "⚙️", "✨")):
            fail(f"{rel} uses emoji as chrome")
    phone = read("Apps/iOS/Sources/ExergyPhoneApp.swift")
    if "TabView" not in phone:
        fail("iPhone shell must use TabView")
    pad = read("Apps/iPad/Sources/ExergyPadApp.swift")
    if "NavigationSplitView" not in pad:
        fail("iPad shell must use NavigationSplitView")
    mac = read("Apps/Mac/Sources/ExergyMacApp.swift")
    if "MacGlanceHUD" not in mac or "MenuBarExtra" not in mac:
        fail("Mac shell must keep MenuBarExtra and floating HUD")


def test_glance_is_remaining() -> None:
    snap = read("Packages/ExergyCore/Sources/ExergyCore/Snapshot.swift")
    if "remainingChip" not in snap:
        fail("Glance chips must go through remainingChip")
    shannon = ROOT.parents[1] / "Pill/Sources/UsageCore/ExergyPlanGlance.swift"
    if shannon.is_file():
        text = shannon.read_text(encoding="utf-8")
        if "%.0f%% left" not in text:
            fail("Shannon glance chip must show remaining left, not used")


def main() -> int:
    test_identity_bundle_ids()
    test_no_secrets_in_cloud_keys()
    test_privacy_manifests()
    test_project_bundle_ids()
    test_pace_formula()
    test_icon_png()
    test_zero_third_party_deps()
    test_design_system_and_tokens()
    test_glance_is_remaining()
    if FAILS:
        print("FAIL")
        for item in FAILS:
            print(" -", item)
        return 1
    print(f"OK {9} contracts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
