import PulseCore
import SwiftUI

struct EditorialAccentLine: View {
    let isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(isExpanded ? PulseDesign.editorialAccent : PulseDesign.separator)
                .frame(
                    width: isExpanded ? proxy.size.width : PulseDesign.editorialLineInitialWidth,
                    height: PulseDesign.editorialLineHeight,
                    alignment: .leading
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeOut(duration: PulseDesign.editorialAccentExpansionDuration),
                    value: isExpanded
                )
        }
        .frame(height: PulseDesign.editorialLineHeight)
        .accessibilityHidden(true)
    }
}

struct EditorialRecordDetailIdentity: View {
    let day: LogicalDay
    let record: CheckInRecordSnapshot?
    let habitName: String?
    let timeZone: TimeZone

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            Text(
                PulseFormatting.fullDate(day, timeZone: timeZone, locale: locale)
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(PulseDesign.secondary)
            .textCase(.uppercase)
            .tracking(PulseDesign.editorialKickerTracking)

            if let habitName {
                Text(habitName)
                    .font(.system(.title, design: .serif).weight(.bold))
                    .foregroundStyle(PulseDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(PulseDesign.editorialAccent)
                .frame(height: PulseDesign.editorialLineHeight)

            if let record {
                Text(
                    String(
                        format: PulseLocalization.string(
                            "history.checked_at",
                            locale: locale
                        ),
                        PulseFormatting.time(
                            record.checkedAt,
                            timeZone: record.timeZone,
                            locale: locale
                        )
                    )
                )
                .font(.caption)
                .foregroundStyle(PulseDesign.secondary)
                .padding(.top, PulseDesign.spacing8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("history.record.detail.identity")
    }

}
