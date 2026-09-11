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

    @Environment(\.pulseVisualTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            navigationButton(.today)
            navigationButton(.history)
        }
        .padding(6)
        .frame(maxWidth: 420)
        .background(PulseDesign.appSurface(for: theme), in: Capsule())
        .overlay { Capsule().stroke(PulseDesign.appDivider(for: theme), lineWidth: 1) }
        .padding(.horizontal, PulseDesign.horizontalPadding)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func navigationButton(_ section: PulsePrimarySection) -> some View {
        let selected = selection == section
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                selection = section
            }
        } label: {
            Label(section == .today ? "tab.today" : "tab.history",
                  systemImage: section == .today ? "circle.dotted" : "calendar")
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? PulseDesign.appInk(for: theme) : PulseDesign.appMuted(for: theme))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: PulseDesign.minimumHitTarget)
                .background(selected ? PulseDesign.appAccentSoft(for: theme) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(section == .today && isTodayChecked ? Text("today.navigation.checked") : Text(verbatim: ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
