import SwiftUI

enum PulsePrimarySection: String, CaseIterable, Identifiable {
    case today
    case history

    var id: Self { self }
}

struct PulsePrimaryNavigation: View {
    @Binding var selection: PulsePrimarySection
    let todayDayNumber: Int?
    let historyMonthDayCount: Int?
    let isTodayChecked: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var navigationHeight = PulseDesign.primaryNavigationHeight
    @ScaledMetric(relativeTo: .body) private var glyphSize = PulseDesign.primaryNavigationGlyph

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = proxy.size.width
                - PulseDesign.primaryNavigationPadding * 2
                - PulseDesign.primaryNavigationGap
            let ratioTotal = PulseDesign.primaryNavigationSelectedRatio
                + PulseDesign.primaryNavigationUnselectedRatio
            let todayRatio = selection == .today
                ? PulseDesign.primaryNavigationSelectedRatio
                : PulseDesign.primaryNavigationUnselectedRatio
            let historyRatio = selection == .history
                ? PulseDesign.primaryNavigationSelectedRatio
                : PulseDesign.primaryNavigationUnselectedRatio

            HStack(spacing: PulseDesign.primaryNavigationGap) {
                navigationButton(for: .today)
                    .frame(
                        width: contentWidth
                            * todayRatio
                            / ratioTotal
                    )

                navigationButton(for: .history)
                    .frame(
                        width: contentWidth
                            * historyRatio
                            / ratioTotal
                    )
            }
            .padding(PulseDesign.primaryNavigationPadding)
        }
        .frame(maxWidth: PulseDesign.primaryNavigationMaxWidth)
        .frame(height: navigationHeight)
        .background {
            RoundedRectangle(
                cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                    style: .continuous
                )
                .fill(PulseDesign.surface.opacity(PulseDesign.navigationSurfaceOpacity))
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                style: .continuous
            )
            .stroke(PulseDesign.separator, lineWidth: PulseDesign.thinLineWidth)
        }
        .shadow(
            color: PulseDesign.shadow.opacity(PulseDesign.navigationShadowOpacity),
            radius: PulseDesign.navigationShadowRadius,
            y: PulseDesign.navigationShadowY
        )
        .padding(.horizontal, PulseDesign.primaryNavigationHorizontalInset)
        .padding(.vertical, PulseDesign.spacing8)
        .frame(maxWidth: .infinity)
    }

    private func navigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section

        return Button {
            selection = section
        } label: {
            HStack(spacing: PulseDesign.spacing12) {
                navigationGlyph(for: section, isSelected: isSelected)

                VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                    Text(section == .today ? "tab.today" : "tab.history")
                        .font(.caption.bold())
                        .lineLimit(1)

                    if isSelected, !dynamicTypeSize.isAccessibilitySize {
                        Text(subtitleKey(for: section))
                            .font(.caption2)
                            .opacity(PulseDesign.navigationSubtitleOpacity)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PulseDesign.spacing12)
            .frame(
                maxWidth: .infinity,
                minHeight: navigationHeight - PulseDesign.primaryNavigationPadding * 2
            )
            .foregroundStyle(isSelected ? PulseDesign.grassForeground : PulseDesign.secondary)
            .background(isSelected ? PulseDesign.grass : Color.clear)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                    style: .continuous
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(isSelected ? Text(subtitleKey(for: section)) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func navigationGlyph(for section: PulsePrimarySection, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected ? PulseDesign.navigationGlyphSurface : Color.clear)
            Circle()
                .stroke(
                    isSelected ? PulseDesign.navigationGlyphSurface : PulseDesign.secondary,
                    lineWidth: PulseDesign.thinLineWidth
                )

            if let value = glyphValue(for: section) {
                Text(value, format: .number)
                    .font(.caption2.bold())
                    .monospacedDigit()
            }
        }
        .frame(
            width: glyphSize,
            height: glyphSize
        )
        .foregroundStyle(isSelected ? PulseDesign.grassForeground : PulseDesign.secondary)
        .accessibilityHidden(true)
    }

    private func glyphValue(for section: PulsePrimarySection) -> Int? {
        switch section {
        case .today: todayDayNumber
        case .history: historyMonthDayCount
        }
    }

    private func subtitleKey(for section: PulsePrimarySection) -> LocalizedStringKey {
        switch section {
        case .today:
            isTodayChecked ? "today.navigation.checked" : "today.navigation.pending"
        case .history:
            "history.navigation.subtitle"
        }
    }
}
