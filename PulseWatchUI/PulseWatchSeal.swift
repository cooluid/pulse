import SwiftUI

/// The watch targets cannot link the phone's seal artwork, so the watch keeps its own small copy of
/// the same drawing: an inked face with the date carved out, or a dashed place before the day is kept.
enum PulseWatchSealRandom {
    static func seed(for text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return hash
    }

    static func unit(_ state: inout UInt64) -> Double {
        state &+= 0x9e37_79b9_7f4a_7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
        value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
        value ^= value >> 31
        return Double(value >> 11) / Double(UInt64(1) << 53)
    }
}

enum PulseWatchDayNumber {
    /// Logical days travel as `yyyy-MM-dd`; the seal only needs the day of the month.
    static func from(_ logicalDay: String?) -> Int? {
        guard let logicalDay, let value = Int(logicalDay.suffix(2)), (1...31).contains(value) else {
            return nil
        }
        return value
    }
}

struct PulseWatchSealImpression: View {
    let text: String
    let ink: Color
    let seed: UInt64
    var texture: Double = 1

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let face = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
            context.drawLayer { layer in
                layer.fill(
                    Path(roundedRect: face, cornerRadius: side * PulseWatchDesign.sealCornerFraction, style: .continuous),
                    with: .color(ink)
                )
                layer.blendMode = .destinationOut
                let glyph = layer.resolve(
                    Text(verbatim: text)
                        .font(.system(size: side * (text.count > 1 ? 0.5 : 0.6), weight: .black, design: .serif))
                        .foregroundStyle(.black)
                )
                layer.draw(glyph, at: CGPoint(x: face.midX, y: face.midY), anchor: .center)
                Self.erode(face: face, seed: seed, texture: texture, context: &layer)
            }
        }
        .rotationEffect(.degrees((Self.tiltUnit(seed) * 2 - 1) * 4))
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private static func tiltUnit(_ seed: UInt64) -> Double {
        var state = seed ^ 0x5bd1_e995_9e37_79b9
        return PulseWatchSealRandom.unit(&state)
    }

    private static func erode(face: CGRect, seed: UInt64, texture: Double, context: inout GraphicsContext) {
        guard texture > 0 else { return }
        var state = seed
        let side = face.width
        for _ in 0..<Int(min(max(side / 3, 8), 48) * texture) {
            let edge = Int(PulseWatchSealRandom.unit(&state) * 4) % 4
            let along = CGFloat(PulseWatchSealRandom.unit(&state)) * side
            let radius = max(0.5, side * CGFloat(0.005 + PulseWatchSealRandom.unit(&state) * 0.01))
            let bite = radius * CGFloat(0.3 + PulseWatchSealRandom.unit(&state) * 0.5)
            let center: CGPoint = switch edge {
            case 0: CGPoint(x: face.minX + along, y: face.minY + bite - radius)
            case 1: CGPoint(x: face.maxX - bite + radius, y: face.minY + along)
            case 2: CGPoint(x: face.minX + along, y: face.maxY - bite + radius)
            default: CGPoint(x: face.minX + bite - radius, y: face.minY + along)
            }
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(.black))
        }
        for _ in 0..<Int(min(side * side / 200, 180) * texture) {
            let center = CGPoint(
                x: face.minX + CGFloat(PulseWatchSealRandom.unit(&state)) * side,
                y: face.minY + CGFloat(PulseWatchSealRandom.unit(&state)) * side
            )
            let radius = max(0.3, side * CGFloat(0.0015 + PulseWatchSealRandom.unit(&state) * 0.004))
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(.black.opacity(0.15 + PulseWatchSealRandom.unit(&state) * 0.45))
            )
        }
    }
}

struct PulseWatchSealSlot: View {
    let text: String?
    let tint: Color
    var ghostOpacity = 0.6

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * PulseWatchDesign.sealCornerFraction, style: .continuous)
                    .fill(tint.opacity(0.06))
                RoundedRectangle(cornerRadius: side * PulseWatchDesign.sealCornerFraction, style: .continuous)
                    .strokeBorder(
                        tint,
                        style: StrokeStyle(
                            lineWidth: max(1.5, side * 0.045),
                            lineCap: .round,
                            dash: [side * 0.1, side * 0.075]
                        )
                    )
                if let text {
                    Text(verbatim: text)
                        .font(.system(size: side * (text.count > 1 ? 0.46 : 0.56), weight: .bold, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(tint.opacity(ghostOpacity))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
