import SwiftUI

struct VisualThemePickerView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @State private var showsStore = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 20) {
                ForEach(PulseVisualTheme.allCases) { theme in
                    PulseVisualThemeChoice(
                        theme: theme,
                        model: model,
                        isSelected: model.resolvedVisualTheme == theme,
                        isLocked:
                            PulseVisualThemeAccessPolicy
                            .requiresEnhancement(theme)
                            && !model.featureAccess.hasEnhancement,
                        locale: locale
                    ) {
                        if !model.requestVisualTheme(theme) {
                            showsStore = true
                        }
                    }
                }
            }
            .padding(.horizontal, PulseDesign.horizontalPadding)
            .padding(.top, PulseDesign.spacing16)
            .padding(.bottom, PulseDesign.spacing32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(PulseScreenBackground())
        .foregroundStyle(PulseDesign.appInk(for: visualTheme))
        .tint(PulseDesign.appAccent(for: visualTheme))
        .navigationTitle(PulseLocalization.string("settings.visual_theme", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .navigationDestination(isPresented: $showsStore) {
            EnhancementStoreView(model: model)
        }
        .id("settings.visual-theme.\(locale.identifier)")
    }
}

private struct PulseVisualThemeChoice: View {
    let theme: PulseVisualTheme
    let model: PulseAppModel
    let isSelected: Bool
    let isLocked: Bool
    let locale: Locale
    let action: () -> Void
    @Environment(\.pulseVisualTheme) private var currentTheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                PulseVisualThemeSpecimen(theme: theme, model: model)

                HStack(alignment: .top, spacing: PulseDesign.spacing12) {
                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(theme.localizedName(locale: locale))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseDesign.appInk(for: currentTheme))

                    }

                    Spacer(minLength: 0)

                    if isLocked {
                        Label("widget.gallery.locked", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PulseDesign.appAccent(for: currentTheme))
                            .frame(minHeight: PulseDesign.minimumHitTarget)
                            .accessibilityIdentifier(
                                "settings.visual-theme.\(theme.rawValue).locked"
                            )
                    } else {
                        ZStack {
                            Circle()
                                .fill(isSelected ? selectionColor : .clear)
                            Circle()
                                .stroke(
                                    isSelected
                                        ? selectionColor
                                        : PulseDesign.appDivider(for: currentTheme),
                                    lineWidth: PulseDesign.emphasisLineWidth
                                )
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(PulseDesign.appAccentForeground(for: theme))
                            }
                        }
                        .frame(width: PulseDesign.spacing24, height: PulseDesign.spacing24)
                        .accessibilityHidden(true)
                    }
                }
            }
            .padding(PulseDesign.spacing12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PulseDesign.appSurface(for: currentTheme),
                in: RoundedRectangle(
                    cornerRadius: PulseDesign.spacing20,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PulseDesign.spacing20,
                    style: .continuous
                )
                .stroke(
                    selectionColor.opacity(
                        isSelected ? 1 : PulseDesign.themePreviewUnselectedBorderOpacity
                    ),
                    lineWidth: isSelected
                        ? PulseDesign.emphasisLineWidth
                        : PulseDesign.thinLineWidth
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(theme.localizedName(locale: locale))
        .accessibilityValue(isLocked ? Text("widget.gallery.locked") : Text(verbatim: ""))
        .accessibilityHint(
            isLocked ? Text("widget.gallery.enhancement.hint") : Text(verbatim: "")
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("settings.visual-theme.\(theme.rawValue)")
    }

    private var selectionColor: Color {
        PulseDesign.appAccent(for: theme)
    }
}
