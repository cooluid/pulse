import SwiftUI

enum PulsePrimarySection: String, CaseIterable, Identifiable {
    case today
    case history

    var id: Self { self }
}

struct PulsePrimaryNavigation: View {
    @Binding var selection: PulsePrimarySection
    let todayDayNumber: Int?
    let isTodayChecked: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pulseVisualTheme) private var visualTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var navigationHeight = PulseDesign.primaryNavigationHeight
    @ScaledMetric(relativeTo: .body) private var glyphSize = PulseDesign.primaryNavigationGlyph
    @Namespace private var selectionNamespace

    @ViewBuilder
    var body: some View {
        switch visualTheme {
        case .sunlitDay:
            sunlitNavigation
        case .editorialJournal:
            EditorialPrimaryNavigation(selection: $selection)
        case .quietField:
            quietNavigation
        }
    }

    private var quietNavigation: some View {
        sizedNavigation
            .background {
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                    style: .continuous
                )
                .fill(PulseDesign.quietChrome)
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
                .stroke(
                    PulseDesign.quietGreen.opacity(0.34),
                    lineWidth: PulseDesign.thinLineWidth
                )
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

    private var sunlitNavigation: some View {
        sunlitNavigationLayout
            .frame(maxWidth: PulseDesign.primaryNavigationMaxWidth)
            .padding(.horizontal, PulseDesign.primaryNavigationHorizontalInset)
            .padding(.vertical, PulseDesign.spacing8)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var sunlitNavigationLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: PulseDesign.primaryNavigationGap) {
                sunlitAccessibilityNavigationButton(for: .today)
                sunlitAccessibilityNavigationButton(for: .history)
            }
            .padding(PulseDesign.primaryNavigationPadding)
            .frame(height: 104)
        } else {
            HStack(spacing: PulseDesign.primaryNavigationGap) {
                sunlitNavigationButton(for: .today)
                sunlitNavigationButton(for: .history)
            }
            .padding(PulseDesign.primaryNavigationPadding)
            .frame(height: PulseDesign.sunlitBarHeight)
        }
    }

    private func sunlitNavigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section

        return Button {
            select(section)
        } label: {
            HStack(spacing: PulseDesign.spacing12) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? PulseDesign.sunlitAccent
                                : PulseDesign.sunlitAccentSoft
                        )
                    Circle()
                        .stroke(
                            PulseDesign.sunlitOnAccent.opacity(0.24),
                            lineWidth: PulseDesign.thinLineWidth
                        )

                    navigationGlyphContent(for: section)
                        .foregroundStyle(PulseDesign.sunlitOnAccent)
                }
                .frame(width: resolvedGlyphSize, height: resolvedGlyphSize)
                .overlay(alignment: .topTrailing) {
                    if section == .today, isTodayChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(PulseDesign.sunlitChromeForeground)
                            .frame(width: 13, height: 13)
                            .background(PulseDesign.sunlitChrome, in: Circle())
                            .offset(x: 4, y: -3)
                            .accessibilityHidden(true)
                    }
                }

                VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                    Text(section == .today ? "tab.today" : "tab.history")
                        .font(.caption.bold())
                        .lineLimit(1)

                    Text(subtitleKey(for: section))
                        .font(.caption2)
                        .opacity(PulseDesign.navigationSubtitleOpacity)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PulseDesign.spacing12)
            .foregroundStyle(
                isSelected
                    ? PulseDesign.sunlitChromeForeground
                    : PulseDesign.sunlitInk
            )
            .background {
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                    style: .continuous
                )
                .fill(
                    isSelected
                        ? PulseDesign.sunlitChrome
                        : PulseDesign.sunlitSurface
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                    style: .continuous
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(isSelected ? Text(subtitleKey(for: section)) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sunlitAccessibilityNavigationButton(
        for section: PulsePrimarySection
    ) -> some View {
        let isSelected = selection == section

        return Button {
            select(section)
        } label: {
            VStack(spacing: PulseDesign.spacing4) {
                ZStack {
                    Circle()
                        .fill(PulseDesign.sunlitAccent)

                    navigationGlyphContent(for: section)
                        .foregroundStyle(PulseDesign.sunlitOnAccent)
                }
                .frame(width: resolvedGlyphSize, height: resolvedGlyphSize)

                Text(section == .today ? "tab.today" : "tab.history")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, PulseDesign.spacing8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(
                isSelected
                    ? PulseDesign.sunlitChromeForeground
                    : PulseDesign.sunlitInk
            )
            .background {
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                    style: .continuous
                )
                .fill(
                    isSelected
                        ? PulseDesign.sunlitChrome
                        : PulseDesign.sunlitSurface
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(isSelected ? Text(subtitleKey(for: section)) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sizedNavigation: some View {
        navigationLayout
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize
                    ? .infinity
                    : PulseDesign.primaryNavigationMaxWidth
            )
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
            .frame(
                height: navigationHeight
            )
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

                    Text(subtitleKey(for: section))
                        .font(.caption2)
                        .opacity(PulseDesign.navigationSubtitleOpacity)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, PulseDesign.spacing12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(navigationForeground(isSelected: isSelected))
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
                navigationGlyph(for: section, isSelected: isSelected)

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
            .foregroundStyle(navigationForeground(isSelected: isSelected))
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
            .fill(PulseDesign.quietGreen)
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
                .fill(isSelected ? PulseDesign.quietSurface : Color.clear)
            Circle()
                .stroke(
                    isSelected
                        ? PulseDesign.quietSurface
                        : PulseDesign.quietChromeForeground.opacity(0.46),
                    lineWidth: PulseDesign.thinLineWidth
                )

            navigationGlyphContent(for: section)
        }
        .frame(width: resolvedGlyphSize, height: resolvedGlyphSize)
        .foregroundStyle(navigationForeground(isSelected: isSelected))
        .accessibilityHidden(true)
    }

    private func navigationForeground(isSelected: Bool) -> Color {
        isSelected ? PulseDesign.quietOnGreen : PulseDesign.quietChromeForeground
    }

    private var resolvedGlyphSize: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? min(glyphSize, PulseDesign.accessibilityNavigationGlyphMaximum)
            : glyphSize
    }

    @ViewBuilder
    private func navigationGlyphContent(for section: PulsePrimarySection) -> some View {
        switch section {
        case .today:
            if let todayDayNumber {
                Text(todayDayNumber, format: .number)
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        case .history:
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .bold))
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
