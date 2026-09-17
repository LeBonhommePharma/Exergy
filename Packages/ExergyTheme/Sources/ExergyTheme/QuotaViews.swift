import SwiftUI
import ExergyCore

public struct FocusMeterCard: View {
    public var account: ExergyAccount
    public var usage: AccountUsage?
    public var now: Date
    public var compact: Bool

    public init(account: ExergyAccount, usage: AccountUsage?, now: Date = Date(), compact: Bool = false) {
        self.account = account
        self.usage = usage
        self.now = now
        self.compact = compact
    }

    public var body: some View {
        let window = usage?.primaryWindow
        let accent = Color.exergyBrand(account.resolvedAccentHex)
        let remaining = window?.remainingPercent
        VStack(spacing: compact ? ExergySpacing.xs : ExergySpacing.sm) {
            ExergyFocusRing(
                usedPercent: window?.usedPercent,
                expectedPercent: window.map { Metering.expectedUsedPercent(now: now, window: $0) } ?? nil,
                accent: accent,
                lineWidth: compact ? 6 : 10
            )
            .frame(height: compact ? 56 : 88)
            RemainingNumber(
                remaining: remaining,
                caption: account.displayTitle
            )
            if let pace = window.map({ Metering.pace(now: now, window: $0) }) {
                Label(pace.copy.resolved, systemImage: ExergySymbol.pace.systemName)
                    .font(ExergyType.caption)
                    .foregroundStyle(Color.exergyMute)
                    .symbolRenderingMode(.monochrome)
                    .labelStyle(.titleAndIcon)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? ExergySpacing.sm : ExergySpacing.md)
        .background(Color.exergySurface, in: RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous)
                .strokeBorder(Color.exergyBorder.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardLabel(remaining: remaining, window: window))
    }

    private func cardLabel(remaining: Double?, window: QuotaWindow?) -> String {
        let title = account.displayTitle
        guard let remaining else {
            return "\(title), \(ExergyCopy.unknown.resolved)"
        }
        let band = RemainingBand.classify(remaining).copy.resolved
        let pace = window.map { Metering.pace(now: now, window: $0).copy.resolved } ?? ""
        return "\(title), \(Int(remaining.rounded())) percent \(ExergyCopy.remaining.resolved.lowercased()), \(band), \(pace)"
    }
}

/// Bullet meter for 3+ KPIs (chart guidance: values always visible as text).
public struct QuotaBullet: View {
    public var account: ExergyAccount
    public var usage: AccountUsage?
    public var now: Date

    public init(account: ExergyAccount, usage: AccountUsage?, now: Date = Date()) {
        self.account = account
        self.usage = usage
        self.now = now
    }

    public var body: some View {
        let window = usage?.primaryWindow
        let used = window?.usedPercent
        let remaining = window?.remainingPercent
        let band = RemainingBand.classify(remaining)
        let expected = window.flatMap { Metering.expectedUsedPercent(now: now, window: $0) }
        HStack(spacing: ExergySpacing.sm) {
            Circle()
                .fill(Color.exergyBrand(account.resolvedAccentHex))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ExergySpacing.xxs) {
                Text(account.displayTitle)
                    .font(ExergyType.body)
                    .foregroundStyle(Color.exergyInk)
                    .lineLimit(1)
                Text(usage?.chipLabel ?? ExergyCopy.unknown.resolved)
                    .font(ExergyType.caption)
                    .foregroundStyle(Color.exergyMute)
                    .lineLimit(2)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.exergyBorder.opacity(0.45))
                        if let remainingTrim = ExergyRingGeometry.remainingTrim(usedPercent: used) {
                            Capsule()
                                .fill(Color.exergyRemaining(band))
                                .frame(width: geo.size.width * CGFloat(min(1, max(0, remainingTrim))))
                        }
                        if let expectedTrim = ExergyRingGeometry.remainingTrim(usedPercent: expected) {
                            Capsule()
                                .fill(Color.exergyInk)
                                .frame(width: 2, height: 10)
                                .offset(x: geo.size.width * CGFloat(min(1, max(0, expectedTrim))))
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(height: 8)
                .accessibilityHidden(true)
            }
            Spacer(minLength: ExergySpacing.sm)
            VStack(alignment: .trailing, spacing: ExergySpacing.xxs) {
                Text(remaining.map { "\(Int($0.rounded()))%" } ?? "—")
                    .font(ExergyType.mono)
                    .foregroundStyle(Color.exergyRemaining(band))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(band.copy.resolved)
                    .font(.caption2)
                    .foregroundStyle(Color.exergyMute)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, ExergySpacing.sm)
        .frame(minHeight: ExergyIconSize.hit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(bulletLabel(remaining: remaining, band: band))
    }

    private func bulletLabel(remaining: Double?, band: RemainingBand) -> String {
        guard let remaining else {
            return "\(account.displayTitle), \(ExergyCopy.unknown.resolved)"
        }
        return "\(account.displayTitle), \(Int(remaining.rounded())) percent \(ExergyCopy.remaining.resolved.lowercased()), \(band.copy.resolved)"
    }
}

public struct MacGlanceHUD: View {
    public var snapshot: ExergySnapshot

    public init(snapshot: ExergySnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        let accounts = Metering.focus(accounts: snapshot.visibleAccounts)
        HStack(spacing: ExergySpacing.sm) {
            ForEach(accounts) { account in
                FocusMeterCard(
                    account: account,
                    usage: snapshot.usage(for: account.id),
                    now: snapshot.generatedAt,
                    compact: true
                )
            }
            if accounts.isEmpty {
                Text(ExergyCopy.emptyTitle.resolved)
                    .font(ExergyType.caption)
                    .foregroundStyle(Color.exergyMute)
                    .padding(ExergySpacing.sm)
            }
        }
        .padding(ExergySpacing.sm)
        .background(Color.exergyBackground, in: RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous)
                .strokeBorder(Color.exergyBorder.opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(snapshot.glance.combinedChip ?? ExergyCopy.glanceTitle.resolved)
    }
}

public struct MenuBarRemainingMarks: View {
    public var snapshot: ExergySnapshot

    public init(snapshot: ExergySnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        let rings = snapshot.glance.rings.prefix(3)
        HStack(spacing: 3) {
            ForEach(Array(rings), id: \.accountID) { ring in
                Capsule()
                    .fill(markFill(ring.remainingPercent, accentHex: ring.accentHex))
                    .frame(width: 4, height: height(ring.remainingPercent))
                    .accessibilityHidden(true)
            }
        }
        .frame(minWidth: 12, minHeight: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.glance.combinedChip ?? ExergyIdentity.displayName)
        #if os(macOS) || os(iOS)
        .help(snapshot.glance.combinedChip ?? ExergyIdentity.tagline)
        #endif
    }

    private func markFill(_ remaining: Double?, accentHex: UInt32) -> Color {
        guard remaining != nil else { return Color.exergyMute.opacity(0.45) }
        return Color.exergyBrand(accentHex).opacity(0.95)
    }

    /// Unknown remaining is a mute stub, never a 0% gold bar.
    private func height(_ remaining: Double?) -> CGFloat {
        guard let remaining else { return 4 }
        return max(4, 14 * CGFloat(remaining / 100))
    }
}
