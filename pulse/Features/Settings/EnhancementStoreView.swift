import PulseCore
import SwiftUI

struct EnhancementStoreView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        ZStack {
            PulseScreenBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing24) {
                    hero
                    ForEach(PulseEnhancementContract.currentCapabilities) { capability in
                        capabilityCard(capability)
                    }
                    restoreSection
                }
                .frame(maxWidth: PulseDesign.screenMaxWidth, alignment: .leading)
                .padding(.horizontal, PulseDesign.horizontalPadding)
                .padding(.vertical, PulseDesign.spacing24)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("store.navigation_title")
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .tint(PulseDesign.appAccent(for: visualTheme))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            purchaseAction
        }
    }

    private func capabilityCard(_ capability: PulseEnhancementCapability) -> some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing16) {
            capabilityHeader(capability)
            capabilitySpecimen(capability)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: PulseDesign.storeCapabilityMinimumHeight,
            alignment: .topLeading
        )
        .padding(PulseDesign.spacing16)
        .background(
            PulseDesign.appSurface(for: visualTheme),
            in: RoundedRectangle(
                cornerRadius: PulseDesign.storeCapabilityCornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.capability.\(capability.rawValue)")
    }

    private func capabilityHeader(_ capability: PulseEnhancementCapability) -> some View {
        HStack(alignment: .top, spacing: PulseDesign.spacing16) {
            Image(systemName: capability.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PulseDesign.appAccent(for: visualTheme))
                .frame(
                    width: PulseDesign.storeCapabilityIconSize,
                    height: PulseDesign.storeCapabilityIconSize
                )
                .background(
                    PulseDesign.appAccentSoft(for: visualTheme),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                Text(capability.titleKey)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                Text(capability.detailKey)
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func capabilitySpecimen(_ capability: PulseEnhancementCapability) -> some View {
        switch capability {
        case .interfaceThemes:
            themeSpecimens
        case .advancedWidgetCompositions:
            widgetSpecimens
        case .scheduledLiveActivity:
            PulseReminderActivityStoreCard(
                reminderDate: model.settings.reminderTime.pickerDate,
                timeZoneIdentifier: TimeZone.gmt.identifier,
                locale: locale
            )
        }
    }

    private var themeSpecimens: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            ForEach(PulseVisualThemeAccessPolicy.enhancementThemes) { theme in
                storeThemeSpecimen(theme)
            }
        }
        .allowsHitTesting(false)
    }

    private func storeThemeSpecimen(_ theme: PulseVisualTheme) -> some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            PulseVisualThemeSwatch(
                theme: theme,
                habitName: model.habit?.name,
                today: model.today,
                recentDays: model.recentDays
            )
            .clipShape(RoundedRectangle(cornerRadius: PulseDesign.themePreviewCornerRadius - 4, style: .continuous))

            Text(theme.localizedName(locale: locale))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseDesign.appInk(for: visualTheme))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(theme.localizedName(locale: locale))
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier(
            "store.capability.interfaceThemes.preview.\(theme.rawValue)"
        )
    }

    @ViewBuilder
    private var widgetSpecimens: some View {
        if let snapshot = model.widgetPresentationSnapshot {
            ScrollView(.horizontal) {
                HStack(spacing: PulseDesign.spacing12) {
                    ForEach(PulseWidgetStyleAccessPolicy.enhancementStyles) { style in
                        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                            PulseWidgetStylePreview(
                                style: style,
                                snapshot: snapshot
                            )
                            .frame(
                                width: PulseDesign.storePreviewWidth,
                                height: PulseDesign.storePreviewHeight
                            )
                            .allowsHitTesting(false)

                            Text(style.localizedName(locale: locale))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    /// Every theme's seal, laid side by side the way sample prints sit on a desk.
    private var hero: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
            HStack(spacing: -PulseDesign.spacing16) {
                ForEach(Array(PulseVisualTheme.allCases.enumerated()), id: \.element) { index, theme in
                    heroPrint(theme, index: index)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PulseDesign.spacing8)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                Label("store.lifetime_badge", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.appAccentForeground(for: visualTheme))
                    .padding(.horizontal, PulseDesign.spacing12)
                    .padding(.vertical, PulseDesign.spacing8)
                    .background(PulseDesign.appAccent(for: visualTheme), in: Capsule())

                Text("store.hero.tagline")
                    .font(PulseDesign.displayFont(size: 24, relativeTo: .title2).weight(.bold))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text("store.hero.scope")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(PulseDesign.spacing20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            PulseDesign.appSurface(for: visualTheme),
            in: RoundedRectangle(cornerRadius: PulseDesign.storeHeroCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.hero")
    }

    private func heroPrint(_ theme: PulseVisualTheme, index: Int) -> some View {
        let palette = PulseDesign.palette(for: theme)
        let seed = PulseSealSeed.value(for: theme.rawValue)
        let side: CGFloat = dynamicTypeSize.isAccessibilitySize ? 76 : 96
        return PulseSealImpression(inscription: .glyph("印"), ink: palette.seal, seed: seed)
            .padding(side * 0.16)
            .frame(width: side, height: side)
            .background(palette.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .rotationEffect(.degrees(Double(index - 1) * 7))
            .offset(y: index == 1 ? -6 : 4)
            .zIndex(index == 1 ? 1 : 0)
    }

    @ViewBuilder
    private var restoreSection: some View {
        if !model.featureAccess.hasEnhancement {
            Button("store.restore") {
                Task { await model.restoreEnhancement() }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(PulseDesign.appAccent(for: visualTheme))
            .frame(maxWidth: .infinity)
            .disabled(model.featureAccess.operation != nil)
            .accessibilityIdentifier("store.restore")
        }
    }

    private var purchaseAction: some View {
        purchaseState
            .frame(maxWidth: PulseDesign.screenMaxWidth, alignment: .leading)
            .padding(.horizontal, PulseDesign.horizontalPadding)
            .padding(.top, PulseDesign.spacing12)
            .padding(.bottom, PulseDesign.spacing8)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                LinearGradient(
                    colors: [
                        PulseDesign.appChromeBackground(for: visualTheme).opacity(0),
                        PulseDesign.appChromeBackground(for: visualTheme),
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
    }

    @ViewBuilder
    private var purchaseState: some View {
        if model.featureAccess.hasEnhancement {
            Label("store.purchased", systemImage: "checkmark.seal.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseDesign.appSuccess(for: visualTheme))
                .frame(maxWidth: .infinity, minHeight: PulseDesign.storePurchaseButtonMinimumHeight)
                .background(storeActionSurface, in: storeActionShape)
                .accessibilityIdentifier("store.status")
        } else if let operation = model.featureAccess.operation {
            switch operation {
            case .purchasing, .restoring:
                ProgressView("store.processing")
                    .frame(
                        maxWidth: .infinity, minHeight: PulseDesign.storePurchaseButtonMinimumHeight
                    )
                    .background(storeActionSurface, in: storeActionShape)
                    .accessibilityIdentifier("store.processing")
            case .pending:
                Label("store.pending", systemImage: "hourglass")
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    .frame(
                        maxWidth: .infinity, minHeight: PulseDesign.storePurchaseButtonMinimumHeight
                    )
                    .background(storeActionSurface, in: storeActionShape)
                    .accessibilityIdentifier("store.pending")
            }
        } else {
            switch model.featureAccess.productState {
            case .loading:
                ProgressView("store.loading")
                    .frame(maxWidth: .infinity, minHeight: PulseDesign.storePurchaseButtonMinimumHeight)
                    .accessibilityIdentifier("store.loading")
            case .available:
                if let product = model.featureAccess.product {
                    Button {
                        Task { await model.purchaseEnhancement() }
                    } label: {
                        Text(
                            String(
                                format: PulseLocalization.string(
                                    "store.buy_format", locale: locale),
                                product.displayPrice
                            )
                        )
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PulseDesign.appAccentForeground(for: visualTheme))
                        .frame(
                            maxWidth: .infinity,
                            minHeight: PulseDesign.storePurchaseButtonMinimumHeight
                        )
                    }
                    .buttonStyle(.plain)
                    .background(
                        PulseDesign.appAccent(for: visualTheme),
                        in: storeActionShape
                    )
                    .accessibilityLabel(product.displayName)
                    .accessibilityValue(product.displayPrice)
                    .accessibilityIdentifier("store.buy")
                }
            case .unavailable:
                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    Label("store.unavailable", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                        .accessibilityIdentifier("store.unavailable")
                    Button("store.retry") {
                        Task { await model.featureAccess.refresh() }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: PulseDesign.storePurchaseButtonMinimumHeight)
                .padding(.horizontal, PulseDesign.spacing16)
                .background(storeActionSurface, in: storeActionShape)
            }
        }
    }

    private var storeActionSurface: Color {
        PulseDesign.appSurface(for: visualTheme)
    }

    private var storeActionShape: AnyShape {
        AnyShape(Capsule())
    }
}
struct PulseReminderActivityStoreCard: View {
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            Text(verbatim: activityString("store.activity.preview.section"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                .accessibilityIdentifier("store.activity.preview.signature")

            PulseReminderActivityStoreShowcase(
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: locale
            )
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.activity.preview.section")
    }

    private func activityString(_ key: String) -> String {
        PulseLocalization.string(
            key,
            table: PulseLocalization.systemUITable,
            locale: locale
        )
    }

}

struct PulseReminderActivityStoreShowcase: View {
    let reminderDate: Date
    let timeZoneIdentifier: String
    let locale: Locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            specimenLabel("store.activity.preview.expanded")

            PulseReminderActivityPreview(
                phase: .pending,
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: locale
            )
            .frame(
                maxWidth: .infinity,
                minHeight: PulseDesign.activityStoreExpandedMinimumHeight
            )

            HStack(alignment: .top, spacing: PulseDesign.spacing8) {
                specimen("store.activity.preview.compact") {
                    compactPreview(phase: .pending)
                }
                .frame(maxWidth: .infinity)

                specimen("store.activity.preview.completed") {
                    compactPreview(phase: .completed)
                }
                .frame(maxWidth: .infinity)

                specimen("store.activity.preview.minimal") {
                    minimalPreview
                }
                .frame(width: PulseDesign.activityStoreMinimalDiameter + PulseDesign.spacing16)
            }

            specimenLabel("store.activity.preview.lock_screen")

            PulseReminderLockScreenView(
                phase: .pending,
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: locale
            )
            .frame(
                maxWidth: .infinity,
                minHeight: PulseDesign.activityStoreLockScreenMinimumHeight
            )
            .background(
                PulseWidgetDesign.paper,
                in: RoundedRectangle(
                    cornerRadius: PulseDesign.activityStoreSurfaceCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PulseDesign.activityStoreSurfaceCornerRadius,
                    style: .continuous
                )
                .stroke(
                    PulseDesign.appDivider(for: visualTheme).opacity(0.72),
                    lineWidth: PulseDesign.thinLineWidth
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func specimen<Content: View>(
        _ key: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
            specimenLabel(key)
            content()
        }
    }

    private func specimenLabel(_ key: String) -> some View {
        Text(verbatim: activityString(key))
            .font(.caption2.weight(.bold))
            .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            .lineLimit(1)
    }

    private var reminderDay: Int? {
        PulseReminderActivityDay.number(reminderDate: reminderDate, timeZoneIdentifier: timeZoneIdentifier)
    }

    private func compactPreview(phase: PulseReminderActivityPhase) -> some View {
        PulseReminderActivityMark(
            phase: phase,
            layout: .islandCompact,
            day: reminderDay
        )
        .frame(maxWidth: .infinity)
        .frame(height: PulseDesign.activityStoreCompactHeight)
        .background(PulseWidgetDesign.activityIslandBackground, in: Capsule())
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }

    private var minimalPreview: some View {
        PulseReminderActivityMark(
            phase: .pending,
            layout: .islandMinimal,
            day: reminderDay
        )
        .frame(
            width: PulseDesign.activityStoreMinimalDiameter,
            height: PulseDesign.activityStoreMinimalDiameter
        )
        .background(PulseWidgetDesign.activityIslandBackground, in: Circle())
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }

    private func activityString(_ key: String) -> String {
        PulseLocalization.string(
            key,
            table: PulseLocalization.systemUITable,
            locale: locale
        )
    }
}

private extension PulseEnhancementCapability {
    var titleKey: LocalizedStringKey {
        switch self {
        case .interfaceThemes:
            "store.capability.themes.title"
        case .advancedWidgetCompositions:
            "store.capability.widgets.title"
        case .scheduledLiveActivity:
            "store.capability.live_activity.title"
        }
    }

    var detailKey: LocalizedStringKey {
        switch self {
        case .interfaceThemes:
            "store.capability.themes.detail"
        case .advancedWidgetCompositions:
            "store.capability.widgets.detail"
        case .scheduledLiveActivity:
            "store.capability.live_activity.detail"
        }
    }

    var systemImage: String {
        switch self {
        case .interfaceThemes:
            "paintpalette.fill"
        case .advancedWidgetCompositions:
            "square.grid.2x2.fill"
        case .scheduledLiveActivity:
            "clock.badge.checkmark.fill"
        }
    }
}
