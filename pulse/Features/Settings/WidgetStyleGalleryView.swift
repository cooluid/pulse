import PulseCore
import SwiftUI

struct WidgetStyleGalleryView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var showsStore = false

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground()

            ScrollView {
                LazyVGrid(columns: columns, spacing: PulseDesign.spacing20) {
                    ForEach(PulseWidgetStyle.allCases) { style in
                        styleButton(style)
                    }
                }
                .frame(maxWidth: PulseDesign.historyMaxWidth)
                .padding(PulseDesign.horizontalPadding)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("widget.gallery.navigation_title")
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .navigationDestination(isPresented: $showsStore) {
            EnhancementStoreView(model: model)
        }
    }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: PulseDesign.spacing20), count: count)
    }

    private func styleButton(_ style: PulseWidgetStyle) -> some View {
        let isSelected = model.settings.widgetStyle == style
        let isLocked = PulseWidgetStyleAccessPolicy.requiresEnhancement(style)
            && !model.featureAccess.hasEnhancement

        return Button {
            if isLocked {
                showsStore = true
            } else {
                model.requestWidgetStyle(style)
            }
        } label: {
            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                PulseWidgetStylePreview(
                    style: style,
                    dayNumber: model.today?.day,
                    commitmentName: model.habit?.name
                )
                .frame(height: PulseDesign.widgetGalleryPreviewHeight)

                HStack(alignment: .firstTextBaseline) {
                    Text(style.localizedName(locale: locale))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PulseDesign.ink)
                    Spacer()
                    if isSelected {
                        Label("widget.gallery.selected", systemImage: "checkmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PulseDesign.grassForeground)
                            .padding(.horizontal, PulseDesign.spacing8)
                            .padding(.vertical, PulseDesign.spacing4)
                            .background(PulseDesign.grass, in: Capsule())
                    } else if isLocked {
                        Label("widget.gallery.locked", systemImage: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(PulseDesign.action)
                            .padding(.horizontal, PulseDesign.spacing8)
                            .padding(.vertical, PulseDesign.spacing4)
                            .background(PulseDesign.field.opacity(0.12), in: Capsule())
                    }
                }

                Text(verbatim: style.localizedDescription(locale: locale))
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PulseDesign.spacing12)
            .background {
                RoundedRectangle(
                    cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
                    style: .continuous
                )
                .fill(
                    isSelected
                        ? PulseDesign.field.opacity(0.09)
                        : PulseDesign.surface.opacity(0.88)
                )
            }
            .overlay {
                RoundedRectangle(
                    cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
                    style: .continuous
                )
                .stroke(
                    isSelected
                        ? PulseDesign.grass.opacity(0.52)
                        : PulseDesign.separator.opacity(0.72),
                    lineWidth: PulseDesign.thinLineWidth
                )
            }
            .shadow(
                color: PulseDesign.shadow.opacity(isSelected ? 0.09 : 0.045),
                radius: isSelected ? 18 : 10,
                y: isSelected ? 7 : 4
            )
            .contentShape(RoundedRectangle(
                cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
                style: .continuous
            ))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("widget.gallery.style.\(style.rawValue)")
    }
}

