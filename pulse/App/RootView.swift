import SwiftUI
import PulseCore

struct RootView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSection: PulsePrimarySection = .today
    @State private var todayPath: [PulseNavigationDestination] = []
    @State private var historyPath: [PulseNavigationDestination] = []
    @State private var primaryNavigationHeight: CGFloat = 0

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
        .tint(PulseDesign.tint)
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
            guard url.scheme == "pulse", url.host == "today" else { return }
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
        ZStack(alignment: .bottom) {
            NavigationStack(path: $todayPath) {
                TodayView(
                    model: model,
                    isActive: selectedSection == .today && todayPath.isEmpty,
                    primaryNavigationClearance: primaryNavigationHeight
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
                HistoryView(
                    model: model,
                    primaryNavigationClearance: primaryNavigationHeight
                )
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

            if isPrimaryNavigationVisible {
                PulsePrimaryNavigation(
                    selection: $selectedSection,
                    todayDayNumber: model.today?.day,
                    historyMonthNumber: model.today?.month,
                    isTodayChecked: model.todayRecord != nil
                )
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    primaryNavigationHeight = newHeight
                }
                .zIndex(2)
            }
        }
        .background(PulseScreenBackground())
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
