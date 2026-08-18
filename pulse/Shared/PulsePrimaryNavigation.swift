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
        case .tideArchive:
            archiveNavigation
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

    private var archiveNavigation: some View {
        archiveNavigationLayout
            .frame(maxWidth: PulseDesign.primaryNavigationMaxWidth)
            .padding(.horizontal, PulseDesign.horizontalPadding)
            .padding(.top, PulseDesign.spacing4)
            .padding(.bottom, PulseDesign.spacing4)
            .frame(maxWidth: .infinity)
            .background {
                PulseDesign.archiveSurface
                    .opacity(PulseDesign.archiveBarSurfaceOpacity)
                    .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PulseDesign.archiveDivider)
                    .frame(height: PulseDesign.thinLineWidth)
            }
    }

    @ViewBuilder
    private var archiveNavigationLayout: some View {
        HStack(spacing: PulseDesign.spacing32) {
            archiveNavigationButton(for: .today)
            archiveNavigationButton(for: .history)
        }
        .frame(
            height: dynamicTypeSize.isAccessibilitySize
                ? PulseDesign.accessibilityNavigationMinimumHeight
                : PulseDesign.archiveBarHeight
        )
    }

    private func archiveNavigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section

        return Button {
            select(section)
        } label: {
            VStack(spacing: PulseDesign.spacing4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? PulseDesign.archiveAccentSoft : Color.clear)
                    Circle()
                        .stroke(
                            isSelected ? PulseDesign.archiveAccent : PulseDesign.archiveDivider,
                            lineWidth: isSelected
                                ? PulseDesign.emphasisLineWidth
                                : PulseDesign.thinLineWidth
                        )

                    navigationGlyphContent(for: section)
                        .foregroundStyle(
                            isSelected ? PulseDesign.archiveInk : PulseDesign.archiveMuted
                        )
                }
                .frame(width: resolvedGlyphSize, height: resolvedGlyphSize)
                .overlay(alignment: .topTrailing) {
                    if section == .today, isTodayChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(PulseDesign.archiveCanvas)
                            .frame(width: 13, height: 13)
                            .background(PulseDesign.archiveAccent, in: Circle())
                            .offset(x: 4, y: -3)
                            .accessibilityHidden(true)
                    }
                }

                Text(section == .today ? "tab.today" : "tab.history")
                    .font(.caption.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)

                Capsule()
                    .fill(isSelected ? PulseDesign.archiveAccent : Color.clear)
                    .frame(width: PulseDesign.spacing20, height: PulseDesign.emphasisLineWidth)
            }
            .foregroundStyle(isSelected ? PulseDesign.archiveInk : PulseDesign.archiveMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            navigationGlyphContent(for: section)
        }
        .frame(width: resolvedGlyphSize, height: resolvedGlyphSize)
        .foregroundStyle(navigationForeground(isSelected: isSelected))
        .accessibilityHidden(true)
    }

    private func navigationForeground(isSelected: Bool) -> Color {
        isSelected ? PulseDesign.grassForeground : PulseDesign.secondary
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