struct PulseWidgetStylePreview: View {
    let style: PulseWidgetStyle
    let dayNumber: Int?
    let commitmentName: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PulseDesign.surface
                preview(in: proxy.size)
            }
            .clipShape(RoundedRectangle(
                cornerRadius: PulseDesign.widgetPreviewCornerRadius,
                style: .continuous
            ))
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func preview(in size: CGSize) -> some View {
        switch style {
        case .breathingOrbit:
            ZStack {
                previewContours(size: size, anchor: CGPoint(x: 0.78, y: 0.58))

                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    previewHeader
                    Spacer(minLength: 0)
                    previewCommitment()
                        .frame(width: size.width * 0.66, alignment: .leading)
                    Spacer(minLength: 0)
                    HStack {
                        previewRhythm
                        Spacer()
                        previewImprint
                    }
                }
                .padding(PulseDesign.spacing16)
            }
        case .diagonalLight:
            ZStack {
                PulseDiagonalField()
                    .fill(PulseDesign.field.opacity(0.18))
                PulseDiagonalField(boundaryOffset: -0.045)
                    .fill(PulseDesign.grass.opacity(0.055))

                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    previewHeader
                    Spacer(minLength: 0)
                    previewCommitment()
                        .frame(width: size.width * 0.61, alignment: .leading)
                    HStack {
                        previewRhythm
                        Spacer()
                        previewImprint
                    }
                }
                .padding(PulseDesign.spacing16)
            }
        case .tidalFill:
            ZStack {
                PulseTidalField(level: 0.48, lift: 0.025)
                    .fill(PulseDesign.field.opacity(0.10))
                PulseTidalField(level: 0.62, lift: -0.020)
                    .fill(PulseDesign.field.opacity(0.14))
                PulseTidalField(level: 0.76, lift: 0.018)
                    .fill(PulseDesign.grass.opacity(0.10))

                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    previewHeader
                    Spacer(minLength: 0)
                    previewCommitment()
                        .frame(width: size.width * 0.62, alignment: .leading)
                    Spacer(minLength: 0)
                    HStack {
                        previewRhythm
                        Spacer()
                        previewImprint
                    }
                }
                .padding(PulseDesign.spacing16)
            }
        case .morningDew:
            ZStack {
                Circle()
                    .fill(PulseDesign.field.opacity(0.15))
                    .frame(width: size.height * 0.82, height: size.height * 0.82)
                    .offset(x: size.width * 0.28, y: -size.height * 0.16)
                Circle()
                    .fill(PulseDesign.grass.opacity(0.12))
                    .frame(width: size.height * 0.34, height: size.height * 0.34)
                    .offset(x: size.width * 0.05, y: size.height * 0.30)

                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    HStack(alignment: .top) {
                        previewHeader
                        Spacer()
                        previewDay(size: size.height * 0.31)
                    }
                    Spacer(minLength: 0)
                    previewCommitment()
                        .frame(width: size.width * 0.68, alignment: .leading)
                    HStack {
                        previewRhythm
                        Spacer()
                        previewImprint
                    }
                }
                .padding(PulseDesign.spacing16)
            }
        case .cornerTint:
            ZStack {
                Circle()
                    .fill(PulseDesign.field.opacity(0.18))
                    .frame(width: size.height * 0.94, height: size.height * 0.94)
                    .offset(x: -size.width * 0.39, y: -size.height * 0.37)
                Circle()
                    .fill(PulseDesign.grass.opacity(0.10))
                    .frame(width: size.height * 0.72, height: size.height * 0.72)
                    .offset(x: size.width * 0.44, y: size.height * 0.38)

                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    previewHeader
                    Spacer(minLength: 0)
                    previewCommitment()
                        .frame(width: size.width * 0.60, alignment: .leading)
                    Spacer(minLength: 0)
                    HStack {
                        previewRhythm
                        Spacer()
                        previewImprint
                    }
                }
                .padding(PulseDesign.spacing16)
            }
        case .quietOrder:
            VStack(spacing: PulseDesign.spacing12) {
                previewHeader
                Spacer(minLength: 0)
                previewCommitment()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
                HStack(spacing: PulseDesign.spacing12) {
                    previewRhythm
                    Spacer(minLength: PulseDesign.spacing8)
                    previewImprint
                }
                .padding(.leading, PulseDesign.spacing12)
                .padding(.trailing, PulseDesign.spacing8)
                .padding(.vertical, PulseDesign.spacing8)
                .background(PulseDesign.field.opacity(0.10), in: Capsule())
            }
            .padding(PulseDesign.spacing16)
        }
    }

    private var previewHeader: some View {
        HStack(spacing: PulseDesign.spacing8) {
            Circle()
                .fill(PulseDesign.grass)
                .frame(width: 7, height: 7)
            Text("today.commitment.cue")
                .font(.caption2.weight(.medium))
                .foregroundStyle(PulseDesign.secondary)
            Spacer()
            if style != .morningDew {
                previewDay(size: 25)
            }
        }
    }

    private func previewContours(size: CGSize, anchor: CGPoint) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Ellipse()
                    .stroke(
                        PulseDesign.field.opacity(0.30 - Double(index) * 0.045),
                        lineWidth: index == 0 ? 1.4 : 1
                    )
                    .frame(
                        width: size.width * (0.82 - CGFloat(index) * 0.12),
                        height: size.height * (1.04 - CGFloat(index) * 0.13)
                    )
            }
        }
        .position(x: size.width * anchor.x, y: size.height * anchor.y)
    }

    private func previewDay(size: CGFloat) -> some View {
        Group {
            if let dayNumber {
                Text(dayNumber, format: .number)
                    .font(.system(size: size, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PulseDesign.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func previewCommitment(foreground: Color = PulseDesign.ink) -> some View {
        Group {
            if let commitmentName {
                Text(verbatim: commitmentName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(foreground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var previewRhythm: some View {
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 3) ? PulseDesign.grass : PulseDesign.separator)
                    .frame(width: index == 6 ? 8 : 6, height: index == 6 ? 8 : 6)
            }
        }
    }

    private var previewImprint: some View {
        ZStack {
            Circle()
                .stroke(PulseDesign.grass.opacity(0.42), lineWidth: 1)
            Circle()
                .fill(PulseDesign.action)
                .frame(width: 14, height: 14)
        }
        .frame(width: 34, height: 34)
    }
}

private struct PulseDiagonalField: Shape {
    var boundaryOffset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(
            x: rect.width * (0.46 + boundaryOffset),
            y: rect.minY
        ))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(
            x: rect.width * (0.24 + boundaryOffset),
            y: rect.maxY
        ))
        path.closeSubpath()
        return path
    }
}

private struct PulseTidalField: Shape {
    let level: CGFloat
    let lift: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startY = rect.height * level
        path.move(to: CGPoint(x: rect.minX, y: startY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * (level + lift)),
            control1: CGPoint(x: rect.width * 0.28, y: rect.height * (level - 0.10)),
            control2: CGPoint(x: rect.width * 0.70, y: rect.height * (level + 0.10))
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
