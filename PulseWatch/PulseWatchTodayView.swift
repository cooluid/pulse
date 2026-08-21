import PulseWatchShared
import SwiftUI

struct PulseWatchTodayView: View {
    let model: PulseWatchModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { proxy in
            let metrics = PulseWatchLayoutMetrics.resolve(containerSize: proxy.size)
            ZStack {
                PulseWatchStatusFieldBackground(state: model.displayState)

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView {
                            statusControl(metrics: metrics)
                                .frame(minHeight: proxy.size.height)
                        }
                    } else {
                        statusControl(metrics: metrics)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .containerBackground(Color("PulseWatchCanvasTop").gradient, for: .navigation)
        .background(Color("PulseWatchCanvasTop"))
        .task {
            await model.start()
        }
    }

    private func statusControl(metrics: PulseWatchLayoutMetrics) -> some View {
        Group {
            if canCheckIn {
                Button {
                    Task { await model.checkIn() }
                } label: {
                    statusFace(metrics: metrics)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(statusText)
                .accessibilityHint(
                    PulseWatchLocalization.string(
                        "watch.action.check_in",
                        locale: locale
                    )
                )
            } else {
                statusFace(metrics: metrics)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func statusFace(metrics: PulseWatchLayoutMetrics) -> some View {
        HStack(spacing: metrics.contentGap) {
            VStack(alignment: .leading, spacing: 5) {
                Text("watch.field.today")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color("PulseWatchInk").opacity(0.62))
                    .tracking(0.7)
                    .accessibilityHidden(true)

                Text(primaryTitleKey)
                    .font(.system(
                        size: metrics.primaryFontSize,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(Color("PulseWatchInk"))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .accessibilityHidden(true)

                Spacer(minLength: 4)

                Text(verbatim: statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusForeground)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .minimumScaleFactor(0.74)
                    .fixedSize(horizontal: false, vertical: true)

                if showsRecoveryAction {
                    recoveryButton
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            PulseWatchDayAxis(state: model.displayState)
                .frame(width: metrics.axisWidth)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, metrics.topPadding)
        .padding(.bottom, metrics.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .frame(minHeight: PulseWatchDesign.recoveryButtonMinimumHeight)
                .background(
                    Capsule()
                        .fill(Color("PulseWatchCanvasTop").opacity(0.46))
                )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: true)
    }

    private var primaryTitleKey: LocalizedStringKey {
        switch model.displayState {
        case .ready, .submitting, .pendingSync:
            "watch.action.check_in"
        case .committed:
            "watch.state.done"
        case .needsSync:
            "watch.field.sync"
        case .failed:
            "watch.field.unsaved"
        }
    }

    private var statusForeground: Color {
        switch model.displayState {
        case .submitting, .pendingSync:
            Color("PulseWatchPending")
        case .failed:
            Color("PulseWatchInk")
        case .ready, .committed, .needsSync:
            Color("PulseWatchInk").opacity(0.82)
        }
    }

    private var canCheckIn: Bool {
        if case .ready = model.displayState { return true }
        return false
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
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
            Text("watch.state.unavailable")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("watch.action.retry", action: retry)
        }
        .padding()
    }
}
