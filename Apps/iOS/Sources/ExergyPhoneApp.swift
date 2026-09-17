import SwiftUI
import ExergyCore
import ExergyTheme

@main
struct ExergyPhoneApp: App {
    @State private var model = ExergyAppModel()

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    UsageHomeView(model: model, surface: .iPhone)
                        .navigationTitle(ExergyIdentity.localizedName)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem {
                    Label(ExergyCopy.usage.resolved, systemImage: ExergySymbol.usage.systemName)
                }
                .tag(0)

                NavigationStack {
                    AddAccountView(model: model)
                }
                .tabItem {
                    Label(ExergyCopy.addAccount.resolved, systemImage: ExergySymbol.add.systemName)
                }
                .tag(1)

                NavigationStack {
                    SettingsView(model: model)
                }
                .tabItem {
                    Label(ExergyCopy.settings.resolved, systemImage: ExergySymbol.settings.systemName)
                }
                .tag(2)
            }
            .tint(Color.exergyGold)
            .background(Color.exergyBackground.ignoresSafeArea())
        }
    }
}
