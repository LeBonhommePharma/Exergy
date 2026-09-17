#!/usr/bin/env python3
"""Linux-runnable contracts that must stay true even without Swift."""
from __future__ import annotations

import json
import math
import pathlib
import re
import sys

SCRIPTS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
from icon_png import (  # noqa: E402
    GOLD,
    RETIRED_CYAN,
    RETIRED_GOLD,
    SLATE,
    decode_rgb,
    dist,
    has_trns,
    read_ihdr,
)

ROOT = SCRIPTS.parent
FAILS: list[str] = []

EMOJI_RE = re.compile(
    "["
    "\U0001f300-\U0001faff"
    "\U00002700-\U000027bf"
    "\U0001f600-\U0001f64f"
    "\U0001f680-\U0001f6ff"
    "]+"
)


def fail(msg: str) -> None:
    FAILS.append(msg)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def remaining_percent(used: float) -> float | None:
    """Mirrors Metering.remainingPercent — fail closed on non-finite used."""
    if not math.isfinite(used):
        return None
    return min(100.0, max(0.0, 100.0 - used))


def test_identity_bundle_ids() -> None:
    ident = read("Packages/ExergyCore/Sources/ExergyCore/Identity.swift")
    for needle in (
        "com.lebonhommepharma.exergy",
        "iCloud.com.lebonhommepharma.exergy",
        "ZJLX84G8QV",
        "exergy://oauth",
        "https://thebonhomme.com/Exergy/privacy/",
        "com.lebonhommepharma.exergy.pad",
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
    if "../iOS/Resources/Assets.xcassets" not in pad:
        fail("iPad must share the iOS AppIcon catalog (no separate baked corners)")


def test_fail_closed_percents() -> None:
    if remaining_percent(40) != 60:
        fail("40 used → 60 remaining")
    if remaining_percent(0) != 100:
        fail("0 used → 100 remaining")
    if remaining_percent(100) != 0:
        fail("100 used → 0 remaining")
    if remaining_percent(float("nan")) is not None:
        fail("NaN used must not invent a remaining %")
    if remaining_percent(float("inf")) is not None:
        fail("+inf used must not invent a remaining %")
    if remaining_percent(float("-inf")) is not None:
        fail("-inf used must not invent a remaining %")
    metering = read("Packages/ExergyCore/Sources/ExergyCore/Metering.swift")
    if "used.isFinite" not in metering:
        fail("Metering.remainingPercent must fail closed on non-finite used")
    if "remainingChip" not in metering or "remainingPercent(used:" not in metering:
        fail("remainingChip must go through remainingPercent")


def test_pace_formula() -> None:
    start, end, now = 0, 100, 50
    expected = (now - start) / (end - start) * 100
    if expected != 50:
        fail("pace midpoint should be 50")
    used = 56
    if used - expected <= 5:
        fail("used 56 vs expected 50 should be ahead")
    duration = 300 * 60
    remaining = 60
    elapsed = duration - remaining
    expected_end = elapsed / duration * 100
    if 90 - expected_end >= -5:
        fail("90% used with 1 min left of 5h is behind linear spend")


def test_pace_and_band_codable() -> None:
    metering = read("Packages/ExergyCore/Sources/ExergyCore/Metering.swift")
    if not re.search(r"enum PaceState:[^\n]*Codable", metering):
        fail("PaceState must be Codable (glance JSON / WidgetBridge)")
    if not re.search(r"enum RemainingBand:[^\n]*Codable", metering):
        fail("RemainingBand must be Codable")
    snap = read("Packages/ExergyCore/Sources/ExergyCore/Snapshot.swift")
    if "struct ExergyGlancePayload: Equatable, Sendable, Codable" not in snap:
        fail("ExergyGlancePayload must be Codable")
    if "pace: PaceState" not in snap:
        fail("Glance rings must carry PaceState")


def _assert_rgb_png(path: pathlib.Path, expect_w: int, expect_h: int, label: str) -> bytes:
    data = path.read_bytes()
    try:
        w, h, depth, color = read_ihdr(data)
    except ValueError as exc:
        fail(f"{label}: {exc}")
        return b""
    if (w, h) != (expect_w, expect_h):
        fail(f"{label} {w}x{h}, need {expect_w}x{expect_h}")
    if depth != 8 or color != 2:
        fail(f"{label} must be 8-bit RGB")
    if has_trns(data):
        fail(f"{label} must be opaque (no tRNS)")
    try:
        _, _, rgb = decode_rgb(data)
    except ValueError as exc:
        fail(f"{label} decode: {exc}")
        return b""
    return rgb


def _brand_ok(rgb: bytes, label: str) -> None:
    n = len(rgb) // 3
    gold_px = slate_px = retired = 0
    for i in range(0, len(rgb), 3):
        pix = (rgb[i], rgb[i + 1], rgb[i + 2])
        if dist(pix, GOLD) <= 22:
            gold_px += 1
        if dist(pix, SLATE) <= 22:
            slate_px += 1
        if dist(pix, RETIRED_GOLD) <= 40 or dist(pix, RETIRED_CYAN) <= 40:
            retired += 1
    if gold_px / n < 0.02:
        fail(f"{label} missing chrome gold #C4A359 ({gold_px / n:.3%} of pixels)")
    if slate_px / n < 0.20:
        fail(f"{label} missing slate #0F172A ground ({slate_px / n:.3%} of pixels)")
    if retired / n > 0.005:
        fail(f"{label} too close to retired #FBBF24/#22D3EE ({retired / n:.3%} of pixels)")


def _corners_are_slate(rgb: bytes, size: int, label: str) -> None:
    inset = max(8, size // 16)

    def pix(x: int, y: int) -> tuple[int, int, int]:
        i = (y * size + x) * 3
        return (rgb[i], rgb[i + 1], rgb[i + 2])

    for x, y in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1), (inset, inset)):
        if dist(pix(x, y), SLATE) > 18:
            fail(f"{label} corner/safe-zone is not slate (baked mask or oversized glyph)")
            return


