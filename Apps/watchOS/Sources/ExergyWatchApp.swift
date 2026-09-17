import SwiftUI
import ExergyCore
import ExergyTheme

@main
struct ExergyWatchApp: App {
    @State private var model = ExergyAppModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView(model: model)
        }
    }
}

struct WatchRootView: View {
    @Bindable var model: ExergyAppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let focus = Metering.focus(accounts: model.snapshot.visibleAccounts)
        let rings = model.snapshot.glance.rings
        NavigationStack {
            ScrollView {
                VStack(spacing: ExergySpacing.sm) {
                    WatchDial(rings: rings)
                        .frame(width: 96, height: 96)
                        .padding(.top, ExergySpacing.xs)
                    if let remaining = primaryRemaining(focus) {
                        Text("\(Int(remaining.rounded()))%")
                            .font(.system(.title, design: .default).weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.exergyRemaining(RemainingBand.classify(remaining)))
                            .minimumScaleFactor(0.7)
                        Text(ExergyCopy.remaining.resolved)
                            .font(.caption2)
                            .foregroundStyle(Color.exergyMute)
                        Text(RemainingBand.classify(remaining).copy.resolved)
                            .font(.caption2)
                            .foregroundStyle(Color.exergyInk)
                    } else {
                        Text("—")
                            .font(.system(.title, design: .default).weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.exergyMute)
                            .minimumScaleFactor(0.7)
                        Text(ExergyCopy.unknown.resolved)
                            .font(.caption2)
                            .foregroundStyle(Color.exergyMute)
                    }
                    if focus.isEmpty {
                        ExergyEmptyState(showsAddHint: false)
                    } else {
                        ForEach(focus) { account in
                            WatchAccountRow(
                                account: account,
                                usage: model.snapshot.usage(for: account.id)
                            )
                        }
                    }
                }
                .padding(.horizontal, ExergySpacing.sm)
            }
            .background(Color.exergyBackground.ignoresSafeArea())
            .navigationTitle(ExergyIdentity.localizedName)
            .task { await model.bootstrapDemoIfNeeded() }
        }
        .animation(ExergyMotion.animation(reduceMotion: reduceMotion), value: rings.count)
    }

    private func primaryRemaining(_ accounts: [ExergyAccount]) -> Double? {
        accounts.compactMap { model.snapshot.usage(for: $0.id)?.remainingPercent }.first
    }
}

struct WatchAccountRow: View {
    var account: ExergyAccount
    var usage: AccountUsage?

    var body: some View {
        let remaining = usage?.remainingPercent
        let band = RemainingBand.classify(remaining)
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(account.displayTitle)
                    .font(.caption2)
                    .foregroundStyle(Color.exergyInk)
                    .lineLimit(1)
                Text(band.copy.resolved)
                    .font(.caption2)
                    .foregroundStyle(Color.exergyMute)
            }
            Spacer()
            Text(remaining.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.exergyRemaining(band))
        }
        .padding(.vertical, ExergySpacing.xs)
        .frame(minHeight: ExergyIconSize.hit)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.displayTitle), \(remaining.map { "\(Int($0.rounded())) percent \(ExergyCopy.remaining.resolved.lowercased())" } ?? ExergyCopy.unknown.resolved), \(band.copy.resolved)")
    }
}
