import SwiftUI

struct VisualThemePickerView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme
    @State private var showsStore = false
    @State private var previewTheme: PulseVisualTheme?
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
                        locale: locale,
                        onPreview: { previewTheme = theme }
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
        .sheet(item: $previewTheme) { theme in
            PulseExpandedThemePreview(theme: theme, model: model)
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
    let onPreview: () -> Void
    let action: () -> Void
    @Environment(\.pulseVisualTheme) private var currentTheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            selectionButton
            Button(action: onPreview) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.appInk(for: currentTheme))
                    .frame(width: 36, height: 36)
                    .background(PulseDesign.appSurface(for: currentTheme), in: Circle())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel(previewTitle)
            .accessibilityIdentifier("settings.visual-theme.preview.\(theme.rawValue)")
        }
    }

    private var selectionButton: some View {
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
        .accessibilityRepresentation {
            Button(theme.localizedName(locale: locale), action: action)
                .accessibilityValue(isLocked ? Text("widget.gallery.locked") : Text(verbatim: ""))
                .accessibilityHint(isLocked ? Text("widget.gallery.enhancement.hint") : Text(verbatim: ""))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityAction(named: Text(previewTitle), onPreview)
                .accessibilityIdentifier("settings.visual-theme.\(theme.rawValue)")
        }
    }

    private var selectionColor: Color {
        PulseDesign.appAccent(for: theme)
    }

    private var previewTitle: String {
        String(format: PulseLocalization.string("settings.visual_theme.preview", locale: locale),
               theme.localizedName(locale: locale))
    }
}

private struct PulseExpandedThemePreview: View {
    let theme: PulseVisualTheme
    let model: PulseAppModel
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var inheritedColorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                PulseVisualThemeSpecimen(theme: theme, model: model)
                    .accessibilityRepresentation {
                        Text(theme.localizedDescription(locale: locale))
                    }
                    .frame(maxWidth: 390)
                    .padding(16)
                    .frame(maxWidth: .infinity)
            }
            .background(PulseScreenBackground())
            .navigationTitle(theme.localizedName(locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                        .accessibilityIdentifier("settings.visual-theme.preview.close")
                }
            }
        }
        .environment(\.pulseVisualTheme, theme)
        .tint(PulseDesign.appAccent(for: theme))
        .preferredColorScheme(PulseThemeAppearance.previewColorScheme(
            theme: theme, appearance: model.settings.theme, inherited: inheritedColorScheme
        ))
    }
}
