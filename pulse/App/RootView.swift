import SwiftUI
import PulseCore

struct RootView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.pulseVisualTheme) private var visualTheme
    @State private var selectedSection: PulsePrimarySection = .today
    @State private var todayPath: [PulseNavigationDestination] = []
    @State private var historyPath: [PulseNavigationDestination] = []

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                ProgressView("app.loading")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PulseScreenBackground())
            case .ready:
                if model.habit?.isIdentityConfirmed == true {
                    primaryInterface
                } else {
                    NavigationStack {
                        CommitmentIdentityEditor(model: model, mode: .onboarding)
                    }
                    .id(model.habit?.id)
                }
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
                    .tint(PulseDesign.action)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PulseScreenBackground())
            }
        }
        .foregroundStyle(PulseDesign.ink)
        .tint(PulseDesign.appAccent(for: visualTheme))
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
        .onOpenURL { url in
            guard url.scheme == PulseRuntimeIdentity.urlScheme,
                  url.host == "today" else { return }
            selectedSection = .today
            todayPath.removeAll()
        }
        .onChange(of: model.navigationResetToken) { _, _ in
            selectedSection = .today
            todayPath.removeAll()
            historyPath.removeAll()
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

    private var primaryInterface: some View {
        VStack(spacing: 0) {
            ZStack {
                NavigationStack(path: $todayPath) {
                    TodayView(
                        model: model,
                        isActive: selectedSection == .today && todayPath.isEmpty
                    )
                        .accessibilityHidden(!todayPath.isEmpty)
                        .navigationDestination(for: PulseNavigationDestination.self) { destination in
                            secondaryDestination(destination)
                        }
                }
                .opacity(selectedSection == .today ? 1 : 0)
                .offset(
                    x: reduceMotion || selectedSection == .today
                        ? 0
                        : -PulseDesign.primaryContentTransitionOffset
                )
                .allowsHitTesting(selectedSection == .today)
                .accessibilityHidden(selectedSection != .today)
                .zIndex(selectedSection == .today ? 1 : 0)
                .animation(primaryContentAnimation, value: selectedSection)

                NavigationStack(path: $historyPath) {
                    HistoryView(model: model)
                        .accessibilityHidden(!historyPath.isEmpty)
                        .navigationDestination(for: PulseNavigationDestination.self) { destination in
                            secondaryDestination(destination)
                        }
                }
                .opacity(selectedSection == .history ? 1 : 0)
                .offset(
                    x: reduceMotion || selectedSection == .history
                        ? 0
                        : PulseDesign.primaryContentTransitionOffset
                )
                .allowsHitTesting(selectedSection == .history)
                .accessibilityHidden(selectedSection != .history)
                .zIndex(selectedSection == .history ? 1 : 0)
                .animation(primaryContentAnimation, value: selectedSection)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isPrimaryNavigationVisible {
                PulsePrimaryNavigation(
                    selection: $selectedSection,
                    todayDayNumber: model.today?.day,
                    isTodayChecked: model.todayRecord != nil
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(PulseScreenBackground())
        .animation(primaryContentAnimation, value: isPrimaryNavigationVisible)
    }

    private var isPrimaryNavigationVisible: Bool {
        switch selectedSection {
        case .today: todayPath.isEmpty
        case .history: historyPath.isEmpty
        }
    }

    @ViewBuilder
    private func secondaryDestination(_ destination: PulseNavigationDestination) -> some View {
        switch destination {
        case .settings:
            SettingsView(model: model)
                .id(model.settings.language)
        }
    }

    private var primaryContentAnimation: Animation? {
        reduceMotion
            ? nil
            : .easeInOut(duration: PulseDesign.primaryContentTransitionDuration)
    }
}

enum PulseNavigationDestination: Hashable {
    case settings
}
