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
        _ = Color.exergyGold
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
        XCTAssertEqual(ExergyPalette.goldDark, 0xC4A359)
        XCTAssertEqual(ExergyPalette.darkBackground, 0x0F172A)
        XCTAssertEqual(ExergyPalette.destructive, 0xEF4444)
        XCTAssertEqual(ExergySymbol.usage.systemName, "gauge.with.needle")
        _ = Color.exergyRemaining(.plentiful)
        _ = Color.exergyRemaining(.watch)
        _ = Color.exergyRemaining(.low)
        _ = Color.exergyRemaining(.unknown)
    }
}
