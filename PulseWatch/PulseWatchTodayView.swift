import PulseWatchShared
import SwiftUI

struct PulseWatchTodayView: View {
    let model: PulseWatchModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { proxy in
            let metrics = PulseWatchLayoutMetrics.resolve(
                containerSize: proxy.size,
                safeAreaTop: proxy.safeAreaInsets.top,
                safeAreaBottom: proxy.safeAreaInsets.bottom,
                showsDate: projectDateText != nil,
                showsRecoveryAction: showsRecoveryAction,
                showsRhythm: model.projection.snapshot?.sevenDayPulse != nil,
                showsTransientStatus: showsTransientStatus
            )
            Group {
                if requiresScrollingPage(metrics) {
                    ScrollView {
                        stackedContent(metrics: metrics)
                            .padding(.top, metrics.topReserve)
                            .padding(.bottom, metrics.bottomPadding)
                    }
                } else {
                    faceContent(metrics: metrics)
                        .frame(height: metrics.contentHeight)
                        .padding(.top, metrics.topReserve)
                        .padding(.bottom, metrics.bottomPadding)
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
            VStack(spacing: 0) {
                if let projectDateText {
                    dateHeader(projectDateText)
                        .frame(height: metrics.dateLane, alignment: .top)
                }
                Spacer(minLength: 0)
                if showsTransientStatus {
                    statusLabel
                }
                if showsRecoveryAction {
                    recoveryButton
                }
            }

            imprintControl(metrics: metrics, showsOrbit: true)
                .padding(.top, metrics.dateLane)
                .padding(.bottom, metrics.bottomChrome)
        }
        .padding(.horizontal, metrics.horizontalPadding)
    }

    private func stackedContent(metrics: PulseWatchLayoutMetrics) -> some View {
        VStack(spacing: 8) {
            if let projectDateText {
                dateHeader(projectDateText)
            }

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
        Button {
            Task { await model.checkIn() }
        } label: {
            ZStack {
                if showsOrbit, let days = model.projection.snapshot?.sevenDayPulse {
                    PulseWatchWeekOrbit(
                        days: days,
                        radius: metrics.orbitRadius,
                        nodeSide: metrics.orbitNodeSide
                    )
                }
                PulseWatchImprintMark(state: model.displayState)
                    .frame(
                        width: metrics.todayMarkSide,
                        height: metrics.todayMarkSide
                    )
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canCheckIn)
        .accessibilityLabel(statusText)
        .accessibilityHint(
            canCheckIn
                ? PulseWatchLocalization.string("watch.action.check_in", locale: locale)
                : ""
        )
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

    private func requiresScrollingPage(_ metrics: PulseWatchLayoutMetrics) -> Bool {
        dynamicTypeSize.isAccessibilitySize || metrics.requiresScroll
    }

    private func dateHeader(
        _ projectDateText: (weekday: String, monthDay: String)
    ) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: projectDateText.weekday.uppercased(with: locale))
            Text(verbatim: projectDateText.monthDay)
                .monospacedDigit()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color("PulseWatchSecondary"))
        .frame(maxWidth: .infinity)
    }

    private var projectDateText: (weekday: String, monthDay: String)? {
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
    ) -> (weekday: String, monthDay: String) {
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = locale
        weekdayFormatter.timeZone = timeZone
        weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")
        let monthDayFormatter = DateFormatter()
        monthDayFormatter.locale = locale
        monthDayFormatter.timeZone = timeZone
        monthDayFormatter.setLocalizedDateFormatFromTemplate("MMdd")
        return (
            weekdayFormatter.string(from: date),
            monthDayFormatter.string(from: date)
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
