import PulseCore
import SwiftUI

/// What a seal carries. The big seal carries the one thing; day marks carry their date.
enum PulseSealInscription: Equatable, Sendable {
    case name(String)
    case number(Int)
    case glyph(String)
}

enum PulseSealTypeface: Equatable, Sendable {
    /// The bundled display serif. Only the app registers it; elsewhere it falls back to the system face.
    case display
    case systemSerif

    func font(size: CGFloat) -> Font {
        switch self {
        case .display:
            .custom("NotoSerifSC-Regular", fixedSize: size).weight(.black)
        case .systemSerif:
            .system(size: size, weight: .black, design: .serif)
        }
    }
}

/// Stable per-day variation, so a day's impression looks the same everywhere it appears.
enum PulseSealSeed {
    static func value(for text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01b3
        }
        return hash
    }

    static func value(for day: LogicalDay) -> UInt64 {
        value(for: day.storageValue)
    }

    static func tilt(for seed: UInt64, maximum: Double = 3) -> Angle {
        var random = PulseSealRandom(seed: seed ^ 0x5bd1_e995_9e37_79b9)
        return .degrees((random.unit() * 2 - 1) * maximum)
    }
}

/// SplitMix64: `SystemRandomNumberGenerator` cannot be seeded, and the texture must not change between renders.
struct PulseSealRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e37_79b9_7f4a_7c15
        var value = state
        value = (value ^ (value >> 30)) &* 0xbf58_476d_1ce4_e5b9
        value = (value ^ (value >> 27)) &* 0x94d0_49bb_1331_11eb
        return value ^ (value >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }
}

enum PulseSealLayout: Equatable {
    /// Right-to-left columns, each read top to bottom, the way a seal is read.
    case columns([[String]])
    case lines([String])

    static func resolve(_ inscription: PulseSealInscription) -> PulseSealLayout {
        switch inscription {
        case .number(let value):
            .lines([String(value)])
        case .glyph(let glyph):
            .columns([[glyph]])
        case .name(let name):
            resolve(name: name)
        }
    }

    static func resolve(name rawName: String) -> PulseSealLayout {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let characters = name.map(String.init)
        guard !characters.isEmpty else { return .lines([]) }
        let wideCount = characters.filter(isWide).count
        if !name.contains(where: \.isWhitespace),
           characters.count <= 12,
           wideCount * 2 >= characters.count {
            return .columns(columns(for: characters))
        }
        return .lines(lines(for: name))
    }

    private static func columns(for characters: [String]) -> [[String]] {
        let count = characters.count
        let columnCount = count <= 3 ? 1 : (count <= 6 ? 2 : 3)
        let base = count / columnCount
        let extra = count % columnCount
        var result: [[String]] = []
        var index = 0
        for column in 0..<columnCount {
            let length = base + (column < extra ? 1 : 0)
            result.append(Array(characters[index..<(index + length)]))
            index += length
        }
        return result
    }

    private static func lines(for name: String) -> [String] {
        let words = name.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count > 1 else { return [name] }
        var best: [String] = [name]
        var bestScore = score([name])
        for lineCount in 2...min(3, words.count) {
            let candidate = balancedLines(words, count: lineCount)
            let candidateScore = score(candidate)
            if candidateScore > bestScore {
                best = candidate
                bestScore = candidateScore
            }
        }
        return best
    }

    /// Larger is better: roughly the type size a square face allows for these lines.
    private static func score(_ lines: [String]) -> Double {
        let longest = Double(lines.map(\.count).max() ?? 1)
        return min(1 / max(longest * 0.6, 1), 1 / (Double(lines.count) * 1.15))
    }

