import PulseCore
import SwiftUI

struct WidgetStyleGalleryView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var showsStore = false

    var body: some View {
        ZStack {
            PulsePosterBackground()

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

                HStack {
                    Text(style.localizedName(locale: locale))
                        .font(.headline.weight(.black))
                        .foregroundStyle(PulseDesign.ink)
                    Spacer()
                    if isSelected {
                        Label("widget.gallery.selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseDesign.grass)
                    } else if isLocked {
                        Label("widget.gallery.locked", systemImage: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseDesign.action)
                    }
                }
            }
            .padding(.bottom, PulseDesign.spacing16)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isSelected ? PulseDesign.grass : PulseDesign.ink)
                    .frame(height: isSelected ? PulseDesign.emphasisLineWidth : PulseDesign.thinLineWidth)
            }
            .contentShape(Rectangle())
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
            .clipShape(RoundedRectangle(cornerRadius: PulseDesign.mediaCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PulseDesign.mediaCornerRadius, style: .continuous)
                    .stroke(PulseDesign.ink, lineWidth: PulseDesign.thinLineWidth)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func preview(in size: CGSize) -> some View {
        switch style {
        case .faultField:
            ZStack {
                PulsePreviewFault()
                    .fill(PulseDesign.action)
                    .frame(width: size.width * 0.62)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                HStack {
                    previewDay(size: min(size.width, size.height) * 0.34)
                    Spacer()
                    previewCommitment
                        .foregroundStyle(PulseDesign.actionForeground)
                        .frame(width: size.width * 0.42, alignment: .leading)
                }
                .padding(PulseDesign.spacing16)
            }
        case .oversizedRing:
            HStack(spacing: PulseDesign.spacing8) {
                PulseOpenRing(color: PulseDesign.action, lineWidth: 18)
                    .frame(width: size.height * 1.08, height: size.height * 1.08)
                    .offset(x: -size.height * 0.28)
                VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                    previewDay(size: size.height * 0.28)
                    previewCommitment
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .commitmentManifesto:
            VStack(alignment: .leading) {
                HStack {
                    Circle().fill(PulseDesign.action).frame(width: 10, height: 10)
                    Spacer()
                    previewDay(size: size.height * 0.24)
                }
                Spacer()
                previewCommitment
                    .font(.title2.weight(.black))
                Spacer()
                Rectangle().fill(PulseDesign.ink).frame(height: 8)
            }
            .padding(PulseDesign.spacing16)
        case .tearOffCalendar:
            VStack(spacing: 0) {
                PulseDesign.action.frame(height: size.height * 0.24)
                HStack(alignment: .bottom) {
                    previewDay(size: size.height * 0.48)
                    previewCommitment
                    Spacer(minLength: 0)
                    PulseOpenRing(color: PulseDesign.grass, lineWidth: 9)
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(8))
                }
                .padding(PulseDesign.spacing12)
            }
        }
    }

    private func previewDay(size: CGFloat) -> some View {
        Group {
            if let dayNumber {
                Text(dayNumber, format: .number)
                    .font(.system(size: size, weight: .black))
                    .monospacedDigit()
                    .tracking(-2)
                    .foregroundStyle(PulseDesign.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private var previewCommitment: some View {
        Group {
            if let commitmentName {
                Text(verbatim: commitmentName)
                    .font(.headline.weight(.black))
                    .foregroundStyle(PulseDesign.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

private struct PulsePreviewFault: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.32, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