def _watch_circular(rgb: bytes, size: int) -> None:
    """Gold must sit inside ~68% of the canvas so the Watch circle does not clip it."""
    cx = cy = (size - 1) / 2.0
    limit = size * 0.42
    gold_out = 0
    samples = 0
    step = 4
    for y in range(0, size, step):
        for x in range(0, size, step):
            samples += 1
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= limit * limit:
                continue
            i = (y * size + x) * 3
            pix = (rgb[i], rgb[i + 1], rgb[i + 2])
            if dist(pix, GOLD) <= 22:
                gold_out += 1
    if gold_out > 2:
        fail(f"watch icon gold leaks outside circular safe zone ({gold_out} samples)")


def test_icon_png() -> None:
    ios = ROOT / "Apps/iOS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    rgb = _assert_rgb_png(ios, 1024, 1024, "iOS icon")
    if rgb:
        _brand_ok(rgb, "iOS icon")
        _corners_are_slate(rgb, 1024, "iOS icon")

    watch = ROOT / "Apps/watchOS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
    wrgb = _assert_rgb_png(watch, 1024, 1024, "watchOS icon")
    if wrgb:
        _brand_ok(wrgb, "watchOS icon")
        _watch_circular(wrgb, 1024)

    mac_set = ROOT / "Apps/Mac/Resources/Assets.xcassets/AppIcon.appiconset"
    catalog = json.loads((mac_set / "Contents.json").read_text())
    if len(catalog["images"]) != 10:
        fail("Mac iconset must list all 10 size/scale slots")
    seen_px: set[int] = set()
    for entry in catalog["images"]:
        w, h = (int(p) for p in entry["size"].split("x"))
        scale = int(str(entry["scale"]).rstrip("x"))
        px = w * scale
        filename = entry.get("filename")
        if not filename:
            fail(f"Mac slot {entry['size']} {entry['scale']} missing filename")
            continue
        rgb = _assert_rgb_png(mac_set / filename, px, px, f"Mac {filename}")
        seen_px.add(px)
        if rgb and px >= 128:
            _brand_ok(rgb, f"Mac {filename}")
    if 16 not in seen_px or 1024 not in seen_px:
        fail("Mac catalog must include true 16px and 1024px files (not a 1024 stuffed into 16)")


def test_zero_third_party_deps() -> None:
    core = read("Packages/ExergyCore/Package.swift")
    if "dependencies: [" in core.split("let package")[1].split("targets")[0] and "url:" in core:
        fail("ExergyCore must not grow remote Swift dependencies")


