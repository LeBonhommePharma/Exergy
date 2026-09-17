import XCTest
@testable import ExergyCore

final class MeteringTests: XCTestCase {
    func testRemaining() {
        XCTAssertEqual(Metering.remainingPercent(used: 40), 60)
        XCTAssertEqual(Metering.remainingPercent(used: 0), 100)
        XCTAssertEqual(Metering.remainingPercent(used: 100), 0)
        XCTAssertNil(Metering.remainingPercent(used: .nan))
        XCTAssertNil(Metering.remainingPercent(used: .infinity))
        XCTAssertNil(Metering.remainingPercent(used: -.infinity))
        XCTAssertNil(Metering.remainingChip(tag: "Week", usedPercent: .infinity))
        XCTAssertNil(Metering.remainingChip(tag: "Week", usedPercent: .nan))
    }

    func testPaceAndRemainingBandCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for pace in PaceState.allCases {
            XCTAssertEqual(try decoder.decode(PaceState.self, from: try encoder.encode(pace)), pace)
        }
        for band in RemainingBand.allCases {
            XCTAssertEqual(
                try decoder.decode(RemainingBand.self, from: try encoder.encode(band)),
                band
            )
        }
        XCTAssertEqual(
            String(data: try encoder.encode(PaceState.ahead), encoding: .utf8),
            "\"ahead\""
        )
    }

    func testExpectedLinearPace() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 100)
        let mid = Date(timeIntervalSince1970: 50)
        XCTAssertEqual(Metering.expectedUsedPercent(now: mid, startedAt: start, resetsAt: end), 50)
        XCTAssertEqual(Metering.expectedUsedPercent(now: start, startedAt: start, resetsAt: end), 0)
        XCTAssertEqual(Metering.expectedUsedPercent(now: end, startedAt: start, resetsAt: end), 100)
        XCTAssertNil(Metering.expectedUsedPercent(now: mid, startedAt: end, resetsAt: start))
    }

    func testPaceBand() {
        XCTAssertEqual(Metering.pace(used: 50, expected: 50), .onPace)
        XCTAssertEqual(Metering.pace(used: 56, expected: 50), .ahead)
        XCTAssertEqual(Metering.pace(used: 44, expected: 50), .behind)
        XCTAssertEqual(Metering.pace(used: 50, expected: nil), .unknown)
    }

    func testWindowPaceFromMinutes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        // 5h window, 1 minute left → expected used ≈ 99.7%. 90% used is slower than linear.
        let almostDone = QuotaWindow(
            kind: .fiveHour,
            usedPercent: 90,
            resetsAt: now.addingTimeInterval(60),
            windowMinutes: 300
        )
        XCTAssertEqual(Metering.pace(now: now, window: almostDone), .behind)

        // Same 90% used one hour into a 5h window → expected 20%. Ahead of spend.
        let early = QuotaWindow(
            kind: .fiveHour,
            usedPercent: 90,
            resetsAt: now.addingTimeInterval(4 * 3600),
            windowMinutes: 300
        )
        XCTAssertEqual(Metering.pace(now: now, window: early), .ahead)
    }

    func testFocusLimitThree() {
        let accounts = (0..<5).map { i in
            ExergyAccount(
                id: UUID(),
                provider: .claude,
                label: "a\(i)",
                enabled: i != 1,
                sortIndex: i
            )
        }
        let focus = Metering.focus(accounts: accounts, limit: 3)
        XCTAssertEqual(focus.map(\.label), ["a0", "a2", "a3"])
    }

    func testNeverInventUsedPercent() {
        let w = QuotaWindow(kind: .sevenDay, label: "Max")
        XCTAssertNil(w.usedPercent)
        XCTAssertNil(w.remainingPercent)
        XCTAssertNil(w.shortLabel)
    }

    func testRemainingBandAndChip() {
        XCTAssertEqual(RemainingBand.classify(nil), .unknown)
        XCTAssertEqual(RemainingBand.classify(80), .plentiful)
        XCTAssertEqual(RemainingBand.classify(35), .watch)
        XCTAssertEqual(RemainingBand.classify(15), .low)
        XCTAssertEqual(RemainingBand.classify(.nan), .unknown)
        let chip = Metering.remainingChip(tag: "Week", usedPercent: 61)
        XCTAssertNotNil(chip)
        XCTAssertTrue(chip?.contains("39") == true)
        XCTAssertTrue(chip?.contains("Week") == true)
        XCTAssertNil(Metering.remainingChip(tag: "Week", usedPercent: .nan))
    }
}

final class PoolMergeTests: XCTestCase {
    func testMaxUsedWinsInsideSameReset() {
        let id = UUID()
        let reset = Date(timeIntervalSince1970: 2_000)
        let a = AccountUsage(
            accountID: id,
            provider: .claude,
            label: "Work",
            observedAt: Date(timeIntervalSince1970: 10),
            sourceDevice: "Mac",
            windows: [QuotaWindow(kind: .sevenDay, usedPercent: 40, resetsAt: reset)]
        )
        let b = AccountUsage(
            accountID: id,
            provider: .claude,
            label: "Work",
            observedAt: Date(timeIntervalSince1970: 20),
            sourceDevice: "iPhone",
            windows: [QuotaWindow(kind: .sevenDay, usedPercent: 55, resetsAt: reset)]
        )
        let merged = PoolMerge.merge([a, b])
        XCTAssertEqual(merged?.usedPercent, 55)
        XCTAssertEqual(merged?.sourceDevice, "iPhone")
    }

