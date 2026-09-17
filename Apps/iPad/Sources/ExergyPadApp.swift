import SwiftUI
import ExergyCore
import ExergyTheme

private enum PadRoute: String, Hashable, CaseIterable {
    case usage
    case add
    case settings

    var title: String {
        switch self {
        case .usage: return ExergyCopy.usage.resolved
        case .add: return ExergyCopy.addAccount.resolved
        case .settings: return ExergyCopy.settings.resolved
        }
    }

    var symbol: ExergySymbol {
        switch self {
        case .usage: return .usage
        case .add: return .add
        case .settings: return .settings
        }
    }
}

@main
struct ExergyPadApp: App {
    @State private var model = ExergyAppModel()
    @State private var route: PadRoute? = .usage

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                List(PadRoute.allCases, id: \.self, selection: $route) { item in
                    ExergySymbolLabel(item.title, symbol: item.symbol)
                        .frame(minHeight: ExergyIconSize.hit)
                        .tag(item)
                }
                .navigationTitle(ExergyIdentity.localizedName)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                Group {
                    switch route ?? .usage {
                    case .usage:
                        UsageHomeView(model: model, surface: .iPad)
                    case .add:
                        AddAccountView(model: model)
                    case .settings:
                        SettingsView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.exergyBackground.ignoresSafeArea())
            }
            .tint(Color.exergyGold)
        }
    }
}
