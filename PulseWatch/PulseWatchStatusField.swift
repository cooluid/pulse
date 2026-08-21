import PulseWatchShared
import SwiftUI

struct PulseWatchStatusFieldBackground: View {
    let state: PulseWatchDisplayState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color("PulseWatchCanvasTop"),
                        Color("PulseWatchCanvasBottom"),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                PulseWatchWaveShape(
                    baseline: waveBaselines.back,
                    amplitude: 0.075,
                    phase: 0.08
                )
                .fill(Color("PulseWatchWaveBack"))

                PulseWatchWaveShape(
                    baseline: waveBaselines.middle,
                    amplitude: 0.065,
                    phase: 0.44
                )
                .fill(Color("PulseWatchWaveMiddle"))

                PulseWatchWaveShape(
                    baseline: waveBaselines.front,
                    amplitude: 0.055,
                    phase: 0.76
                )
                .fill(Color("PulseWatchWaveFront"))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
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
}

struct PulseWatchDayAxis: View {
    let state: PulseWatchDisplayState

    var body: some View {
        GeometryReader { proxy in
            let top = proxy.size.height * 0.08
            let bottom = proxy.size.height * 0.92
            let x = proxy.size.width / 2
            let y = top + (bottom - top) * nodePosition

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: x, y: top))
                    path.addLine(to: CGPoint(x: x, y: bottom))
                }
                .stroke(
                    axisColor.opacity(0.86),
                    style: StrokeStyle(
                        lineWidth: PulseWatchDesign.statusAxisLineWidth,
                        lineCap: .round
                    )
                )

                Circle()
                    .fill(Color("PulseWatchInk"))
                    .frame(
                        width: PulseWatchDesign.statusAxisNodeSide,
                        height: PulseWatchDesign.statusAxisNodeSide
                    )
                    .overlay {
                        Circle()
                            .stroke(
                                axisColor,
                                lineWidth: PulseWatchDesign.statusAxisNodeStrokeWidth
                            )
                    }
                    .shadow(
                        color: axisColor.opacity(0.55),
                        radius: PulseWatchDesign.statusAxisNodeShadowRadius
                    )
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var nodePosition: CGFloat {
        switch state {
        case .needsSync:
            0.16
        case .ready:
            0.28
        case .submitting, .pendingSync, .failed:
            0.48
        case .committed:
            0.74
        }
    }

    private var axisColor: Color {
        switch state {
        case .submitting, .pendingSync:
            Color("PulseWatchPending")
        case .failed:
            Color("PulseWatchSecondary")
        case .ready, .committed, .needsSync:
            Color("PulseWatchAxis")
        }
    }
}

private struct PulseWatchWaveShape: Shape {
    let baseline: CGFloat
    let amplitude: CGFloat
    let phase: CGFloat

    func path(in rect: CGRect) -> Path {
        let y = rect.height * baseline
        let rise = rect.height * amplitude
        let phaseOffset = (phase - 0.5) * rect.width * 0.12

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