    func testDailyBurnNonNegative() {
        let id = UUID()
        let from = AccountUsage(
            accountID: id,
            provider: .codex,
            label: "Plus",
            observedAt: Date(timeIntervalSince1970: 0),
            sourceDevice: "Mac",
            windows: [QuotaWindow(kind: .sevenDay, usedPercent: 10)]
        )
        let to = AccountUsage(
            accountID: id,
            provider: .codex,
            label: "Plus",
            observedAt: Date(timeIntervalSince1970: 100),
            sourceDevice: "Mac",
            windows: [QuotaWindow(kind: .sevenDay, usedPercent: 18)]
        )
        XCTAssertEqual(DailyBurn.delta(from: from, to: to), 8)
        XCTAssertEqual(DailyBurn.delta(from: to, to: from), nil)
    }
}

final class SecretPolicyTests: XCTestCase {
    func testCloudFieldsRejectTokenKeys() {
        XCTAssertThrowsError(
            try SecretPolicy.assertNoSecrets(["accessToken": .string("x")])
        )
        XCTAssertThrowsError(
            try SecretPolicy.assertNoSecrets(["api_key": .string("x")])
        )
        XCTAssertNoThrow(
            try SecretPolicy.assertNoSecrets([CloudKeys.label: .string("Work")])
        )
    }

    func testLooksLikeOpenAIKey() {
        XCTAssertTrue(SecretPolicy.looksLikeSecret("sk-abcdefghijklmnopqrstuvwxyz"))
        XCTAssertFalse(SecretPolicy.looksLikeSecret("Work"))
    }

    func testSyncedRecordsHaveNoForbiddenKeys() throws {
        let account = DemoCatalog.accounts()[0]
        let usage = DemoCatalog.usage()[0]
        try SecretPolicy.assertNoSecrets(SyncedAccount(account: account).cloudFields)
        try SecretPolicy.assertNoSecrets(SyncedUsage(usage: usage).cloudFields)
        try SecretPolicy.assertNoSecrets(SyncedSettings().cloudFields)
        for key in SyncedAccount(account: account).cloudFields.keys {
            XCTAssertFalse(SecretPolicy.isForbidden(key), key)
        }
    }

    func testBackendRefusesSecretFields() async {
        let backend = InMemorySyncBackend()
        do {
            try await backend.save(
                recordType: "X",
                recordName: "1",
                fields: ["refreshToken": .string("nope")]
            )
            XCTFail("should refuse")
        } catch SyncError.secretInCloudFields {
            // expected
        } catch {
            XCTFail("wrong error \(error)")
        }
    }
}

final class CloudRoundtripTests: XCTestCase {
    func testAccountRoundtrip() throws {
        let original = SyncedAccount(account: DemoCatalog.accounts()[0])
        let again = try original.reencoded()
        XCTAssertEqual(original.account.id, again.account.id)
        XCTAssertEqual(original.account.provider, again.account.provider)
        XCTAssertEqual(original.account.label, again.account.label)
    }

    func testUsageRoundtripWindows() throws {
        let original = SyncedUsage(usage: DemoCatalog.usage()[0])
        let again = try original.reencoded()
        XCTAssertEqual(original.usage.windows.count, again.usage.windows.count)
        XCTAssertEqual(original.usage.usedPercent, again.usage.usedPercent)
    }

    func testSettingsRoundtrip() throws {
        let original = SyncedSettings(demoMode: false, showSpend: true)
        XCTAssertEqual(try original.reencoded(), original)
    }

    func testGlanceRingCodableWithPace() throws {
        let payload = DemoCatalog.snapshot().glance
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let again = try decoder.decode(ExergyGlancePayload.self, from: data)
        XCTAssertEqual(again.rings.count, payload.rings.count)
        XCTAssertEqual(again.rings.first?.pace, payload.rings.first?.pace)
        XCTAssertNotNil(again.combinedChip)
    }

    func testEmptyGlanceDoesNotInventRemaining() {
        let empty = ExergyGlancePayload.empty()
        XCTAssertTrue(empty.rings.isEmpty)
        XCTAssertFalse(empty.demo)
        XCTAssertNil(empty.combinedChip)
    }

    func testIntDoubleWidening() throws {
        let fields: CloudFields = [
            CloudKeys.accountID: .string(UUID().uuidString),
            CloudKeys.provider: .string("claude"),
            CloudKeys.label: .string("A"),
            CloudKeys.enabled: .int(1),
            CloudKeys.sortIndex: .double(2),
            CloudKeys.createdAt: .date(Date(timeIntervalSince1970: 1)),
            CloudKeys.authMethod: .string("oauth"),
            CloudKeys.updatedAt: .date(Date(timeIntervalSince1970: 2)),
        ]
        let synced = try SyncedAccount(cloudFields: fields)
        XCTAssertTrue(synced.account.enabled)
        XCTAssertEqual(synced.account.sortIndex, 2)
    }
}