def test_design_system_and_tokens() -> None:
    master = ROOT / "design-system/exergy/MASTER.md"
    if not master.is_file():
        fail("design-system/exergy/MASTER.md missing")
    master_text = master.read_text(encoding="utf-8")
    if "#C4A359" not in master_text:
        fail("Exergy MASTER.md must list remaining-gold #C4A359")
    if "| Accent/CTA | `#22C55E`" in master_text:
        fail("Exergy MASTER CTA must be gold, not generated green")
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
    apps = ROOT / "Apps"
    for path in sorted(apps.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        if "Color(.sRGB" in text:
            fail(f"{rel} uses raw sRGB instead of tokens")
        if EMOJI_RE.search(text):
            fail(f"{rel} uses emoji as chrome")
    phone = read("Apps/iOS/Sources/ExergyPhoneApp.swift")
    if "TabView" not in phone:
        fail("iPhone shell must use TabView")
    if phone.count("tabItem") < 3:
        fail("iPhone tabs must keep labels (Usage / Add / Settings)")
    pad = read("Apps/iPad/Sources/ExergyPadApp.swift")
    if "NavigationSplitView" not in pad:
        fail("iPad shell must use NavigationSplitView")
    mac = read("Apps/Mac/Sources/ExergyMacApp.swift")
    if "MacGlanceHUD" not in mac or "MenuBarExtra" not in mac:
        fail("Mac shell must keep MenuBarExtra and floating HUD")
    if "ExergyRingGeometry.remainingTrim" not in theme:
        fail("focus rings must fill remaining work, not used spend")
    if "ExergyPressStyle" not in read("Packages/ExergyTheme/Sources/ExergyTheme/ExergyControls.swift"):
        fail("buttons must use ExergyPressStyle (Reduce Motion aware)")
    if "ExergyLoadingSkeleton" not in read("Packages/ExergyTheme/Sources/ExergyTheme/ExergyControls.swift"):
        fail("empty remaining meters need a loading skeleton that never paints 0%")
    if "LabeledContent" not in read("Apps/Shared/UsageHomeView.swift"):
        fail("add-account form must use visible labels, not placeholder-only")
    if "minHeight: ExergyIconSize.hit" not in read("Apps/watchOS/Sources/ExergyWatchApp.swift"):
        fail("Watch account rows must keep 44pt hits")
    if '?? "—"' not in read("Apps/Shared/WatchDial.swift"):
        fail("Watch dial must render em-dash when remaining is unknown")
    if "emptyAction" not in read("Packages/ExergyCore/Sources/ExergyCore/L10n.swift"):
        fail("empty state must name a next action")
    if "ExergyPressStyle" not in mac:
        fail("Mac menu-bar links must use ExergyPressStyle")
    if "remaining ?? 0" in read("Packages/ExergyTheme/Sources/ExergyTheme/QuotaViews.swift"):
        fail("menu-bar remaining marks must not invent 0% height")
    if "ExergyLoadingSkeleton" not in read("Apps/Shared/UsageHomeView.swift"):
        fail("unknown account usage must show ExergyLoadingSkeleton, not a 0% ring")
    if 'Text("—")' not in read("Apps/watchOS/Sources/ExergyWatchApp.swift"):
        fail("Watch remaining numeral must be an em-dash when unknown")
    shannon_root = ROOT.parent
    phone = shannon_root / "iOS/Sources/ShannonPhone/HomeView.swift"
    watch = shannon_root / "watchOS/Sources/ShannonWatch/WatchRootView.swift"
    widget = shannon_root / "iOS/Sources/ShannonWidget/ShannonWidget.swift"
    pad_batt = shannon_root / "iPad/Sources/ShannonPad/Views/StatusCardsView.swift"
    if phone.is_file() and "accessibilityReduceMotion" not in phone.read_text(encoding="utf-8"):
        fail("Shannon press style must honor Reduce Motion")
    if phone.is_file() and 'title: media.isPlaying ? "Pause" : "Play"' not in phone.read_text(encoding="utf-8"):
        fail("phone transport controls must keep visible accessibility labels")
    if watch.is_file() and ".labelStyle(.iconOnly)" in watch.read_text(encoding="utf-8"):
        fail("Watch gate Approve/Deny must show titles, not icon-only")
    if widget.is_file() and "Gauge(value: 0)" in widget.read_text(encoding="utf-8"):
        fail("Shannon widget must not invent a 0-capacity gauge")
    if widget.is_file() and "Gauge(value: docking.fraction)" in widget.read_text(encoding="utf-8"):
        fail("Shannon widget circular gauge must use knownFraction, not a 0% track")
    if widget.is_file() and "max(fraction, 0.001)" in widget.read_text(encoding="utf-8"):
        fail("Shannon widget ring must not paint a fake 0.1% sliver")
    if pad_batt.is_file() and "percent ?? 0" in pad_batt.read_text(encoding="utf-8"):
        fail("iPad battery rings must not coerce unknown percent to 0")
    if pad_batt.is_file() and "max(fraction, 0.001)" in pad_batt.read_text(encoding="utf-8"):
        fail("iPad battery rings must not paint a fake 0.1% sliver")
    pad_card = shannon_root / "iPad/Sources/ShannonPad/Views/AgentCardView.swift"
    if pad_card.is_file() and "ShannonLayout.hitTarget" not in pad_card.read_text(encoding="utf-8"):
        fail("iPad annotate control must keep a 44pt hit target")
    face = shannon_root / "watchOS/Sources/ShannonWatch/ShannonFaceView.swift"
    if face.is_file():
        face_text = face.read_text(encoding="utf-8")
        if "Int(progress.fraction * 100)" in face_text:
            fail("Watch docking percent must use percentLabel, not raw *100")
        if 'String(format: "H %.2f"' in face_text:
            fail("Watch face entropy must use entropyLabel, not raw H %.2f")
        if "accessibilityAddTraits(.isButton)" in face_text:
            fail("Watch clock must not advertise a button trait")
        if "progress.targetsTotal > 0 ? progress.fraction : 0" in face_text:
            fail("Watch docking ProgressView must omit the bar when total is unknown")
        if "progress.knownFraction" not in face_text:
            fail("Watch docking row must use knownFraction")
    docking = shannon_root / "Packages/ShannonCore/Sources/ShannonCore/DockingProgress.swift"
    if docking.is_file():
        docking_text = docking.read_text(encoding="utf-8")
        if "percentLabel" not in docking_text:
            fail("DockingProgress must expose percentLabel that fails closed on zero total")
        if "var knownFraction: Double?" not in docking_text:
            fail("DockingProgress must expose knownFraction so glances can omit unknown bars")
    pad_dock = shannon_root / "iPad/Sources/ShannonPad/Views/DockingProgressView.swift"
    if pad_dock.is_file() and 'Int(fraction * 100)' in pad_dock.read_text(encoding="utf-8"):
        fail("iPad docking ring must use percentLabel, not raw *100")
    phone_home = shannon_root / "iOS/Sources/ShannonPhone/HomeView.swift"
    if phone_home.is_file() and "max(fraction, 0.001)" in phone_home.read_text(encoding="utf-8"):
        fail("phone docking ring must not paint a fake 0.1% sliver")
    complication = shannon_root / "watchOS/Sources/ShannonWatchComplication/ShannonComplication.swift"
    if complication.is_file():
        complication_text = complication.read_text(encoding="utf-8")
        if 'String(format: "H %.2f"' in complication_text:
            fail("Watch complication entropy must use entropyLabel")
        if "Gauge(value: docking.fraction)" in complication_text:
            fail("Watch complication gauges must use knownFraction, not a 0% track")
    shannon_theme = ROOT.parent / "Packages/ShannonTheme/Sources/ShannonTheme/SemanticColors.swift"
    if shannon_theme.is_file():
        st = shannon_theme.read_text(encoding="utf-8")
        if "0x508CFF" in st:
            fail("Shannon separators must not use leftover electric-blue chrome")
        if "0x45E0A8" not in st or "0x8B5CF6" not in st:
            fail("Shannon accent/entropy tokens must stay mint/violet")
    agent = ROOT.parent / "Packages/ShannonCore/Sources/ShannonCore/AgentState.swift"
    if agent.is_file() and "var systemImage: String" not in agent.read_text(encoding="utf-8"):
        fail("AgentActivity must expose SF Symbol systemImage for Watch chrome")


def _decode_plan_glance(raw: bytes) -> dict | None:
    """Mirrors ExergyPlanGlance.decode — empty/malformed JSON is nil, never 0%."""
    try:
        payload = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict):
        return None
    rings = payload.get("rings")
    if not isinstance(rings, list):
        return None
    parts: list[str] = []
    for ring in rings:
        if not isinstance(ring, dict):
            continue
        used = ring.get("usedPercent")
        if not isinstance(used, (int, float)) or isinstance(used, bool) or not math.isfinite(used):
            continue
        remaining = min(100.0, max(0.0, 100.0 - float(used)))
        tag = None
        for key in ("windowTag", "title", "provider"):
            value = ring.get(key)
            if isinstance(value, str) and value.strip():
                tag = value.strip()
                break
        parts.append(f"{tag or 'win'} {remaining:.0f}% left")
    if not parts:
        return None
    return {
        "combinedChip": " · ".join(parts[:3]),
        "demo": bool(payload.get("demo") or False),
    }


