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
    @ScaledMetric(relativeTo: .title) private var sunlitGlyphDiameter =
        PulseDesign.sunlitNavigationGlyph
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
        case .moonTide, .prismLedger:
            ledgerNavigation
        }
    }

    private var ledgerNavigation: some View {
        HStack(spacing: 0) {
            ledgerNavigationButton(for: .today)
            ledgerNavigationButton(for: .history)
        }
        .frame(maxWidth: .infinity)
        .frame(
            height: dynamicTypeSize.isAccessibilitySize
                ? PulseDesign.accessibilityNavigationMinimumHeight
                : PulseDesign.ledgerNavigationHeight
        )
        .background(PulseDesign.appChromeBackground(for: visualTheme))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PulseDesign.appDivider(for: visualTheme))
                .frame(height: PulseDesign.thinLineWidth)
        }
    }

    private func ledgerNavigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section

        return Button {
            select(section)
        } label: {
            VStack(spacing: PulseDesign.spacing8) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? PulseDesign.appSurface(for: visualTheme)
                                : Color.clear
                        )
                    Circle()
                        .stroke(
                            isSelected
                                ? PulseDesign.appAccent(for: visualTheme)
                                : PulseDesign.appDivider(for: visualTheme),
                            lineWidth: isSelected
                                ? PulseDesign.emphasisLineWidth
                                : PulseDesign.thinLineWidth
                        )

                    navigationGlyphContent(for: section)
                }
                .frame(width: resolvedLedgerGlyphDiameter, height: resolvedLedgerGlyphDiameter)

                Text(section == .today ? "tab.today" : "tab.history")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(
                isSelected
                    ? PulseDesign.appInk(for: visualTheme)
                    : PulseDesign.appMuted(for: visualTheme)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    PulseDesign.appAccentSoft(for: visualTheme).opacity(
                        visualTheme == .moonTide ? 0.34 : 0.72
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(isSelected ? Text(subtitleKey(for: section)) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: PulseDesign.sunlitNavigationClusterGap) {
                    sunlitNavigationButton(for: .today)
                    sunlitNavigationButton(for: .history)
                }
            } else {
                HStack {
                    Spacer(minLength: 0)
                    HStack(spacing: PulseDesign.sunlitNavigationClusterGap) {
                        sunlitNavigationButton(for: .today)
                        sunlitNavigationButton(for: .history)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, PulseDesign.primaryNavigationHorizontalInset)
        .padding(.top, PulseDesign.spacing8)
        .padding(.bottom, PulseDesign.spacing12)
        .frame(maxWidth: .infinity)
    }

    private func sunlitNavigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section

        return Button {
            select(section)
        } label: {
            VStack(spacing: PulseDesign.spacing8) {
                ZStack {
                    Circle()
                        .fill(PulseDesign.sunlitSurface)
                        .shadow(
                            color: PulseDesign.shadow.opacity(
                                PulseDesign.sunlitNavigationShadowOpacity
                            ),
                            radius: PulseDesign.sunlitNavigationShadowRadius,
                            y: PulseDesign.sunlitNavigationShadowY
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    isSelected
                                        ? PulseDesign.sunlitAccent
                                        : PulseDesign.sunlitDivider,
                                    lineWidth: isSelected
                                        ? PulseDesign.emphasisLineWidth
                                        : PulseDesign.thinLineWidth
                                )
                        }

                    sunlitGlyphContent(for: section)
                        .foregroundStyle(
                            isSelected
                                ? PulseDesign.sunlitInk
                                : PulseDesign.sunlitMuted
                        )
                }
                .frame(
                    width: resolvedSunlitGlyphDiameter,
                    height: resolvedSunlitGlyphDiameter
                )
                .overlay(alignment: .topTrailing) {
                    if section == .today, isTodayChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(PulseDesign.sunlitChromeForeground)
                            .frame(width: 16, height: 16)
                            .background(PulseDesign.sunlitChrome, in: Circle())
                            .offset(x: 2, y: -2)
                            .accessibilityHidden(true)
                    }
                }

                Text(section == .today ? "tab.today" : "tab.history")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(
                        isSelected
                            ? PulseDesign.sunlitInk
                            : PulseDesign.sunlitMuted
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(
                minWidth: PulseDesign.minimumHitTarget,
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(isSelected ? Text(subtitleKey(for: section)) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func sunlitGlyphContent(for section: PulsePrimarySection) -> some View {
        switch section {
        case .today:
            if let todayDayNumber {
                Text(todayDayNumber, format: .number)
                    .font(
                        .system(
                            size: resolvedSunlitGlyphDiameter * 0.34,
                            weight: .black,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        case .history:
            Image(systemName: "calendar")
                .font(
                    .system(
                        size: resolvedSunlitGlyphDiameter * 0.34,
                        weight: .bold
                    )
                )
        }
    }

    private var resolvedSunlitGlyphDiameter: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? min(
                sunlitGlyphDiameter,
                PulseDesign.sunlitNavigationGlyphAccessibilityMaximum
            )
            : sunlitGlyphDiameter
    }

    private var resolvedLedgerGlyphDiameter: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? PulseDesign.accessibilityNavigationGlyphMaximum
            : PulseDesign.ledgerNavigationGlyph
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
