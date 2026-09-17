import SwiftUI
import ExergyCore
import ExergyTheme

@main
struct ExergyPadApp: App {
    @State private var model = ExergyAppModel()

    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                List {
                    NavigationLink(ExergyCopy.usage.resolved) {
                        UsageHomeView(model: model)
                    }
                    NavigationLink(ExergyCopy.addAccount.resolved) {
                        AddAccountView(model: model)
                    }
                    NavigationLink(ExergyCopy.settings.resolved) {
                        SettingsView(model: model)
                    }
                }
                .navigationTitle(ExergyIdentity.localizedName)
            } detail: {
                UsageHomeView(model: model)
            }
            .tint(Color.exergyGold)
        }
    }
}
