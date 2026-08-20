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
                showsRhythm: model.projection.snapshot?.sevenDayPulse != nil
            )
            Group {
                if requiresScrollingPage {
                    ScrollView {
                        pageContent(metrics: metrics)
                            .padding(.top, metrics.topReserve)
                            .padding(.bottom, metrics.bottomPadding)
                    }
                } else {
                    pageContent(metrics: metrics)
                        .frame(height: metrics.contentHeight, alignment: .center)
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

    private func pageContent(metrics: PulseWatchLayoutMetrics) -> some View {
        VStack(spacing: metrics.spacing) {
            if let projectDateText {
                dateHeader(projectDateText)
            }

            Button {
                Task { await model.checkIn() }
            } label: {
                PulseWatchImprintMark(state: model.displayState)
                    .frame(
                        width: metrics.todayMarkSide,
                        height: metrics.todayMarkSide
                    )
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

            Text(statusText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color("PulseWatchInk"))
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            if showsRecoveryAction {
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

            if let days = model.projection.snapshot?.sevenDayPulse {
                PulseWatchSevenDayPulse(
                    days: days,
                    displayState: model.displayState,
                    showsTodayImprint: false
                )
                .frame(height: metrics.rhythmHeight)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, metrics.horizontalPadding)
    }

    private var canCheckIn: Bool {
        if case .ready = model.displayState { return true }
        return false
    }

    private var requiresScrollingPage: Bool {
        dynamicTypeSize.isAccessibilitySize
            || (showsRecoveryAction
                && model.projection.snapshot?.sevenDayPulse != nil)
    }

    private func dateHeader(
        _ projectDateText: (weekday: String, monthDay: String)
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: projectDateText.weekday.uppercased(with: locale))
            Spacer()
            Text(verbatim: projectDateText.monthDay)
                .monospacedDigit()
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Color("PulseWatchSecondary"))
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
