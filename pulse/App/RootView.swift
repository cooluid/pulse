import SwiftUI

struct RootView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                ProgressView("app.loading")
                    .controlSize(.large)
            case .ready:
                TabView {
                    NavigationStack {
                        TodayView(model: model)
                    }
                    .tabItem {
                        Label("tab.today", systemImage: "checkmark.circle.fill")
                    }

                    NavigationStack {
                        HistoryView(model: model)
                    }
                    .tabItem {
                        Label("tab.history", systemImage: "calendar")
                    }
                }
                .tint(PulseDesign.brand)
            case .failed:
                ContentUnavailableView {
                    Label("load.failure.title", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("load.failure.message")
                } actions: {
                    Button("action.retry") {
                        Task { await model.start() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .background(PulseDesign.background)
        .tint(PulseDesign.brand)
        .task {
            if model.loadState == .loading {
                await model.start()
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await model.handleSceneActivation() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            Task { await model.handleSceneActivation() }
        }
        .alert(
            "error.title",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("action.ok", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
