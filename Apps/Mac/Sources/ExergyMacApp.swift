import SwiftUI
import ExergyCore
import ExergyTheme

@main
struct ExergyMacApp: App {
    @State private var model = ExergyAppModel()
    @AppStorage("exergy.floatingHUD") private var showHUD = true

    var body: some Scene {
        MenuBarExtra {
            NavigationStack {
                PopoverRoot(model: model, showHUD: $showHUD)
            }
            .frame(width: 380, height: 560)
            .background(Color.exergyBackground)
        } label: {
            MenuBarRemainingMarks(snapshot: model.snapshot)
        }
        .menuBarExtraStyle(.window)

        Window(ExergyIdentity.displayName, id: "exergy-main") {
            NavigationSplitView {
                UsageHomeView(model: model, surface: .macWindow)
            } detail: {
                SettingsView(model: model, showsHUDToggle: true, showHUD: $showHUD)
                    .frame(minWidth: 280)
            }
            .background(Color.exergyBackground)
            .tint(Color.exergyGold)
        }

        Window(ExergyCopy.glanceTitle.resolved, id: "exergy-hud") {
            MacGlanceHUD(snapshot: model.snapshot)
                .padding(ExergySpacing.sm)
                .background(Color.exergyBackground)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
        .defaultSize(width: 440, height: 200)
    }
}

struct PopoverRoot: View {
    @Bindable var model: ExergyAppModel
    @Binding var showHUD: Bool
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            UsageHomeView(model: model, surface: .macPopover)
            Divider().overlay(Color.exergyBorder)
            HStack(spacing: ExergySpacing.sm) {
                NavigationLink {
                    AddAccountView(model: model)
                } label: {
                    ExergySymbolLabel(ExergyCopy.addAccount.resolved, symbol: .add)
                        .frame(minHeight: ExergyIconSize.hit)
                }
                .help(ExergyCopy.addAccount.resolved)
                Spacer()
                NavigationLink {
                    SettingsView(model: model, showsHUDToggle: true, showHUD: $showHUD)
                } label: {
                    ExergySymbolLabel(ExergyCopy.settings.resolved, symbol: .settings)
                        .frame(minHeight: ExergyIconSize.hit)
                }
                .help(ExergyCopy.settings.resolved)
            }
            .padding(.horizontal, ExergySpacing.md)
            .padding(.vertical, ExergySpacing.xs)
        }
        .background(Color.exergyBackground)
        .tint(Color.exergyGold)
        .onAppear(perform: syncHUD)
        .onChange(of: showHUD) { _, _ in syncHUD() }
    }

    private func syncHUD() {
        if showHUD {
            openWindow(id: "exergy-hud")
        } else {
            dismissWindow(id: "exergy-hud")
        }
    }
}
