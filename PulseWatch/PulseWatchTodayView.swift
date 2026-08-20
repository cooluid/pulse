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
                showsDateCaption: showsDateCaption,
                showsTransientStatus: showsTransientStatus
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
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .containerBackground(Color.black.gradient, for: .navigation)
        .background(Color.black)
        .task {
            await model.start()
        }
    }

    private func faceContent(metrics: PulseWatchLayoutMetrics) -> some View {
        VStack(spacing: PulseWatchDesign.dateCaptionGap) {
            Spacer(minLength: 0)
            imprintControl(metrics: metrics)
            if showsDateCaption, let projectDateCaption {
                dateCaption(projectDateCaption)
            }
            if showsTransientStatus {
                statusLabel
            }
            if showsRecoveryAction {
                recoveryButton
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, metrics.horizontalPadding)
    }

    private func stackedContent(metrics: PulseWatchLayoutMetrics) -> some View {
        VStack(spacing: 8) {
            imprintControl(metrics: metrics)

            if let projectDateCaption {
                dateCaption(projectDateCaption)
            }

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

    private func imprintControl(metrics: PulseWatchLayoutMetrics) -> some View {
        Group {
            if canCheckIn {
                Button {
                    Task { await model.checkIn() }
                } label: {
                    imprintFace(metrics: metrics)
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    PulseWatchLocalization.string(
                        "watch.action.check_in",
                        locale: locale
                    )
                )
            } else {
                imprintFace(metrics: metrics)
            }
        }
        .accessibilityLabel(imprintAccessibilityLabel)
    }

    private func imprintFace(metrics: PulseWatchLayoutMetrics) -> some View {
        PulseWatchImprintMark(state: model.displayState)
            .frame(
                width: metrics.todayMarkSide,
                height: metrics.todayMarkSide
            )
            .background {
                PulseWatchAmbientField(
                    state: model.displayState,
                    animates: animatesAmbientField
                )
                .scaleEffect(PulseWatchDesign.ambientBloomRatio)
            }
            .contentShape(Circle())
    }

    private func dateCaption(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color("PulseWatchSecondary"))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityHidden(true)
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

    private var showsDateCaption: Bool {
        guard !requiresScrollingPage, !showsRecoveryAction else { return false }
        switch model.displayState {
        case .ready, .committed:
            return projectDateCaption != nil
        case .needsSync, .submitting, .pendingSync, .failed:
            return false
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

    private var projectDateCaption: String? {
        guard let snapshot = model.projection.snapshot,
              let timeZone = TimeZone(identifier: snapshot.projectTimeZoneIdentifier),
              let date = logicalDayDate(snapshot.todayLogicalDay, timeZone: timeZone) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: date)
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

    private var imprintAccessibilityLabel: String {
        guard let projectDateCaption else { return statusText }
        let format = PulseWatchLocalization.string(
            "watch.accessibility.date_state",
            locale: locale
        )
        return String(
            format: format,
            locale: locale,
            projectDateCaption,
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
