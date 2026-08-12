import SwiftUI

enum PulsePrimarySection: String, CaseIterable, Identifiable {
    case today
    case history

    var id: Self { self }
}

struct PulsePrimaryNavigation: View {
    @Binding var selection: PulsePrimarySection
    let todayDayNumber: Int?
    let historyMonthNumber: Int?
    let isTodayChecked: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var navigationHeight = PulseDesign.primaryNavigationHeight
    @ScaledMetric(relativeTo: .body) private var glyphSize = PulseDesign.primaryNavigationGlyph
    @Namespace private var selectionNamespace

    var body: some View {
        navigationLayout
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize
                    ? .infinity
                    : PulseDesign.primaryNavigationMaxWidth
            )
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

    @ViewBuilder
    private var navigationLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: PulseDesign.primaryNavigationGap) {
                accessibilityNavigationButton(for: .today)
                accessibilityNavigationButton(for: .history)
            }
            .padding(PulseDesign.primaryNavigationPadding)
        } else {
            HStack(spacing: PulseDesign.primaryNavigationGap) {
                navigationButton(for: .today)
                navigationButton(for: .history)
            }
            .padding(PulseDesign.primaryNavigationPadding)
            .frame(height: navigationHeight)
        }
    }

    private func navigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section

        return Button {
            select(section)
        } label: {
            HStack(spacing: PulseDesign.spacing12) {
                navigationGlyph(for: section, isSelected: isSelected)

                VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                    Text(section == .today ? "tab.today" : "tab.history")
                        .font(.caption.bold())
                        .lineLimit(1)

                    if isSelected {
                        Text(subtitleKey(for: section))
                            .font(.caption2)
                            .opacity(PulseDesign.navigationSubtitleOpacity)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PulseDesign.spacing12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(isSelected ? PulseDesign.grassForeground : PulseDesign.secondary)
            .background {
                selectionBackground(isSelected: isSelected)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                    style: .continuous
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(isSelected ? Text(subtitleKey(for: section)) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityNavigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section

        return Button {
            select(section)
        } label: {
            VStack(spacing: PulseDesign.spacing4) {
                if let value = glyphValue(for: section) {
                    Text(value, format: .number)
                        .font(.body.bold())
                        .monospacedDigit()
                }

                Text(section == .today ? "tab.today" : "tab.history")
                    .font(.caption.bold())
                    .lineLimit(2)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, PulseDesign.spacing12)
            .padding(.vertical, PulseDesign.spacing8)
            .frame(
                maxWidth: .infinity,
                minHeight: PulseDesign.accessibilityNavigationMinimumHeight
            )
            .foregroundStyle(isSelected ? PulseDesign.grassForeground : PulseDesign.secondary)
            .background {
                selectionBackground(isSelected: isSelected)
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                    style: .continuous
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(isSelected ? Text(subtitleKey(for: section)) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func selectionBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(
                cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.grass)
            .matchedGeometryEffect(
                id: "primary.navigation.selection",
                in: selectionNamespace
            )
        }
    }

    private func select(_ section: PulsePrimarySection) {
        guard selection != section else { return }
        guard !reduceMotion else {
            selection = section
            return
        }
        withAnimation(.smooth(duration: PulseDesign.primaryNavigationSelectionDuration)) {
            selection = section
        }
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
        .frame(width: glyphSize, height: glyphSize)
        .foregroundStyle(isSelected ? PulseDesign.grassForeground : PulseDesign.secondary)
        .accessibilityHidden(true)
    }

    private func glyphValue(for section: PulsePrimarySection) -> Int? {
        switch section {
        case .today: todayDayNumber
        case .history: historyMonthNumber
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
