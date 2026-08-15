import PulseCore
import SwiftUI

struct WidgetStyleGalleryView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var showsStore = false

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                    galleryIntroduction

                    if let snapshot = model.widgetPresentationSnapshot {
                        LazyVGrid(columns: columns, spacing: PulseDesign.spacing20) {
                            ForEach(PulseWidgetStyle.allCases) { style in
                                PulseWidgetStyleCard(
                                    style: style,
                                    snapshot: snapshot,
                                    isLocked: PulseWidgetStyleAccessPolicy
                                        .requiresEnhancement(style)
                                        && !model.featureAccess.hasEnhancement,
                                    onOpenStore: { showsStore = true }
                                )
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "widget.gallery.unavailable.title",
                            systemImage: "exclamationmark.circle",
                            description: Text("widget.gallery.unavailable.message")
                        )
                    }
                }
                .frame(maxWidth: PulseDesign.historyMaxWidth, alignment: .leading)
                .padding(PulseDesign.horizontalPadding)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("widget.gallery.navigation_title")
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .navigationDestination(isPresented: $showsStore) {
            EnhancementStoreView(model: model)
        }
    }

    private var galleryIntroduction: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            Text("widget.gallery.introduction.title")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseDesign.ink)
            Text("widget.gallery.introduction.message")
                .font(.footnote)
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label("widget.gallery.preview.notice", systemImage: "play.circle")
                .font(.caption)
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, PulseDesign.spacing4)
    }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: PulseDesign.spacing20), count: count)
    }

}

private struct PulseWidgetStyleCard: View {
    let style: PulseWidgetStyle
    let snapshot: PulseWidgetSnapshot
    let isLocked: Bool
    let onOpenStore: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var previewState = PreviewState.idle
    @State private var previewSnapshot: PulseWidgetSnapshot?
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            GeometryReader { proxy in
                let gap = PulseDesign.spacing8
                let previewHeight = max(
                    1,
                    (proxy.size.width - gap) / (1 + PulseDesign.widgetMediumAspectRatio)
                )

                HStack(spacing: gap) {
                    PulseWidgetStylePreview(
                        style: style,
                        snapshot: presentedSnapshot,
                        usesMediumMetrics: false
                    )
                    .frame(width: previewHeight, height: previewHeight)

                    PulseWidgetStylePreview(
                        style: style,
                        snapshot: presentedSnapshot,
                        usesMediumMetrics: true
                    )
                    .frame(
                        width: previewHeight * PulseDesign.widgetMediumAspectRatio,
                        height: previewHeight
                    )
                }
            }
            .aspectRatio(PulseDesign.widgetPreviewPairAspectRatio, contentMode: .fit)