    private static func balancedLines(_ words: [String], count: Int) -> [String] {
        let total = words.reduce(0) { $0 + $1.count } + words.count - 1
        let target = Double(total) / Double(count)
        var lines: [String] = []
        var current = ""
        for (index, word) in words.enumerated() {
            let remainingWords = words.count - index
            let remainingLines = count - lines.count
            let candidate = current.isEmpty ? word : current + " " + word
            if !current.isEmpty,
               Double(candidate.count) > target * 1.15 || remainingWords < remainingLines {
                lines.append(current)
                current = word
            } else {
                current = candidate
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private static func isWide(_ character: String) -> Bool {
        guard let scalar = character.unicodeScalars.first?.value else { return false }
        switch scalar {
        case 0x1100...0x11FF, 0x2E80...0x2FFF, 0x3000...0x303F, 0x3040...0x30FF,
             0x3100...0x312F, 0x3130...0x318F, 0x3190...0x31FF, 0x3400...0x4DBF,
             0x4E00...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF, 0xFF00...0xFFEF,
             0x20000...0x3134F:
            return true
        default:
            return false
        }
    }
}

/// Draws an inscription into a context. Used both to carve (destination-out) and to ghost it.
enum PulseSealCarving {
    static func draw(
        _ layout: PulseSealLayout,
        in face: CGRect,
        typeface: PulseSealTypeface,
        color: Color,
        context: inout GraphicsContext
    ) {
        switch layout {
        case .columns(let columns):
            drawColumns(columns, in: face, typeface: typeface, color: color, context: &context)
        case .lines(let lines):
            drawLines(lines, in: face, typeface: typeface, color: color, context: &context)
        }
    }

    private static func drawColumns(
        _ columns: [[String]],
        in face: CGRect,
        typeface: PulseSealTypeface,
        color: Color,
        context: inout GraphicsContext
    ) {
        guard !columns.isEmpty else { return }
        let inset = face.width * (columns.count == 1 && columns[0].count == 1 ? 0.14 : 0.1)
        let inner = face.insetBy(dx: inset, dy: inset)
        let rows = CGFloat(columns.map(\.count).max() ?? 1)
        let cellWidth = inner.width / CGFloat(columns.count)
        let cellHeight = inner.height / rows
        let fontSize = min(cellWidth, cellHeight) * 0.97
        let stretch = min(max(cellWidth / cellHeight, 0.86), 1.2)
        for (columnIndex, column) in columns.enumerated() {
            let centerX = inner.maxX - cellWidth * (CGFloat(columnIndex) + 0.5)
            let top = inner.midY - cellHeight * CGFloat(column.count) / 2
            for (rowIndex, glyph) in column.enumerated() {
                let text = context.resolve(
                    Text(verbatim: glyph).font(typeface.font(size: fontSize)).foregroundStyle(color)
                )
                var glyphContext = context
                glyphContext.translateBy(
                    x: centerX,
                    y: top + cellHeight * (CGFloat(rowIndex) + 0.5) + fontSize * opticalLift(typeface)
                )
                glyphContext.scaleBy(x: stretch, y: 1)
                glyphContext.draw(text, at: .zero, anchor: .center)
            }
        }
    }

    private static func drawLines(
        _ lines: [String],
        in face: CGRect,
        typeface: PulseSealTypeface,
        color: Color,
        context: inout GraphicsContext
    ) {
        guard !lines.isEmpty else { return }
        let inner = face.insetBy(dx: face.width * 0.13, dy: face.height * 0.13)
        var fontSize = inner.height / (CGFloat(lines.count) * 1.08)
        let resolved: [GraphicsContext.ResolvedText] = lines.map {
            context.resolve(Text(verbatim: $0).font(typeface.font(size: fontSize)))
        }
        let widest = resolved.map { $0.measure(in: CGSize(width: 10_000, height: 10_000)).width }.max() ?? 1
        if widest > inner.width {
            fontSize *= inner.width / widest
        }
        let lineHeight = fontSize * 1.08
        let top = inner.midY - lineHeight * CGFloat(lines.count) / 2
        for (index, line) in lines.enumerated() {
            let text = context.resolve(
                Text(verbatim: line).font(typeface.font(size: fontSize)).foregroundStyle(color)
            )
            context.draw(
                text,
                at: CGPoint(x: inner.midX, y: top + lineHeight * (CGFloat(index) + 0.5)),
                anchor: .center
            )
        }
    }

    /// The display serif sets CJK glyphs a little high in their line box.
    private static func opticalLift(_ typeface: PulseSealTypeface) -> CGFloat {
        typeface == .display ? 0.035 : 0
    }
}

/// One impression of a seal on paper: the face in ink, the inscription carved out, the edge and
/// the ink coverage slightly uneven, the way a real seal never prints the same twice.
struct PulseSealImpression: View {
    let inscription: PulseSealInscription
    let ink: Color
    var seed: UInt64 = 0
    var texture: Double = 1
    var typeface: PulseSealTypeface = .display
    var cornerFraction: CGFloat = 0.075

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let face = CGRect(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2,
                width: side,
                height: side
            )
            context.drawLayer { layer in
                layer.fill(
                    Path(roundedRect: face, cornerRadius: side * cornerFraction, style: .continuous),
                    with: .color(ink)
                )
                layer.blendMode = .destinationOut
                PulseSealCarving.draw(
                    PulseSealLayout.resolve(inscription),
                    in: face,
                    typeface: typeface,
                    color: .black,
                    context: &layer
                )
                Self.erode(face: face, seed: seed, texture: texture, context: &layer)
            }
            Self.bleed(
                PulseSealLayout.resolve(inscription),
                face: face,
                typeface: typeface,
                ink: ink,
                seed: seed,
                texture: texture,
                context: &context
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    static func erode(
        face: CGRect,
        seed: UInt64,
        texture: Double,
        bitesRim: Bool = true,
        context: inout GraphicsContext
    ) {
        guard texture > 0 else { return }
        var random = PulseSealRandom(seed: seed)
        let side = face.width

        let nickCount = bitesRim ? Int(min(max(side / 2.6, 10), 96) * texture) : 0
        for _ in 0..<nickCount {
            let edge = Int(random.unit() * 4) % 4
            let along = CGFloat(random.unit()) * side
            let radius = max(0.6, side * CGFloat(random.range(0.004, 0.013)))
            let bite = radius * CGFloat(random.range(0.25, 0.8))
            let center: CGPoint = switch edge {
            case 0: CGPoint(x: face.minX + along, y: face.minY + bite - radius)
            case 1: CGPoint(x: face.maxX - bite + radius, y: face.minY + along)
            case 2: CGPoint(x: face.minX + along, y: face.maxY - bite + radius)
            default: CGPoint(x: face.minX + bite - radius, y: face.minY + along)
            }
            context.fill(circle(center, radius), with: .color(.black))
        }

        // A hand never presses evenly: one side of the face always prints a little lighter.
        let pressureAngle = random.range(0, .pi * 2)
        let pressureCenter = CGPoint(
            x: face.midX + CGFloat(cos(pressureAngle)) * side * 0.62,
            y: face.midY + CGFloat(sin(pressureAngle)) * side * 0.62
        )
        context.fill(
            Path(face),
            with: .radialGradient(
                Gradient(colors: [.black.opacity(0.2 * texture), .black.opacity(0.06 * texture), .clear]),
                center: pressureCenter,
                startRadius: 0,
                endRadius: side * 0.78
            )
        )

        let grainCount = Int(min(side * side / 190, 420) * texture)
        for _ in 0..<grainCount {
            let center = CGPoint(
                x: face.minX + CGFloat(random.unit()) * side,
                y: face.minY + CGFloat(random.unit()) * side
            )
            let radius = max(0.3, side * CGFloat(random.range(0.0011, 0.003)))
            context.fill(circle(center, radius), with: .color(.black.opacity(random.range(0.1, 0.42))))
        }

        // Where the ink skipped, it skipped in patches, and mostly near the rim.
        let patchCount = 2 + Int(random.unit() * 3)
        let dotsPerPatch = max(2, min(side / 16, 14) * texture)
        for _ in 0..<patchCount {
            var anchorX = random.range(0.15, 0.85)
            var anchorY = random.range(0.15, 0.85)
            if random.unit() < 0.7 {
                if random.unit() < 0.5 {
                    anchorX = rimBiased(&random)
                } else {
                    anchorY = rimBiased(&random)
                }
            }
            let anchor = CGPoint(x: face.minX + side * CGFloat(anchorX), y: face.minY + side * CGFloat(anchorY))
            let spread = side * CGFloat(random.range(0.035, 0.08))
            for _ in 0..<Int(dotsPerPatch * random.range(0.6, 1.2)) {
                let dx = CGFloat(random.unit() + random.unit() - 1) * spread
                let dy = CGFloat(random.unit() + random.unit() - 1) * spread
                let radius = max(0.35, side * CGFloat(random.range(0.0014, 0.0045)))
                context.fill(
                    circle(CGPoint(x: anchor.x + dx, y: anchor.y + dy), radius),
                    with: .color(.black.opacity(random.range(0.3, 0.75)))
                )
            }
        }
    }

    /// Ink creeping back into the carved strokes, the way it does on any well-used seal.
    static func bleed(
        _ layout: PulseSealLayout,
        face: CGRect,
        typeface: PulseSealTypeface,
        ink: Color,
        seed: UInt64,
        texture: Double,
        context: inout GraphicsContext
    ) {
        guard texture > 0 else { return }
        context.drawLayer { layer in
            layer.clipToLayer { mask in
                PulseSealCarving.draw(layout, in: face, typeface: typeface, color: .black, context: &mask)
            }
            var random = PulseSealRandom(seed: seed ^ 0x2545_f491_4f6c_dd1d)
            let side = face.width
            let count = Int(min(side * side / 700, 110) * texture)
            for _ in 0..<count {
                let center = CGPoint(
                    x: face.minX + CGFloat(random.unit()) * side,
                    y: face.minY + CGFloat(random.unit()) * side
                )
                let radius = max(0.35, side * CGFloat(random.range(0.0014, 0.0046)))
                layer.fill(circle(center, radius), with: .color(ink.opacity(random.range(0.35, 0.85))))
            }
        }
    }

    private static func rimBiased(_ random: inout PulseSealRandom) -> Double {
        let depth = random.range(0.03, 0.2)
        return random.unit() < 0.5 ? depth : 1 - depth
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Where today's impression will land: a dashed outline and the inscription, barely there.
/// The same dashed outline marks today in every row of days.
struct PulseSealSlot: View {
    let inscription: PulseSealInscription
    let tint: Color
    var typeface: PulseSealTypeface = .display
    var isPressed = false
    var cornerFraction: CGFloat = 0.075
    var ghostOpacity = 0.1

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let lineWidth = max(1.5, side * 0.0085)
            let face = CGRect(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2,
                width: side,
                height: side
            )
            let outline = Path(
                roundedRect: face.insetBy(dx: lineWidth / 2, dy: lineWidth / 2),
                cornerRadius: side * cornerFraction,
                style: .continuous
            )
            context.fill(outline, with: .color(tint.opacity(isPressed ? 0.1 : 0.035)))
            var ghost = context
            ghost.opacity = isPressed ? max(0.22, ghostOpacity * 1.8) : ghostOpacity
            PulseSealCarving.draw(
                PulseSealLayout.resolve(inscription),
                in: face,
                typeface: typeface,
                color: tint,
                context: &ghost
            )
            context.stroke(
                outline,
                with: .color(tint.opacity(isPressed ? 1 : 0.7)),
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    dash: [side * 0.036, side * 0.026]
                )
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Ink reaching outward from where the seal met the paper. The edge wobbles so it reads as ink, not a wipe.
struct PulseInkSpreadShape: Shape {
    var progress: CGFloat
    var seed: UInt64

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let reach = hypot(rect.width, rect.height) / 2 * 1.08 * progress
        guard reach > 0 else { return Path() }
        var random = PulseSealRandom(seed: seed ^ 0xa076_1d64_78bd_642f)
        let lobes = (0..<5).map { _ in (random.range(0.5, 1), random.range(0, .pi * 2), random.range(2, 6)) }
        var path = Path()
        let steps = 72
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * .pi * 2
            var wobble = 0.0
            for (strength, phase, frequency) in lobes {
                wobble += strength * sin(angle * frequency.rounded() + phase)
            }
            let radius = reach * (1 + CGFloat(wobble) * 0.035 * (1 - progress * 0.6))
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

enum PulseDayMarkState: Equatable, Sendable {
    case kept
    case awaiting
    case missed
    case quiet
}

extension PulseDayMarkState {
    init(_ state: PulseWidgetDayState) {
        switch state {
        case .checked: self = .kept
        case .todayPending: self = .awaiting
        case .missed: self = .missed
        case .beforeHabit: self = .quiet
        }
    }
}

/// One day in a row or a month: kept days are small seals carrying their date.
struct PulseDayMark: View {
    let day: Int
    let state: PulseDayMarkState
    let seed: UInt64
    let seal: Color
    let ink: Color
    let muted: Color
    var emphasized = false
    /// Too small for a legible date: days that were not kept become a dash or a dot.
    var isCompact = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch state {
                case .kept:
                    PulseSealImpression(
                        inscription: .number(day),
                        ink: seal,
                        seed: seed,
                        texture: 0.55,
                        typeface: .systemSerif,
                        cornerFraction: 0.14
                    )
                    .rotationEffect(PulseSealSeed.tilt(for: seed, maximum: 4))
                case .awaiting:
                    RoundedRectangle(cornerRadius: side * 0.14, style: .continuous)
                        .strokeBorder(
                            seal,
                            style: StrokeStyle(lineWidth: max(1.2, side * 0.045), dash: [side * 0.1, side * 0.075])
                        )
                    if !isCompact {
                        number(size: side, color: seal, weight: .semibold)
                    }
                case .missed:
                    if !isCompact {
                        number(size: side, color: muted, weight: .regular)
                    }
                    Capsule()
                        .fill(muted.opacity(0.7))
                        .frame(width: side * (isCompact ? 0.42 : 0.26), height: max(1, side * (isCompact ? 0.08 : 0.04)))
                        .offset(y: isCompact ? 0 : side * 0.3)
                case .quiet:
                    if isCompact {
                        Circle()
                            .fill(muted.opacity(0.45))
                            .frame(width: max(2, side * 0.14), height: max(2, side * 0.14))
                    } else {
                        number(size: side, color: muted.opacity(0.55), weight: .regular)
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func number(size: CGFloat, color: Color, weight: Font.Weight) -> some View {
        Text(day, format: .number)
            .font(.system(size: size * 0.4, weight: emphasized ? .bold : weight, design: .serif))
            .monospacedDigit()
            .foregroundStyle(color)
    }
}
