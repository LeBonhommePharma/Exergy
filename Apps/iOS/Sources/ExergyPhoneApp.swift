import SwiftUI
import ExergyCore
import ExergyTheme

@main
struct ExergyPhoneApp: App {
    @State private var model = ExergyAppModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                UsageHomeView(model: model)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            NavigationLink(ExergyCopy.settings.resolved) {
                                SettingsView(model: model)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(ExergyCopy.addAccount.resolved) {
                                AddAccountView(model: model)
                            }
                        }
                    }
                    .navigationTitle(ExergyIdentity.localizedName)
            }
            .tint(Color.exergyGold)
        }
    }
}
