import SwiftUI

struct RootView: View {
    @Bindable var model: PulseAppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSection: PulsePrimarySection = .today

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                ProgressView("app.loading")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PulseScreenBackground())
            case .ready:
                primaryInterface
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
        ZStack {
            NavigationStack {
                TodayView(model: model, isActive: selectedSection == .today)
            }
            .opacity(selectedSection == .today ? 1 : 0)
            .allowsHitTesting(selectedSection == .today)
            .accessibilityHidden(selectedSection != .today)
            .zIndex(selectedSection == .today ? 1 : 0)

            NavigationStack {
                HistoryView(model: model, isActive: selectedSection == .history)
            }
            .opacity(selectedSection == .history ? 1 : 0)
            .allowsHitTesting(selectedSection == .history)
            .accessibilityHidden(selectedSection != .history)
            .zIndex(selectedSection == .history ? 1 : 0)
        }
        .background(PulseScreenBackground())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PulsePrimaryNavigation(
                selection: $selectedSection,
                todayDayNumber: model.today?.day,
                historyMonthDayCount: historyMonthDayCount,
                isTodayChecked: model.todayRecord != nil
            )
        }
    }

    private var historyMonthDayCount: Int? {
        guard let today = model.today, let timeZone = model.timeZone else { return nil }
        return PulseFormatting.numberOfDaysInMonth(today, timeZone: timeZone)
    }
}
