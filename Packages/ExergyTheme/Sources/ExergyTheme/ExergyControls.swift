import SwiftUI
import ExergyCore

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
        .buttonStyle(.plain)
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
                .foregroundStyle(Color.exergyBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ExergySpacing.compact)
                .background(
                    enabled ? Color.exergyGold : Color.exergyMute,
                    in: RoundedRectangle(cornerRadius: ExergyRadius.sm, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityLabel(title)
    }
}

public struct ExergyEmptyState: View {
    public var body: some View {
        VStack(alignment: .leading, spacing: ExergySpacing.sm) {
            Text(ExergyCopy.emptyTitle.resolved)
                .font(ExergyType.headline)
                .foregroundStyle(Color.exergyInk)
            Text(ExergyCopy.emptyBody.resolved)
                .font(ExergyType.caption)
                .foregroundStyle(Color.exergyMute)
        }
        .padding(ExergySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.exergySurface, in: RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ExergyRadius.md, style: .continuous)
                .strokeBorder(Color.exergyBorder.opacity(0.6), lineWidth: 1)
        }
    }
}
