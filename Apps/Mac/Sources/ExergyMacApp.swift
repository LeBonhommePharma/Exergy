import SwiftUI
import ExergyCore
import ExergyTheme

@main
struct ExergyMacApp: App {
    @State private var model = ExergyAppModel()

    var body: some Scene {
        MenuBarExtra {
            NavigationStack {
                PopoverRoot(model: model)
            }
            .frame(width: 360, height: 520)
        } label: {
            MenuBarLabel(snapshot: model.snapshot)
        }
        .menuBarExtraStyle(.window)

        Window("Exergy", id: "exergy-main") {
            NavigationSplitView {
                UsageHomeView(model: model)
            } detail: {
                SettingsView(model: model)
                    .frame(minWidth: 280)
            }
        }
    }
}

struct MenuBarLabel: View {
    var snapshot: ExergySnapshot

    var body: some View {
        let rings = snapshot.glance.rings.prefix(3)
        HStack(spacing: 3) {
            ForEach(Array(rings), id: \.accountID) { ring in
                Capsule()
                    .fill(Color.exergyBrand(ring.accentHex).opacity(0.9))
                    .frame(width: 4, height: menuHeight(ring.remainingPercent))
            }
        }
        .accessibilityLabel(snapshot.glance.combinedChip ?? ExergyIdentity.displayName)
    }

    private func menuHeight(_ remaining: Double?) -> CGFloat {
        let pct = remaining ?? 0
        return max(4, 14 * CGFloat(pct / 100))
    }
}

struct PopoverRoot: View {
    @Bindable var model: ExergyAppModel

    var body: some View {
        VStack(spacing: 0) {
            UsageHomeView(model: model)
            Divider()
            HStack {
                NavigationLink(ExergyCopy.addAccount.resolved) {
                    AddAccountView(model: model)
                }
                Spacer()
                NavigationLink(ExergyCopy.settings.resolved) {
                    SettingsView(model: model)
                }
            }
            .padding(ExergySpacing.md)
        }
        .background(Color.exergyBackground)
    }
}
