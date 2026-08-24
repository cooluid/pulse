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
            PulseFieldBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing32) {
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
        .toolbarBackground(
            PulseDesign.appChromeBackground(for: visualTheme),
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
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
            PulseDesign.appSurface(for: visualTheme).opacity(0.82),
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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    themeSpecimenCards
                }
            } else {
                HStack(alignment: .top, spacing: PulseDesign.spacing12) {
                    themeSpecimenCards
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var themeSpecimenCards: some View {
        ForEach(PulseVisualThemeAccessPolicy.enhancementThemes) { theme in
            storeThemeSpecimen(theme)
                .frame(maxWidth: .infinity)
        }
    }

    private func storeThemeSpecimen(_ theme: PulseVisualTheme) -> some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            PulseVisualThemeSpecimen(theme: theme)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: PulseDesign.themePreviewCornerRadius,
                        style: .continuous
                    )
                    .stroke(
                        PulseDesign.appDivider(for: theme).opacity(0.72),
                        lineWidth: PulseDesign.thinLineWidth
                    )
                }

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

    @ViewBuilder
    private var hero: some View {
        switch visualTheme {
        case .sunlitDay:
            sunlitHero
        case .editorialJournal:
            quietHero
        case .quietField:
            playfulQuietHero
        }
    }

    private var quietHero: some View {
        HStack(alignment: .center, spacing: PulseDesign.spacing16) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                Label("store.lifetime_badge", systemImage: "leaf.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.grassForeground)
                    .padding(.horizontal, PulseDesign.spacing12)
                    .padding(.vertical, PulseDesign.spacing8)
                    .background(PulseDesign.grass, in: Capsule())

                Text("store.hero.tagline")
                    .font(.title2.weight(.black))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text("store.hero.scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PulseBrandMark(size: PulseDesign.brandMarkSize)
                .accessibilityHidden(true)
        }
        .padding(PulseDesign.spacing20)
        .background(
            PulseDesign.surface.opacity(0.90),
            in: RoundedRectangle(
                cornerRadius: PulseDesign.storeHeroCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.storeHeroCornerRadius,
                style: .continuous
            )
            .stroke(PulseDesign.separator.opacity(0.72), lineWidth: PulseDesign.thinLineWidth)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: PulseDesign.storeHeroCornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.hero")
    }

    private var playfulQuietHero: some View {
        HStack(alignment: .center, spacing: PulseDesign.spacing16) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                Label("store.lifetime_badge", systemImage: "sparkles")
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .foregroundStyle(PulseDesign.quietOnGreen)
                    .padding(.horizontal, PulseDesign.spacing12)
                    .padding(.vertical, PulseDesign.spacing8)
                    .background(PulseDesign.quietYellow, in: Capsule())

                Text("store.hero.tagline")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(PulseDesign.quietInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text("store.hero.scope")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PulseDesign.quietMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Image(systemName: "sparkle")
                    .font(.system(size: PulseDesign.spacing16, weight: .black))
                    .foregroundStyle(PulseDesign.quietPink)
                    .offset(x: PulseDesign.spacing24, y: -PulseDesign.spacing24)

                PulseBrandMark(size: PulseDesign.storeBrandMarkSize)
            }
            .accessibilityHidden(true)
        }
        .padding(PulseDesign.spacing20)
        .background {
            PulseQuietSpeechBubbleShape()
                .fill(PulseDesign.quietSurface)
        }
        .overlay {
            PulseQuietSpeechBubbleShape()
                .stroke(PulseDesign.quietDivider, lineWidth: PulseDesign.thinLineWidth)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.hero")
    }

    private var sunlitHero: some View {
        HStack(alignment: .center, spacing: PulseDesign.spacing16) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                Label("store.lifetime_badge", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(PulseDesign.sunlitChromeForeground)
                    .padding(.horizontal, PulseDesign.spacing12)
                    .padding(.vertical, PulseDesign.spacing8)
                    .background(
                        PulseDesign.sunlitChrome,
                        in: Capsule()
                    )

                Text("store.hero.tagline")
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text("store.hero.scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                PulseSunlitMapTexture(opacity: 0.34)
                    .frame(width: 84, height: 84)

                PulseBrandMark(size: PulseDesign.storeBrandMarkSize)
            }
            .accessibilityHidden(true)
        }
        .padding(PulseDesign.spacing20)
        .background(
            PulseDesign.sunlitSurface,
            in: RoundedRectangle(
                cornerRadius: PulseDesign.sunlitCardCornerRadius,
                style: .continuous
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.hero")
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
            .padding(.horizontal, PulseDesign.primaryNavigationHorizontalInset)
            .padding(.vertical, PulseDesign.spacing8)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .background(PulseDesign.appSurface(for: visualTheme))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PulseDesign.appDivider(for: visualTheme))
                    .frame(height: PulseDesign.thinLineWidth)
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
        VStack(alignment: .leading, spacing: PulseDesign.spacing16) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                Text(verbatim: activityString("store.activity.preview.signature"))
                    .font(.title2.weight(.black))
                    .foregroundStyle(PulseDesign.appInk(for: visualTheme))

                Text(verbatim: activityString("store.activity.preview.section"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            }
            .accessibilityElement(children: .combine)
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
                PulseWidgetDesign.activityLockScreenBackground,
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

    private func compactPreview(phase: PulseReminderActivityPhase) -> some View {
        PulseReminderActivityMark(
            phase: phase,
            layout: .islandCompact
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
            layout: .islandMinimal
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
            "waveform.path.ecg.rectangle.fill"
        }
    }
}
