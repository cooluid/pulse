import SwiftUI

enum PulsePrimarySection: String, CaseIterable, Identifiable {
    case today
    case history
    var id: Self { self }
}

/// Two places, floating over the page: today, and the record of every day before it.
struct PulsePrimaryNavigation: View {
    @Binding var selection: PulsePrimarySection
    let todayDayNumber: Int?
    let isTodayChecked: Bool

    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var selectionNamespace

    private var palette: PulseThemePalette { PulseDesign.palette(for: theme) }

    var body: some View {
        HStack(spacing: PulseDesign.spacing4) {
            navigationButton(.today)
            navigationButton(.history)
        }
        .padding(5)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : PulseDesign.primaryNavigationWidth)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 460 : nil)
        .pulseGlass(in: Capsule())
        .padding(.horizontal, PulseDesign.horizontalPadding)
        .padding(.top, PulseDesign.spacing8)
        .padding(.bottom, PulseDesign.primaryNavigationBottomInset)
        .frame(maxWidth: .infinity)
    }

    private func navigationButton(_ section: PulsePrimarySection) -> some View {
        let selected = selection == section
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                selection = section
            }
        } label: {
            VStack(spacing: 3) {
                icon(section, selected: selected)
                Text(section == .today ? "tab.today" : "tab.history")
                    .font(.caption2.weight(selected ? .semibold : .medium))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            .foregroundStyle(selected ? palette.ink : palette.muted)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: PulseDesign.primaryNavigationHeight - 10)
            .background {
                if selected {
                    Capsule()
                        .fill(palette.ink.opacity(0.08))
                        .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(section == .today && isTodayChecked ? Text("today.navigation.checked") : Text(verbatim: ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func icon(_ section: PulsePrimarySection, selected: Bool) -> some View {
        switch section {
        case .today:
            // Today's tab carries today's state: an empty place, or the seal.
            ZStack {
                if isTodayChecked {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(palette.seal)
                } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(palette.seal, style: StrokeStyle(lineWidth: 1.5, dash: [2.6, 2.1]))
                }
                if let todayDayNumber {
                    Text(todayDayNumber, format: .number)
                        .font(.system(size: 10.5, weight: .black, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(isTodayChecked ? palette.onSeal : palette.seal)
                }
            }
            .frame(width: 23, height: 23)
            .accessibilityHidden(true)
        case .history:
            Image(systemName: selected ? "square.grid.2x2.fill" : "square.grid.2x2")
                .font(.system(size: 19, weight: .medium))
                .frame(width: 23, height: 23)
                .accessibilityHidden(true)
        }
    }
}
