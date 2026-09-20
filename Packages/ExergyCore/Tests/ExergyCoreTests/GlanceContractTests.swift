import XCTest
@testable import ExergyCore

/// The glance JSON is a CROSS-REPO contract.
///
/// Exergy writes `exergy-glance.json` into App Group
/// `group.com.lebonhommepharma.exergy`; ShannonUI reads it in
/// `Pill/Sources/UsageCore/ExergyPlanGlance.swift` to paint its chip. Since
/// Exergy was extracted out of ShannonUI the two sides live in different
/// repositories, so nothing compiles them together and a rename here would
/// simply make Shannon's chip go blank at runtime with every check still green.
///
/// `Fixtures/glance-contract.json` is the sample that pins the shape. The same
/// bytes exist in ShannonUI at `Pill/Tests/PillCoreTests/Fixtures/glance-contract.json`
/// (sha256 edad6c4dd04bd0c9a6b83f74ff79f6e922e3789216181db3d7564a76cf3c3644).
/// Change one and you must change the other in the same breath.
final class GlanceContractTests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/glance-contract.json")
    }

    private func fixtureData() throws -> Data { try Data(contentsOf: fixtureURL) }

    /// Byte equality both ways. `WidgetBridge.write` sets `.sortedKeys` and
    /// `.iso8601`, so its output is deterministic and this is a real lock, not
    /// a field-presence check that a type change could slip past.
    func testCanonicalGlanceRoundTripsByteForByte() throws {
        let data = try fixtureData()
        let decoded = try WidgetBridge.read(data)
        let reencoded = try WidgetBridge.write(decoded)
        XCTAssertEqual(
            String(data: reencoded, encoding: .utf8),
            String(data: data, encoding: .utf8),
            "Glance JSON shape changed. ShannonUI reads these exact keys — update "
            + "Pill/Sources/UsageCore/ExergyPlanGlance.swift and the fixture in BOTH repos."
        )
    }

    /// Every field ShannonUI actually reads, named explicitly. The round-trip
    /// above would also catch a rename, but not say which field broke.
    func testFieldsShannonReadsArePresent() throws {
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try fixtureData()) as? [String: Any]
        )
        XCTAssertNotNil(object["demo"] as? Bool, "Shannon reads demo")
        let rings = try XCTUnwrap(object["rings"] as? [[String: Any]])
        let ring = try XCTUnwrap(rings.first)
        XCTAssertNotNil(ring["usedPercent"] as? Double, "Shannon reads usedPercent")
        XCTAssertNotNil(ring["windowTag"] as? String, "Shannon reads windowTag")
        XCTAssertNotNil(ring["title"] as? String, "Shannon reads title")
        XCTAssertNotNil(ring["provider"] as? String, "Shannon reads provider")
    }

    /// The chip string itself. ShannonUI asserts this same literal against the
    /// same bytes, so if the wording or rounding moves, both sides go red.
    func testCanonicalGlanceProducesTheAgreedChip() throws {
        let payload = try WidgetBridge.read(try fixtureData())
        XCTAssertEqual(payload.combinedChip, "Week 39% left")
        XCTAssertTrue(payload.demo)
    }
}
