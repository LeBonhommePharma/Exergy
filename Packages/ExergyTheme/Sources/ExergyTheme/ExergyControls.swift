import SwiftUI
import ExergyCore

/// Pressed scale stays inside the hit box (no layout shift). 180ms, Reduce Motion off.
public struct ExergyPressStyle: ButtonStyle {
    public var pressedScale: CGFloat = 0.97

    public init(pressedScale: CGFloat = 0.97) {
        self.pressedScale = pressedScale
    }

    public func makeBody(configuration: Configuration) -> some View {
        ExergyPressStyleBody(configuration: configuration, pressedScale: pressedScale)
    }
}

private struct ExergyPressStyleBody: View {
    let configuration: ButtonStyleConfiguration
    var pressedScale: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(
                ExergyMotion.animation(reduceMotion: reduceMotion, duration: ExergyMotion.short),
                value: configuration.isPressed
            )
    }
}

/// Section label. The site calls this a kicker: uppercase, tracked, mono, muted.
///
/// Sections used to be set in `ExergyType.headline` — the same face and weight
/// as the card titles underneath them. Two levels rendered identically is not a
/// hierarchy, it is a list, and on the dense surfaces it read as one. Dropping
/// the label in size and raising its tracking separates the levels without
/// adding a rule or a box.
public struct ExergySectionHeader: View {
    public var title: String
    public var trailing: String?

    public init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ExergySpacing.sm) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.exergyMute)
            if let trailing {
                Spacer(minLength: ExergySpacing.xs)
                // Counts are data, so they stay monospaced and stay dashed when
                // unknown — same rule as every other number in the app.
                Text(trailing)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.exergyMute)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

public struct ExergyScreen<Content: View>: View {
    public var content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.exergyBackground.ignoresSafeArea())
    }
}

public struct ExergySymbolLabel: View {
    public var symbol: ExergySymbol
    public var title: String

    public init(_ title: String, symbol: ExergySymbol) {
        self.symbol = symbol
        self.title = title
    }

    public var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol.systemName)
                .symbolRenderingMode(.monochrome)
        }
        .labelStyle(.titleAndIcon)
    }
}

public struct ExergyIconHit: View {
    public var symbol: ExergySymbol
    public var title: String
    public var action: () -> Void

    public init(symbol: ExergySymbol, title: String, action: @escaping () -> Void) {
        self.symbol = symbol
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol.systemName)
                .font(.system(size: ExergyIconSize.md, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.exergyInk)
                .frame(width: ExergyIconSize.hit, height: ExergyIconSize.hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(ExergyPressStyle())
        .accessibilityLabel(title)
    }
}

public struct ExergyPrimaryButton: View {
    public var title: String
    public var enabled: Bool
    public var action: () -> Void

    public init(_ title: String, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.enabled = enabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(ExergyType.headline)
                // Enabled: ink on the accent. Disabled: muted text on a quiet
                // surface, NOT ink-on-mute dimmed to 0.55 — that stacked a
                // translucent fill under low-contrast text and pushed the label
                // under the 3:1 floor for a disabled control. A disabled button
                // should read as unavailable, not as unreadable.
                .foregroundStyle(enabled ? Color.exergyBackground : Color.exergyMute)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ExergySpacing.compact)
                .frame(minHeight: ExergyIconSize.hit)
                .background(
                    enabled ? Color.exergyAccent : Color.exergySurface,
                    in: RoundedRectangle(cornerRadius: ExergyRadius.sm, style: .continuous)
                )
                .overlay {
                    if !enabled {
                        RoundedRectangle(cornerRadius: ExergyRadius.sm, style: .continuous)
                            .strokeBorder(Color.exergyBorder.opacity(0.5), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(ExergyPressStyle())
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}

public struct ExergyEmptyState: View {
    public var showsAddHint: Bool

    public init(showsAddHint: Bool = true) {
        self.showsAddHint = showsAddHint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ExergySpacing.sm) {
            Text(ExergyCopy.emptyTitle.resolved)
                .font(ExergyType.headline)
                .foregroundStyle(Color.exergyInk)
            Text(ExergyCopy.emptyBody.resolved)
                .font(ExergyType.caption)
                .foregroundStyle(Color.exergyMute)
            if showsAddHint {
                Label(ExergyCopy.emptyAction.resolved, systemImage: ExergySymbol.add.systemName)
                    .font(ExergyType.caption.weight(.semibold))
                    .foregroundStyle(Color.exergyAccent)
                    .symbolRenderingMode(.monochrome)
                    .frame(minHeight: ExergyIconSize.hit, alignment: .leading)
            }
        }
        .padding(ExergySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.exergySurface, in: RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous)
                .strokeBorder(Color.exergyBorder.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Quiet remaining-quota placeholder. Never paints a 0% gold fill.
public struct ExergyLoadingSkeleton: View {
    public init() {}

    public var body: some View {
        HStack(spacing: ExergySpacing.sm) {
            Circle()
                .stroke(Color.exergyBorder.opacity(0.7), lineWidth: 6)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ExergySpacing.xxs) {
                Text(ExergyCopy.loading.resolved)
                    .font(ExergyType.headline)
                    .foregroundStyle(Color.exergyInk)
                Text(ExergyCopy.unknown.resolved)
                    .font(ExergyType.caption)
                    .foregroundStyle(Color.exergyMute)
            }
            Spacer(minLength: ExergySpacing.sm)
            Text("—")
                .font(ExergyType.mono)
                .foregroundStyle(Color.exergyMute)
        }
        .padding(ExergySpacing.md)
        .frame(maxWidth: .infinity, minHeight: ExergyIconSize.hit, alignment: .leading)
        .background(Color.exergySurface, in: RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous)
                .strokeBorder(Color.exergyBorder.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(ExergyCopy.loading.resolved), \(ExergyCopy.unknown.resolved)")
    }
}