            HStack(alignment: .firstTextBaseline) {
                Text(style.localizedName(locale: locale))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PulseDesign.ink)
                Spacer()
                previewControl
                if isLocked {
                    lockedBadge
                }
            }

            Text(verbatim: style.localizedDescription(locale: locale))
                .font(.footnote)
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PulseDesign.spacing12)
        .background {
            RoundedRectangle(
                cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.surface.opacity(0.90))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
                style: .continuous
            )
            .stroke(
                isLocked
                    ? PulseDesign.field.opacity(0.32)
                    : PulseDesign.separator.opacity(0.72),
                lineWidth: PulseDesign.thinLineWidth
            )
        }
        .shadow(color: PulseDesign.shadow.opacity(0.05), radius: 12, y: 5)
        .contentShape(RoundedRectangle(
            cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
            style: .continuous
        ))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("widget.gallery.style.\(style.rawValue)")
        .onChange(of: snapshot.isCheckedToday) { _, _ in
            cancelPreviewAndRestoreFact()
        }
        .onDisappear {
            previewTask?.cancel()
            previewTask = nil
        }
    }

    private var previewControl: some View {
        Button(action: replayPreview) {
            Image(systemName: previewButtonSystemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseDesign.action)
                .frame(
                    width: PulseDesign.spacing32,
                    height: PulseDesign.spacing32
                )
                .background(PulseDesign.background.opacity(0.86), in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            PulseDesign.separator.opacity(0.76),
                            lineWidth: PulseDesign.thinLineWidth
                        )
                }
                .frame(
                    width: PulseDesign.minimumHitTarget,
                    height: PulseDesign.minimumHitTarget
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isPreviewRunning)
        .accessibilityLabel(previewButtonTitle)
        .accessibilityHint("widget.gallery.preview.hint")
        .accessibilityIdentifier("widget.gallery.preview.\(style.rawValue)")
    }

    private var presentedSnapshot: PulseWidgetSnapshot {
        previewSnapshot ?? snapshot
    }

    private var isPreviewRunning: Bool {
        previewState == .playing
    }

    private var previewButtonTitle: LocalizedStringKey {
        switch previewState {
        case .idle:
            return "widget.gallery.preview.play"
        case .playing:
            return "widget.gallery.preview.playing"
        case .completed:
            return "widget.gallery.preview.replay"
        }
    }

    private var previewButtonSystemImage: String {
        switch previewState {
        case .idle:
            return "play.fill"
        case .playing:
            return "hourglass"
        case .completed:
            return "arrow.counterclockwise"
        }
    }

    @MainActor
    private func replayPreview() {
        previewTask?.cancel()
        let pendingSnapshot = snapshot.projectingTodayCheckInForGallery(false)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            previewState = .playing
            previewSnapshot = reduceMotion
                ? pendingSnapshot
                : pendingSnapshot.projectingGallery(period: .morning, isChecked: false)
        }

        previewTask = Task { @MainActor in
            do {
                if reduceMotion {
                    try await Task.sleep(
                        for: PulseWidgetMotionPresentation.reducedMotionPendingStateHold
                    )
                    try Task.checkCancellation()
                    previewSnapshot = pendingSnapshot.projectingTodayCheckInForGallery(true)
                    try await Task.sleep(
                        for: PulseWidgetMotionPresentation.reducedMotionCompletionStateHold
                    )
                } else {
                    try await Task.sleep(
                        for: PulseWidgetMotionPresentation.galleryInitialStateHold
                    )
                    try Task.checkCancellation()
                    previewSnapshot = pendingSnapshot.projectingGallery(
                        period: .daylight,
                        isChecked: false
                    )
                    try await Task.sleep(
                        for: PulseWidgetMotionPresentation.galleryAmbientStateHold
                    )
                    try Task.checkCancellation()
                    previewSnapshot = pendingSnapshot.projectingGallery(
                        period: .evening,
                        isChecked: false
                    )
                    try await Task.sleep(
                        for: PulseWidgetMotionPresentation.galleryAmbientStateHold
                    )
                    try Task.checkCancellation()
                    previewSnapshot = pendingSnapshot.projectingGallery(
                        period: .evening,
                        isChecked: true
                    )
                    try await Task.sleep(
                        for: PulseWidgetMotionPresentation.galleryCompletionStateHold
                    )
                }
                try Task.checkCancellation()
                previewState = .completed
                previewTask = nil
            } catch {
                return
            }
        }
    }

    @MainActor
    private func cancelPreviewAndRestoreFact() {
        previewTask?.cancel()
        previewTask = nil
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            previewState = .idle
            previewSnapshot = nil
        }
    }

    private var lockedBadge: some View {
        Button(action: onOpenStore) {
            Label("widget.gallery.locked", systemImage: "lock.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(PulseDesign.action)
                .padding(.horizontal, PulseDesign.spacing8)
                .padding(.vertical, PulseDesign.spacing4)
                .background(PulseDesign.field.opacity(0.12), in: Capsule())
                .frame(minHeight: PulseDesign.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("widget.gallery.enhancement.hint")
        .accessibilityIdentifier("widget.gallery.enhancement.\(style.rawValue)")
    }

    private enum PreviewState {
        case idle
        case playing
        case completed
    }
}

extension PulseWidgetSnapshot {
    func projectingGallery(
        period: PulseWidgetAmbientPeriod,
        isChecked: Bool
    ) -> PulseWidgetSnapshot {
        let projected = projectingTodayCheckInForGallery(isChecked)
        let calendar = Calendar.pulseGregorian(timeZone: projectTimeZone)
        let dayStart = today.startDate(timeZone: projectTimeZone)
        let hour: Int
        switch period {
        case .morning:
            hour = PulseWidgetAmbientPeriod.morningStartHour + 2
        case .daylight:
            hour = PulseWidgetAmbientPeriod.daylightStartHour + 2
        case .evening:
            hour = PulseWidgetAmbientPeriod.eveningStartHour + 2
        }
        guard let projectedDate = calendar.date(byAdding: .hour, value: hour, to: dayStart) else {
            preconditionFailure("Gallery ambient projection requires a valid project calendar date.")
        }

        return PulseWidgetSnapshot(
            habitID: projected.habitID,
            habitName: projected.habitName,
            today: projected.today,
            checkedAt: projected.checkedAt,
            recentDays: projected.recentDays,
            generatedAt: projectedDate,
            nextDayBoundary: projected.nextDayBoundary,
            projectTimeZoneIdentifier: projected.projectTimeZoneIdentifier
        )
    }

    func projectingTodayCheckInForGallery(_ isChecked: Bool) -> PulseWidgetSnapshot {
        let projectedRecentDays = recentDays.map { daySnapshot in
            guard daySnapshot.day == today else { return daySnapshot }
            return PulseWidgetDaySnapshot(
                day: daySnapshot.day,
                state: isChecked ? .checked : .todayPending
            )
        }

        return PulseWidgetSnapshot(
            habitID: habitID,
            habitName: habitName,
            today: today,
            checkedAt: isChecked ? (checkedAt ?? generatedAt) : nil,
            recentDays: projectedRecentDays,
            generatedAt: generatedAt,
            nextDayBoundary: nextDayBoundary,
            projectTimeZoneIdentifier: projectTimeZoneIdentifier
        )
    }
}

struct PulseWidgetStylePreview: View {
    let style: PulseWidgetStyle
    let snapshot: PulseWidgetSnapshot
    let usesMediumMetrics: Bool

    init(
        style: PulseWidgetStyle,
        snapshot: PulseWidgetSnapshot,
        usesMediumMetrics: Bool = true
    ) {
        self.style = style
        self.snapshot = snapshot
        self.usesMediumMetrics = usesMediumMetrics
    }

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PulseWidgetHomeRenderer(
            snapshot: snapshot,
            style: style,
            usesMediumMetrics: usesMediumMetrics,
            usesFullColorPalette: true,
            allowsMotion: !reduceMotion,
            statusText: PulseLocalization.string(
                snapshot.isCheckedToday
                    ? "today.navigation.checked"
                    : "today.navigation.pending",
                locale: locale
            ),
            pathSummaryFormat: PulseLocalization.string(
                "widget.path.summary.format",
                locale: locale
            ),
            emptyPlaceText: PulseLocalization.string(
                "widget.place.empty",
                locale: locale
            ),
            placeStatusText: PulseLocalization.string(
                snapshot.isCheckedToday
                    ? "widget.place.checked"
                    : "widget.place.pending",
                locale: locale
            )
        )
        .clipShape(RoundedRectangle(
            cornerRadius: PulseDesign.widgetPreviewCornerRadius,
            style: .continuous
        ))
        .accessibilityHidden(true)
    }
}
