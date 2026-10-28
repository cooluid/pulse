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
            let metrics = PulseWatchLayoutMetrics.resolve(containerSize: proxy.size)
            ZStack {
                PulseWatchStatusFieldBackground(
                    state: model.displayState,
                    animates: animatesWaves
                )

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
        .containerBackground(Color("PulseWatchPaper").gradient, for: .navigation)
        .background(Color("PulseWatchPaper"))
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

    /// Today's seal in the middle of the screen, what it means under it.
    private func statusFace(metrics: PulseWatchLayoutMetrics) -> some View {
        VStack(spacing: metrics.contentGap) {
            Spacer(minLength: 0)

            PulseWatchImprintMark(
                state: model.displayState,
                todayLogicalDay: model.projection.snapshot?.todayLogicalDay
            )
            .frame(width: metrics.sealSide, height: metrics.sealSide)
            .accessibilityHidden(true)

            Text(primaryTitleKey)
                .font(.system(
                    size: metrics.primaryFontSize,
                    weight: .bold,
                    design: .serif
                ))
                .foregroundStyle(titleForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .accessibilityHidden(true)

            Text(verbatim: statusText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusForeground)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(0.74)
                .fixedSize(horizontal: false, vertical: true)

            if showsRecoveryAction {
                recoveryButton
            }

            Spacer(minLength: 0)
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
                        .fill(Color("PulseWatchPaper").opacity(0.46))
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

    private var titleForeground: Color {
        switch model.displayState {
        case .ready, .submitting, .pendingSync:
            Color("PulseWatchSeal")
        case .committed, .needsSync, .failed:
            Color("PulseWatchInk")
        }
    }

    private var statusForeground: Color {
        switch model.displayState {
        case .submitting, .pendingSync:
            Color("PulseWatchSeal")
        case .failed:
            Color("PulseWatchInk")
        case .ready, .committed, .needsSync:
            Color("PulseWatchMuted")
        }
    }

    private var canCheckIn: Bool {
        if case .ready = model.displayState { return true }
        return false
    }

    private var animatesWaves: Bool {
        guard scenePhase == .active,
              model.projection.snapshot?.waveMotionEnabled == true,
              !reduceMotion,
              !isLuminanceReduced else {
            return false
        }
        switch model.displayState {
        case .ready, .submitting, .pendingSync, .committed:
            return true
        case .needsSync, .failed:
            return false
        }
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
