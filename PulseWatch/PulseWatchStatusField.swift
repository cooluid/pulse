import PulseWatchShared
import SwiftUI

struct PulseWatchStatusFieldBackground: View {
    let state: PulseWatchDisplayState
    let animates: Bool

    var body: some View {
        Group {
            if animates {
                TimelineView(.periodic(
                    from: .now,
                    by: PulseWatchDesign.waveFrameInterval
                )) { context in
                    field(at: context.date)
                }
            } else {
                field(at: Date(timeIntervalSinceReferenceDate: 0))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func field(at date: Date) -> some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color("PulseWatchPaper"),
                        Color("PulseWatchPaperDeep"),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                PulseWatchWaveShape(
                    baseline: waveBaselines.back,
                    amplitude: 0.075,
                    phase: phase(
                        at: date,
                        period: PulseWatchDesign.waveBackPeriod,
                        offset: 0.08
                    )
                )
                .fill(Color("PulseWatchWashBack"))

                PulseWatchWaveShape(
                    baseline: waveBaselines.middle,
                    amplitude: 0.065,
                    phase: phase(
                        at: date,
                        period: PulseWatchDesign.waveMiddlePeriod,
                        offset: 0.44
                    )
                )
                .fill(Color("PulseWatchWashMiddle"))

                PulseWatchWaveShape(
                    baseline: waveBaselines.front,
                    amplitude: 0.055,
                    phase: phase(
                        at: date,
                        period: PulseWatchDesign.waveFrontPeriod,
                        offset: 0.76
                    )
                )
                .fill(Color("PulseWatchWashFront"))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var waveBaselines: (back: CGFloat, middle: CGFloat, front: CGFloat) {
        switch state {
        case .ready:
            (0.67, 0.77, 0.86)
        case .submitting, .pendingSync:
            (0.59, 0.70, 0.81)
        case .committed:
            (0.47, 0.59, 0.71)
        case .needsSync:
            (0.72, 0.81, 0.89)
        case .failed:
            (0.69, 0.78, 0.87)
        }
    }

    private func phase(
        at date: Date,
        period: TimeInterval,
        offset: Double
    ) -> Double {
        let normalized = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period
        return normalized + offset
    }
}

private struct PulseWatchWaveShape: Shape {
    let baseline: CGFloat
    let amplitude: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        let angle = phase * 2 * Double.pi
        let verticalOffset = CGFloat(cos(angle))
            * rect.height
            * PulseWatchDesign.waveVerticalTravelRatio
        let y = rect.height * baseline + verticalOffset
        let rise = rect.height * amplitude
        let phaseOffset = CGFloat(sin(angle))
            * rect.width
            * PulseWatchDesign.waveHorizontalTravelRatio

        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: y + rise * 0.18))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.48, y: y + rise * 0.30),
            control1: CGPoint(
                x: rect.width * 0.16 + phaseOffset,
                y: y - rise * 0.78
            ),
            control2: CGPoint(
                x: rect.width * 0.34 + phaseOffset,
                y: y + rise * 0.86
            )
        )
        path.addCurve(
            to: CGPoint(x: rect.width, y: y - rise * 0.12),
            control1: CGPoint(
                x: rect.width * 0.67 + phaseOffset,
                y: y - rise * 0.54
            ),
            control2: CGPoint(
                x: rect.width * 0.84 + phaseOffset,
                y: y + rise * 0.36
            )
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}