def test_glance_is_remaining() -> None:
    snap = read("Packages/ExergyCore/Sources/ExergyCore/Snapshot.swift")
    if "remainingChip" not in snap:
        fail("Glance chips must go through remainingChip")
    if "usedPercent" in snap and "remainingChip(tag:" not in snap:
        fail("Glance chip helper must not skip remainingChip")
    if "func empty(now: Date = Date())" not in snap:
        fail("ExergyGlancePayload must expose empty() for cache-miss glances")
    if "func loadFromAppGroup" not in snap:
        fail("WidgetBridge must load App Group JSON without inventing remaining %")
    widget = read("Apps/iOS/Sources/Widget/ExergyWidget.swift")
    if "completion(.live())" not in widget:
        fail("Exergy widget snapshot/timeline must use live App Group data")
    if "?? placeholder" in widget or "completion(placeholder" in widget:
        fail("Exergy widget must not fall back to demo remaining %")
    complication = read("Apps/watchOS/Sources/ExergyWatchComplication.swift")
    if "completion(.live())" not in complication:
        fail("Watch complication snapshot/timeline must use live App Group data")
    if "let entry = placeholder(in: context)" in complication:
        fail("Watch complication must not always paint demo remaining %")
    entry = read("Apps/Shared/ExergyWidgetEntry.swift")
    if "static func live" not in entry or "static func unknown" not in entry:
        fail("ExergyWidgetEntry must expose live/unknown, not demo-only")
    shannon = ROOT.parents[1] / "Pill/Sources/UsageCore/ExergyPlanGlance.swift"
    if shannon.is_file():
        text = shannon.read_text(encoding="utf-8")
        if "%.0f%% left" not in text:
            fail("Shannon glance chip must show remaining left, not used")
        if "used.isFinite" not in text:
            fail("Shannon glance must fail closed on non-finite used %")
        if "guard let payload = try? decoder.decode(Payload.self, from: data) else {" not in text:
            fail("ExergyPlanGlance.decode must fail closed on malformed JSON")
        if "guard !parts.isEmpty else { return nil }" not in text:
            fail("ExergyPlanGlance.decode must return nil for empty rings")


