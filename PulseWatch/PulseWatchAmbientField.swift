import PulseWatchShared
import SwiftUI

struct PulseWatchAmbientField: View {
    let state: PulseWatchDisplayState
    let animates: Bool

    var body: some View {
        Group {
            if showsField {
                if animates {
                    TimelineView(.periodic(
                        from: .now,
                        by: PulseWatchDesign.ambientFrameInterval
                    )) { context in
                        field(at: context.date)
                    }
                } else {
                    field(at: .init(timeIntervalSinceReferenceDate: 0))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func field(at date: Date) -> some View {
        GeometryReader { proxy in
            let time = date.timeIntervalSinceReferenceDate
            let primaryPhase = phase(
                time: time,
                period: PulseWatchDesign.ambientPrimaryPeriod
            )
            let secondaryPhase = phase(
                time: time,
                period: PulseWatchDesign.ambientSecondaryPeriod
            )
            ZStack {
                ambientEllipse(
                    color: primaryColor,
                    opacity: primaryOpacity,
                    size: CGSize(
                        width: proxy.size.width
                            * PulseWatchDesign.ambientPrimaryWidthRatio,
                        height: proxy.size.height
                            * PulseWatchDesign.ambientPrimaryHeightRatio
                    )
                )
                .scaleEffect(
                    1 + sin(primaryPhase)
                        * PulseWatchDesign.ambientPrimaryScaleAmplitude
                )
                .rotationEffect(.degrees(
                    sin(primaryPhase)
                        * PulseWatchDesign.ambientRotationAmplitude
                ))
                .position(
                    x: proxy.size.width
                        * PulseWatchDesign.ambientPrimaryCenterXRatio
                        + sin(primaryPhase)
                            * PulseWatchDesign.ambientPrimaryMotionX,
                    y: proxy.size.height
                        * PulseWatchDesign.ambientPrimaryCenterYRatio
                        + cos(primaryPhase)
                            * PulseWatchDesign.ambientPrimaryMotionY
                )

                ambientEllipse(
                    color: secondaryColor,
                    opacity: secondaryOpacity,
                    size: CGSize(
                        width: proxy.size.width
                            * PulseWatchDesign.ambientSecondaryWidthRatio,
                        height: proxy.size.height
                            * PulseWatchDesign.ambientSecondaryHeightRatio
                    )
                )
                .scaleEffect(
                    1 + cos(secondaryPhase)
                        * PulseWatchDesign.ambientSecondaryScaleAmplitude
                )
                .rotationEffect(.degrees(
                    -cos(secondaryPhase)
                        * PulseWatchDesign.ambientRotationAmplitude
                ))
                .position(
                    x: proxy.size.width
                        * PulseWatchDesign.ambientSecondaryCenterXRatio
                        + cos(secondaryPhase)
                            * PulseWatchDesign.ambientSecondaryMotionX,
                    y: proxy.size.height
                        * PulseWatchDesign.ambientSecondaryCenterYRatio
                        + sin(secondaryPhase)
                            * PulseWatchDesign.ambientSecondaryMotionY
                )
            }
        }
    }

    private func ambientEllipse(
        color: Color,
        opacity: Double,
        size: CGSize
    ) -> some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [
                    color.opacity(opacity),
                    color.opacity(
                        opacity
                            * PulseWatchDesign.ambientGradientMidpointOpacityRatio
                    ),
                    .clear,
                ],
                center: .center,
                startRadius: max(size.width, size.height)
                    * PulseWatchDesign.ambientGradientStartRadiusRatio
                    / 2,
                endRadius: max(size.width, size.height) / 2
            ))
            .frame(width: size.width, height: size.height)
    }

    private var showsField: Bool {
        switch state {
        case .ready, .committed:
            true
        case .needsSync, .submitting, .pendingSync, .failed:
            false
        }
    }

    private var primaryColor: Color {
        switch state {
        case .committed:
            Color("PulseWatchCommitted")
        case .ready, .needsSync, .submitting, .pendingSync, .failed:
            Color("PulseWatchField")
        }
    }

    private var secondaryColor: Color {
        primaryColor
    }

    private var primaryOpacity: Double {
        switch state {
        case .committed:
            PulseWatchDesign.ambientCommittedPrimaryOpacity
        case .ready, .needsSync, .submitting, .pendingSync, .failed:
            PulseWatchDesign.ambientReadyPrimaryOpacity
        }
    }

    private var secondaryOpacity: Double {
        switch state {
        case .committed:
            PulseWatchDesign.ambientCommittedSecondaryOpacity
        case .ready, .needsSync, .submitting, .pendingSync, .failed:
            PulseWatchDesign.ambientReadySecondaryOpacity
        }
    }

    private func phase(time: TimeInterval, period: TimeInterval) -> Double {
        (time.truncatingRemainder(dividingBy: period) / period) * 2 * .pi
    }
}
