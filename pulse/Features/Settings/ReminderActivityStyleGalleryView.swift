import PulseCore
import SwiftUI

struct ReminderActivityStyleGalleryView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.locale) private var locale
    @State private var previewPhase = PulseReminderActivityPhase.pending

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing24) {
                    introduction
                    phasePicker

                    ForEach(PulseReminderActivityStyle.allCases) { style in
                        styleCard(style)
                    }
                }
                .frame(maxWidth: PulseDesign.screenMaxWidth, alignment: .leading)
                .padding(.horizontal, PulseDesign.horizontalPadding)
                .padding(.vertical, PulseDesign.spacing24)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(systemString("settings.activity.style.navigation_title"))
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .toolbarBackground(PulseDesign.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            Text(verbatim: systemString("settings.activity.style.title"))
                .font(.largeTitle.bold())
                .foregroundStyle(PulseDesign.ink)
            Text(verbatim: systemString("settings.activity.style.detail"))
                .font(.body)
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var phasePicker: some View {
        Picker(systemString("settings.activity.style.preview_state"), selection: $previewPhase) {
            Text(verbatim: systemString("settings.activity.style.preview.pending"))
                .tag(PulseReminderActivityPhase.pending)
            Text(verbatim: systemString("settings.activity.style.preview.completed"))
                .tag(PulseReminderActivityPhase.completed)
        }
        .pickerStyle(.segmented)
    }

    private func styleCard(_ style: PulseReminderActivityStyle) -> some View {
        let isSelected = model.settings.reminderActivityStyle == style

        return Button {
            model.requestReminderActivityStyle(style)
        } label: {
            VStack(alignment: .leading, spacing: PulseDesign.spacing16) {
                HStack(alignment: .firstTextBaseline, spacing: PulseDesign.spacing12) {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(style.localizedName(locale: locale))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(PulseDesign.ink)
                        Text(style.localizedDescription(locale: locale))
                            .font(.subheadline)
                            .foregroundStyle(PulseDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: PulseDesign.spacing8)
                    if isSelected {
                        Label(
                            systemString("settings.activity.style.selected"),
                            systemImage: "checkmark.circle.fill"
                        )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseDesign.action)
                    }
                }

                PulseReminderActivityPreview(
                    style: style,
                    phase: previewPhase,
                    locale: locale
                )
                .frame(height: PulseDesign.activityGalleryPreviewHeight)
            }
            .padding(PulseDesign.spacing20)
            .background(
                PulseDesign.surface.opacity(isSelected ? 1 : 0.84),
                in: RoundedRectangle(
                    cornerRadius: PulseDesign.activityGalleryCardCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PulseDesign.activityGalleryCardCornerRadius,
                    style: .continuous
                )
                .stroke(
                    isSelected ? PulseDesign.grass : PulseDesign.separator,
                    lineWidth: isSelected
                        ? PulseDesign.emphasisLineWidth
                        : PulseDesign.thinLineWidth
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            isSelected
                ? systemString("settings.activity.style.selected")
                : ""
        )
        .accessibilityIdentifier("settings.activity.style.\(style.rawValue)")
    }

    private func systemString(_ key: String) -> String {
        PulseLocalization.string(
            key,
            table: PulseLocalization.systemUITable,
            locale: locale
        )
    }
}