def test_malformed_glance_json_is_nil() -> None:
    good = _decode_plan_glance(
        b'{"demo":true,"rings":[{"usedPercent":61,"windowTag":"Week","title":"Claude","provider":"claude"}]}'
    )
    if good != {"combinedChip": "Week 39% left", "demo": True}:
        fail(f"valid glance decode drifted: {good}")
    for raw in (
        b"",
        b"{",
        b"null",
        b"[]",
        b"{}",
        b'{"rings":[]}',
        b'{"rings":[{"title":"Claude"}]}',
        b'{"rings":[{"usedPercent":"nope","windowTag":"Week"}]}',
        b'{"rings":[{"usedPercent":NaN,"windowTag":"Week"}]}',
        b'{"rings":[{"usedPercent":Infinity,"windowTag":"Week"}]}',
    ):
        if _decode_plan_glance(raw) is not None:
            fail(f"malformed glance must be nil, got a chip from {raw!r}")
    tests = ROOT.parents[1] / "Pill/Tests/PillCoreTests/UsageCoreTests.swift"
    if tests.is_file():
        text = tests.read_text(encoding="utf-8")
        if 'ExergyPlanGlance.decode(Data("{}".utf8))' not in text:
            fail("Swift must assert empty object glance JSON → nil")
        if 'ExergyPlanGlance.decode(Data("{\\"rings\\":[]}".utf8))' not in text:
            fail("Swift must assert empty rings glance JSON → nil")


def main() -> int:
    tests = (
        test_identity_bundle_ids,
        test_no_secrets_in_cloud_keys,
        test_privacy_manifests,
        test_project_bundle_ids,
        test_fail_closed_percents,
        test_pace_formula,
        test_pace_and_band_codable,
        test_icon_png,
        test_zero_third_party_deps,
        test_design_system_and_tokens,
        test_glance_is_remaining,
        test_malformed_glance_json_is_nil,
    )
    for test in tests:
        test()
    if FAILS:
        print("FAIL")
        for item in FAILS:
            print(" -", item)
        return 1
    print(f"OK {len(tests)} contracts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
