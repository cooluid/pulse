import PulseWatchShared
import SwiftUI

struct PulseWatchTodayView: View {
    let model: PulseWatchModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            let metrics = PulseWatchLayoutMetrics.resolve(
                containerSize: proxy.size,
                showsRecoveryAction: showsRecoveryAction,
                showsRhythm: model.projection.snapshot?.sevenDayPulse != nil,
                showsTransientStatus: showsTransientStatus
            )
            ZStack {
                PulseWatchAmbientField(
                    state: model.displayState,
                    animates: animatesAmbientField
                )

                Group {
                    if requiresScrollingPage {
                        ScrollView {
                            stackedContent(metrics: metrics)
                                .padding(.bottom, metrics.bottomPadding)
                        }
                    } else {
                        faceContent(metrics: metrics)
                            .padding(.bottom, metrics.bottomPadding)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .containerBackground(Color.black.gradient, for: .navigation)
        .background(Color.black)
        .task {
            await model.start()
        }
    }

    private func faceContent(metrics: PulseWatchLayoutMetrics) -> some View {
        ZStack {
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                imprintControl(
                    metrics: metrics,
                    showsOrbit: !showsRecoveryAction
                )
                if showsTransientStatus {
                    statusLabel
                }
                if showsRecoveryAction {
                    recoveryButton
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    private func stackedContent(metrics: PulseWatchLayoutMetrics) -> some View {
        VStack(spacing: 8) {
            imprintControl(metrics: metrics, showsOrbit: false)

            statusLabel

            if showsRecoveryAction {
                recoveryButton
            }

            if let days = model.projection.snapshot?.sevenDayPulse {
                PulseWatchSevenDayPulse(
                    days: days,
                    displayState: model.displayState,
                    showsTodayImprint: false
                )
                .frame(height: PulseWatchDesign.accessibilityRhythmHeight)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.horizontalPadding)
    }

    private func imprintControl(
        metrics: PulseWatchLayoutMetrics,
        showsOrbit: Bool
    ) -> some View {
        Group {
            if canCheckIn {
                Button {
                    Task { await model.checkIn() }
                } label: {
                    imprintFace(metrics: metrics, showsOrbit: showsOrbit)
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    PulseWatchLocalization.string(
                        "watch.action.check_in",
                        locale: locale
                    )
                )
            } else {
                imprintFace(metrics: metrics, showsOrbit: showsOrbit)
            }
        }
        .accessibilityLabel(imprintAccessibilityLabel)
    }

    private func imprintFace(
        metrics: PulseWatchLayoutMetrics,
        showsOrbit: Bool
    ) -> some View {
        ZStack {
            if let projectDateText, showsOrbit {
                Text(verbatim: projectDateText.month)
                    .font(.system(
                        size: metrics.faceSide
                            * PulseWatchDesign.heroMonthFontRatio,
                        weight: .black,
                        design: .rounded
                    ))
                    .monospacedDigit()
                    .foregroundStyle(
                        Color("PulseWatchSecondary")
                            .opacity(PulseWatchDesign.heroMonthOpacity)
                    )
                    .tracking(PulseWatchDesign.heroMonthTracking)
                    .offset(
                        x: metrics.faceSide
                            * PulseWatchDesign.heroMonthOffsetXRatio,
                        y: metrics.faceSide
                            * PulseWatchDesign.heroMonthOffsetYRatio
                    )
                    .accessibilityHidden(true)
            }
            if showsOrbit, let days = model.projection.snapshot?.sevenDayPulse {
                PulseWatchWeekOrbit(
                    days: days,
                    radius: metrics.orbitRadius,
                    nodeSide: metrics.orbitNodeSide
                )
            }
            if showsHeroDateContent {
                Circle()
                    .fill(Color.black.opacity(
                        PulseWatchDesign.heroInteriorOpacity
                    ))
                    .frame(
                        width: metrics.todayMarkSide,
                        height: metrics.todayMarkSide
                    )
            }
            PulseWatchImprintMark(state: model.displayState)
                .frame(
                    width: metrics.todayMarkSide,
                    height: metrics.todayMarkSide
                )
            if let projectDateText, showsHeroDateContent {
                VStack(spacing: PulseWatchDesign.heroDateStackSpacing) {
                    Text(verbatim: projectDateText.day)
                        .font(.system(
                            size: metrics.todayMarkSide
                                * PulseWatchDesign.heroDayFontRatio,
                            weight: .black,
                            design: .rounded
                        ))
                        .monospacedDigit()
                    Text(heroStateKey)
                        .font(.system(
                            size: metrics.todayMarkSide
                                * PulseWatchDesign.heroStateFontRatio,
                            weight: .bold,
                            design: .rounded
                        ))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(heroForegroundColor)
            }
        }
        .frame(width: metrics.faceSide, height: metrics.faceSide)
        .contentShape(Circle())
    }

    private var recoveryButton: some View {
        Button {
            Task { await model.retry() }
        } label: {
            Text("watch.action.retry")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color("PulseWatchInk"))
                .padding(
                    .horizontal,
                    PulseWatchDesign.recoveryButtonHorizontalPadding
                )
                .frame(
                    minHeight: PulseWatchDesign.recoveryButtonMinimumHeight
                )
                .background(
                    Capsule()
                        .fill(Color("PulseWatchSecondary").opacity(0.22))
                )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: true)
    }

    private var statusLabel: some View {
        Text(statusText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color("PulseWatchInk"))
            .multilineTextAlignment(.center)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var canCheckIn: Bool {
        if case .ready = model.displayState { return true }
        return false
    }

    private var showsTransientStatus: Bool {
        switch model.displayState {
        case .ready, .committed:
            false
        case .needsSync, .submitting, .pendingSync, .failed:
            true
        }
    }

    private var requiresScrollingPage: Bool { dynamicTypeSize.isAccessibilitySize }

    private var showsHeroDateContent: Bool {
        switch model.displayState {
        case .ready, .committed:
            true
        case .needsSync, .submitting, .pendingSync, .failed:
            false
        }
    }

    private var heroStateKey: LocalizedStringKey {
        switch model.displayState {
        case .committed:
            "watch.state.done"
        case .ready, .needsSync, .submitting, .pendingSync, .failed:
            "watch.action.check_in"
        }
    }

    private var heroForegroundColor: Color {
        switch model.displayState {
        case .committed:
            Color("PulseWatchCommittedForeground")
        case .ready, .needsSync, .submitting, .pendingSync, .failed:
            Color("PulseWatchInk")
        }
    }

    private var animatesAmbientField: Bool {
        guard scenePhase == .active,
              !reduceMotion,
              !isLuminanceReduced else {
            return false
        }
        switch model.displayState {
        case .ready, .committed:
            return true
        case .needsSync, .submitting, .pendingSync, .failed:
            return false
        }
    }

    private var projectDateText: (
        month: String,
        day: String,
        accessibility: String
    )? {
        guard let snapshot = model.projection.snapshot,
              let timeZone = TimeZone(identifier: snapshot.projectTimeZoneIdentifier),
              let date = logicalDayDate(snapshot.todayLogicalDay, timeZone: timeZone) else {
            return nil
        }
        return formattedDate(date, timeZone: timeZone)
    }

    private func logicalDayDate(_ value: String, timeZone: TimeZone) -> Date? {
        let components = value.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: components[0],
            month: components[1],
            day: components[2]
        ))
    }

    private func formattedDate(
        _ date: Date,
        timeZone: TimeZone
    ) -> (month: String, day: String, accessibility: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let monthNumber = calendar.component(.month, from: date)
        let dayNumber = calendar.component(.day, from: date)
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .none
        numberFormatter.usesGroupingSeparator = false
        let accessibilityFormatter = DateFormatter()
        accessibilityFormatter.locale = locale
        accessibilityFormatter.timeZone = timeZone
        accessibilityFormatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return (
            numberFormatter.string(from: NSNumber(value: monthNumber))
                ?? String(monthNumber),
            numberFormatter.string(from: NSNumber(value: dayNumber))
                ?? String(dayNumber),
            accessibilityFormatter.string(from: date)
        )
    }

    private var imprintAccessibilityLabel: String {
        guard let projectDateText else { return statusText }
        let format = PulseWatchLocalization.string(
            "watch.accessibility.date_state",
            locale: locale
        )
        return String(
            format: format,
            locale: locale,
            projectDateText.accessibility,
            statusText
        )
    }

    private var statusText: String {
        PulseWatchLocalization.status(for: model.displayState, locale: locale)
    }

    private var showsRecoveryAction: Bool {
        switch model.displayState {
        case .needsSync, .pendingSync:
            true
        case .failed(let reason):
            reason != .incompatibleProtocol
        case .ready, .submitting, .committed:
            false
        }
    }
}

struct PulseWatchStartupFailureView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.title2)
            Text("watch.state.unavailable")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("watch.action.retry", action: retry)
        }
        .padding()
    }
}
