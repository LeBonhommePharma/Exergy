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
    }

    func testSpacingGrid() {
        XCTAssertEqual(ExergySpacing.md, 16)
        XCTAssertEqual(ExergyRadius.md, 16)
    }
}
