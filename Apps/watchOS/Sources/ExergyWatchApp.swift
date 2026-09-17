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

    var body: some View {
        let rings = model.snapshot.glance.rings
        VStack(spacing: 6) {
            WatchDial(rings: rings)
                .frame(width: 120, height: 120)
            if let chip = model.snapshot.glance.combinedChip {
                Text(chip)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.exergyInk)
            } else {
                Text(ExergyCopy.unknown.resolved)
                    .font(.caption2)
                    .foregroundStyle(Color.exergyMute)
            }
        }
        .padding()
        .background(Color.exergyBackground.ignoresSafeArea())
        .task { await model.bootstrapDemoIfNeeded() }
    }
}
