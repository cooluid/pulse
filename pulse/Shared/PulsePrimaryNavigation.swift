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
        .frame(height: PulseDesign.primaryNavigationHeight)
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
                .fill(PulseDesign.surface.opacity(0.9))
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
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func navigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section

        return Button {
            selection = section
        } label: {
            HStack(spacing: PulseDesign.spacing10) {
                navigationGlyph(for: section, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 1) {
                    Text(section == .today ? "tab.today" : "tab.history")
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)

                    if isSelected, !dynamicTypeSize.isAccessibilitySize {
                        Text(subtitleKey(for: section))
                            .font(.system(size: 9))
                            .opacity(0.76)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PulseDesign.spacing13)
            .frame(maxWidth: .infinity, minHeight: 56)
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
        .accessibilityValue(isSelected ? Text(subtitleKey(for: section)) : Text(""))
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
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
            }
        }
        .frame(
            width: PulseDesign.primaryNavigationGlyph,
            height: PulseDesign.primaryNavigationGlyph
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
