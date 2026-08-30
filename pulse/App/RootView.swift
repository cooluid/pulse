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
    @State private var measuredPrimaryNavigationHeight: CGFloat = 0

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
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
        .foregroundStyle(PulseDesign.appInk(for: visualTheme))
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
        .alert(
            "settings.visual_theme.access_changed.title",
            isPresented: Binding(
                get: { model.themeAccessNoticePresented },
                set: { if !$0 { model.dismissThemeAccessNotice() } }
            )
        ) {
            Button("action.ok", role: .cancel) {
                model.dismissThemeAccessNotice()
            }
        } message: {
            Text("settings.visual_theme.access_changed.message")
        }
    }

    private var primaryInterface: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                NavigationStack(path: $todayPath) {
                    TodayView(
                        model: model,
                        isActive: selectedSection == .today && todayPath.isEmpty
                    )
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            primaryNavigationReserve
                        }
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
                        isActive: selectedSection == .history && historyPath.isEmpty
                    )
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            primaryNavigationReserve
                        }
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
                primaryNavigationBar
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PulsePrimaryNavigationHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
                    .transition(.opacity)
            }
        }
        .onPreferenceChange(PulsePrimaryNavigationHeightKey.self) { height in
            guard height > 0 else { return }
            measuredPrimaryNavigationHeight = height
        }
        .background(PulseScreenBackground())
        .animation(primaryContentAnimation, value: isPrimaryNavigationVisible)
        .animation(nil, value: measuredPrimaryNavigationHeight)
    }

    private var isPrimaryNavigationVisible: Bool {
        switch selectedSection {
        case .today: todayPath.isEmpty
        case .history: historyPath.isEmpty
        }
    }

    private var primaryNavigationBar: some View {
        PulsePrimaryNavigation(
            selection: $selectedSection,
            todayDayNumber: model.today?.day,
            isTodayChecked: model.todayRecord != nil
        )
    }

    private var primaryNavigationReserve: some View {
        Color.clear
            .frame(height: primaryNavigationReserveHeight)
            .accessibilityHidden(true)
    }

    private var primaryNavigationReserveHeight: CGFloat {
        measuredPrimaryNavigationHeight > 0
            ? measuredPrimaryNavigationHeight
            : estimatedPrimaryNavigationHeight
    }

    private var estimatedPrimaryNavigationHeight: CGFloat {
        switch visualTheme {
        case .quietField:
            PulseDesign.primaryNavigationHeight + (PulseDesign.spacing8 * 2)
        case .sunlitDay:
            PulseDesign.sunlitNavigationGlyph
                + PulseDesign.spacing8
                + PulseDesign.spacing16
                + PulseDesign.spacing8
                + PulseDesign.spacing12
        case .editorialJournal:
            PulseDesign.editorialNavigationStripHeight
                + PulseDesign.spacing8
                + PulseDesign.editorialNavigationOuterVerticalPadding
        case .moonTide, .prismLedger:
            PulseDesign.ledgerNavigationHeight
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

private struct PulsePrimaryNavigationHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}
