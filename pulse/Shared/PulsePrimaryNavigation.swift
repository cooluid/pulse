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
        if visualTheme == .tidalBreath {
            tidalNavigation
        } else {
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

    private var tidalNavigation: some View {
        sizedNavigation
            .background {
                RoundedRectangle(
                    cornerRadius: PulseDesign.primaryNavigationCornerRadius,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [PulseDesign.tidalBlueDeep, PulseDesign.tidalBlueDepth],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                    PulseDesign.tidalForeground.opacity(
                        PulseDesign.tidalNavigationBorderOpacity
                    ),
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
            Group {
                if visualTheme == .tidalBreath {
                    RoundedRectangle(
                        cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                        style: .continuous
                    )
                    .fill(PulseDesign.tidalForeground)
                } else {
                    RoundedRectangle(
                        cornerRadius: PulseDesign.primaryNavigationItemCornerRadius,
                        style: .continuous
                    )
                    .fill(PulseDesign.grass)
                }
            }
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
            Group {
                if visualTheme == .tidalBreath {
                    Circle()
                        .fill(
                            isSelected
                                ? PulseDesign.tidalBlueDeep.opacity(
                                    PulseDesign.tidalNavigationSelectedGlyphOpacity
                                )
                                : Color.clear
                        )
                    Circle()
                        .stroke(
                            navigationForeground(isSelected: isSelected),
                            lineWidth: isSelected
                                ? PulseDesign.emphasisLineWidth
                                : PulseDesign.thinLineWidth
                        )
                } else {
                    Circle()
                        .fill(isSelected ? PulseDesign.navigationGlyphSurface : Color.clear)
                    Circle()
                        .stroke(
                            isSelected ? PulseDesign.navigationGlyphSurface : PulseDesign.secondary,
                            lineWidth: PulseDesign.thinLineWidth
                        )
                }
            }

            navigationGlyphContent(for: section)
        }
        .frame(width: resolvedGlyphSize, height: resolvedGlyphSize)
        .foregroundStyle(navigationForeground(isSelected: isSelected))
        .accessibilityHidden(true)
    }

    private func navigationForeground(isSelected: Bool) -> Color {
        if visualTheme == .tidalBreath {
            return isSelected
                ? PulseDesign.tidalBlueDepth
                : PulseDesign.tidalForeground.opacity(
                    PulseDesign.tidalNavigationUnselectedOpacity
                )
        }
        return isSelected ? PulseDesign.grassForeground : PulseDesign.secondary
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
                    .font(.caption2.bold())
                    .monospacedDigit()
            }
        case .history:
            Image(systemName: "calendar")
                .font(.caption2.bold())
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
