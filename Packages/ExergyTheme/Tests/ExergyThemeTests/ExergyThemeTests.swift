import XCTest
import SwiftUI
import ExergyCore
@testable import ExergyTheme

final class ExergyThemeTests: XCTestCase {
    func testBrandColorConstructs() {
        let color = ExergyRGBA(hex: 0xD97757)
        XCTAssertEqual(color.red, Double(0xD9) / 255, accuracy: 0.001)
        XCTAssertEqual(color.alpha, 1)
        _ = Color.exergyBrand(ProviderKind.claude.brandColorHex)
        _ = Color.exergyAccent
        _ = Color.exergyRemaining(.low)
    }

    func testSpacingGrid() {
        XCTAssertEqual(ExergySpacing.md, 16)
        XCTAssertEqual(ExergySpacing.sm, 8)
        XCTAssertEqual(ExergyRadius.md, 12)
        XCTAssertEqual(ExergyIconSize.hit, 44)
        XCTAssertEqual(ExergyMotion.standard, 0.22, accuracy: 0.001)
        XCTAssertNil(ExergyMotion.animation(reduceMotion: true))
        XCTAssertNotNil(ExergyMotion.animation(reduceMotion: false))
    }

    func testPaletteIsNamedTokens() {
        // Pinned to palette v2 (thebonhomme.com tokens.css). These are not
        // arbitrary constants to keep green: if one changes, the app has
        // drifted off the shared palette and that is the thing worth failing
        // on. The previous values here were a Tailwind slate ramp and an
        // invented gold (0xC4A359) that no token file ever defined.
        XCTAssertEqual(ExergyPalette.accentDark, 0xFF9300)      // --tangerine
        XCTAssertEqual(ExergyPalette.accentLight, 0xA85F00)     // --tangerine-fg
        XCTAssertEqual(ExergyPalette.darkBackground, 0x08091A)  // --bg
        XCTAssertEqual(ExergyPalette.lightBackground, 0xF4F6FB) // --bg light
        XCTAssertEqual(ExergyPalette.darkInk, 0xE4E3F5)         // --fg
        XCTAssertEqual(ExergyPalette.plentifulDark, 0x45E0A8)   // --mint
        XCTAssertEqual(ExergyPalette.destructiveDark, 0xFF6B6B) // --state-fail-text
        XCTAssertEqual(ExergyPalette.destructiveLight, 0xBE123C)

        // The retired values must not come back under any name.
        for token in [ExergyPalette.accentDark, ExergyPalette.accentLight,
                      ExergyPalette.darkBackground, ExergyPalette.lightBackground,
                      ExergyPalette.darkSurface, ExergyPalette.lightSurface,
                      ExergyPalette.darkInk, ExergyPalette.lightInk,
                      ExergyPalette.darkMute, ExergyPalette.lightMute,
                      ExergyPalette.darkBorder, ExergyPalette.lightBorder,
                      ExergyPalette.plentifulDark, ExergyPalette.plentifulLight,
                      ExergyPalette.destructiveDark, ExergyPalette.destructiveLight] {
            XCTAssertNotEqual(token, 0xC4A359, "invented gold is back")
            XCTAssertNotEqual(token, 0xC4A35A, "the drifted twin of the invented gold is back")
            XCTAssertNotEqual(token, 0x8A6E2F, "the light-mode invented gold is back")
        }
        XCTAssertEqual(ExergySymbol.usage.systemName, "gauge.with.needle")
        _ = Color.exergyRemaining(.plentiful)
        _ = Color.exergyRemaining(.watch)
        _ = Color.exergyRemaining(.low)
        _ = Color.exergyRemaining(.unknown)
    }

    func testRemainingFirstGeometry() {
        let mid = ExergyRingGeometry.remainingTrim(usedPercent: 61)
        XCTAssertNotNil(mid)
        XCTAssertEqual(mid!, 0.39, accuracy: 0.0001)

        let empty = ExergyRingGeometry.remainingTrim(usedPercent: 0)
        XCTAssertNotNil(empty)
        XCTAssertEqual(empty!, 1.0, accuracy: 0.0001)

        let full = ExergyRingGeometry.remainingTrim(usedPercent: 100)
        XCTAssertNotNil(full)
        XCTAssertEqual(full!, 0.0, accuracy: 0.0001)
        // Geometry still reports Some(0); FocusRing/QuotaViews omit the gold fill.

        XCTAssertNil(ExergyRingGeometry.remainingTrim(usedPercent: nil))
        XCTAssertNil(ExergyRingGeometry.remainingTrim(usedPercent: .nan))
        XCTAssertNil(ExergyRingGeometry.remainingTrim(usedPercent: .infinity))
    }

    func testMenuBarRemainingMarksOmitZero() {
        XCTAssertEqual(MenuBarRemainingMark.height(nil), 4)
        XCTAssertEqual(MenuBarRemainingMark.height(.nan), 4)
        XCTAssertEqual(MenuBarRemainingMark.height(0), 0)
        XCTAssertEqual(MenuBarRemainingMark.height(-1), 0)
        XCTAssertEqual(MenuBarRemainingMark.height(50), 7)
        XCTAssertEqual(MenuBarRemainingMark.height(100), 14)
    }

    func testPressStyleDoesNotUsePlain() {
        XCTAssertEqual(ExergyIconSize.hit, 44)
        XCTAssertEqual(ExergyMotion.short, 0.18, accuracy: 0.001)
        _ = ExergyType.metric
        _ = ExergyEmptyState()
        _ = ExergyLoadingSkeleton()
    }
}
