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

    private var usesPaperNavigation: Bool { theme == .editorialJournal || theme == .sunlitDay }

    var body: some View {
        HStack(spacing: 8) {
            navigationButton(.today)
            if usesPaperNavigation {
                Rectangle().fill(PulseDesign.appDivider(for: theme)).frame(width: 1, height: 36)
            }
            navigationButton(.history)
        }
        .padding(6)
        .frame(maxWidth: 420)
        .background {
            if !usesPaperNavigation {
                Capsule().fill(PulseDesign.appSurface(for: theme))
            }
        }
        .padding(.horizontal, PulseDesign.horizontalPadding)
        .padding(.vertical, usesPaperNavigation ? 2 : 8)
        .frame(maxWidth: .infinity)
        .background(PulseScreenBackground())
        .overlay(alignment: .top) {
            Rectangle().fill(PulseDesign.appDivider(for: theme)).frame(height: 1)
        }
    }

    private func navigationButton(_ section: PulsePrimarySection) -> some View {
        let selected = selection == section
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                selection = section
            }
        } label: {
            Group {
                if usesPaperNavigation {
                    VStack(spacing: 5) {
                        Image(systemName: section == .today
                              ? (selected ? "circle.fill" : "circle")
                              : (selected ? "text.book.closed.fill" : "text.book.closed"))
                            .font(.system(size: 22, weight: .regular))
                        Text(section == .today ? "tab.today" : "tab.history")
                            .font(.caption.weight(selected ? .semibold : .regular))
                    }
                } else {
                    Label(section == .today ? "tab.today" : "tab.history",
                          systemImage: section == .today ? "circle" : "text.book.closed")
                        .font(.subheadline.weight(selected ? .semibold : .regular))
                }
            }
                .foregroundStyle(selected
                                 ? (usesPaperNavigation ? PulseDesign.appAccent(for: theme) : PulseDesign.appInk(for: theme))
                                 : PulseDesign.appMuted(for: theme))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: PulseDesign.minimumHitTarget)
                .background(selected && !usesPaperNavigation ? PulseDesign.appAccentSoft(for: theme) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primary.navigation.\(section.rawValue)")
        .accessibilityValue(section == .today && isTodayChecked ? Text("today.navigation.checked") : Text(verbatim: ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
