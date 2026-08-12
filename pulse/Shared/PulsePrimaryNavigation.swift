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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var navigationHeight = PulseDesign.primaryNavigationHeight

    var body: some View {
        HStack(spacing: 0) {
            navigationButton(for: .today)
            navigationButton(for: .history)
        }
        .frame(
            height: dynamicTypeSize.isAccessibilitySize
                ? PulseDesign.accessibilityNavigationMinimumHeight
                : navigationHeight
        )
        .background(PulseDesign.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PulseDesign.ink)
                .frame(height: PulseDesign.emphasisLineWidth)
        }
    }

    private func navigationButton(for section: PulsePrimarySection) -> some View {
        let isSelected = selection == section
        let isCompletedToday = section == .today && isTodayChecked
        let selectedBackground = isCompletedToday ? PulseDesign.grass : PulseDesign.action
        let selectedForeground = isCompletedToday
            ? PulseDesign.grassForeground
            : PulseDesign.actionForeground

        return Button {
            select(section)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing8) {
                if let value = glyphValue(for: section) {
                    Text(value, format: .number)
                        .font(.title2.weight(.black))
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text(section == .today ? "tab.today" : "tab.history")
                    .font(.caption.weight(.black))
                    .textCase(.uppercase)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            .padding(.horizontal, PulseDesign.spacing12)
            .padding(.vertical, PulseDesign.spacing12)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isSelected ? selectedForeground : PulseDesign.ink)
            .background(isSelected ? selectedBackground : PulseDesign.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            if section == .history {
                Rectangle()
                    .fill(PulseDesign.ink)
                    .frame(width: PulseDesign.thinLineWidth)
            }
        }
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(isSelected ? Text(selectedStateKey(for: section)) : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ section: PulsePrimarySection) {
        guard selection != section else { return }
        if reduceMotion {
            selection = section
        } else {
            withAnimation(.easeOut(duration: PulseDesign.primaryContentTransitionDuration)) {
                selection = section
            }
        }
    }

    private func glyphValue(for section: PulsePrimarySection) -> Int? {
        switch section {
        case .today: todayDayNumber
        case .history: historyMonthNumber
        }
    }

    private func selectedStateKey(for section: PulsePrimarySection) -> LocalizedStringKey {
        switch section {
        case .today:
            isTodayChecked ? "today.navigation.checked" : "today.navigation.pending"
        case .history:
            "history.navigation.subtitle"
        }
    }
}
