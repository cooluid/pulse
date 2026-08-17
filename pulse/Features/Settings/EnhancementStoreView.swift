import PulseCore
import SwiftUI

struct EnhancementStoreView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing32) {
                    hero
                    activityPreviews
                    stylePreviews
                    capabilityList
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
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(visualTheme.localizedName(locale: locale))
                .accessibilityIdentifier(
                    visualTheme == .tideArchive
                        ? "store.theme.tide-archive"
                        : "store.theme.quiet-field"
                )
        }
        .safeAreaInset(edge: .bottom, spacing: PulseDesign.spacing8) {
            purchaseAction
        }
    }

    private var activityPreviews: some View {
        PulseReminderActivityStoreCard(
            reminderDate: model.settings.reminderTime.pickerDate,
            timeZoneIdentifier: TimeZone.gmt.identifier,
            locale: locale
        )
    }

    @ViewBuilder
    private var hero: some View {
        if visualTheme == .tideArchive {
            archiveHero
        } else {
            quietHero
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
                    .foregroundStyle(PulseDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("store.hero.scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PulseBrandMark(size: PulseDesign.brandMarkSize)
                .accessibilityHidden(true)
        }
        .padding(PulseDesign.spacing20)
        .background(PulseDesign.surface.opacity(0.90), in: RoundedRectangle(
            cornerRadius: PulseDesign.storeHeroCornerRadius,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.storeHeroCornerRadius,
                style: .continuous
            )
            .stroke(PulseDesign.separator.opacity(0.72), lineWidth: PulseDesign.thinLineWidth)
        }
        .clipShape(RoundedRectangle(
            cornerRadius: PulseDesign.storeHeroCornerRadius,
            style: .continuous
        ))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.hero")
    }

    private var archiveHero: some View {
        HStack(alignment: .center, spacing: PulseDesign.spacing16) {
            VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                Label("store.lifetime_badge", systemImage: "seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.archiveNight)
                    .padding(.horizontal, PulseDesign.spacing12)
                    .padding(.vertical, PulseDesign.spacing8)
                    .background(
                        PulseDesign.archiveCopper,
                        in: Capsule()
                    )

                Text("store.hero.tagline")
                    .font(.title2.weight(.black))
                    .foregroundStyle(PulseDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("store.hero.scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PulseBrandMark(size: PulseDesign.brandMarkSize)
                .accessibilityHidden(true)
        }
        .padding(PulseDesign.spacing20)
        .background(PulseDesign.archivePaper)
        .clipShape(
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                style: .continuous
            )
            .stroke(
                PulseDesign.archiveCopper.opacity(
                    PulseDesign.archiveHistorySurfaceBorderOpacity
                ),
                lineWidth: PulseDesign.thinLineWidth
            )
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(PulseDesign.archiveCopper)
                .frame(width: PulseDesign.emphasisLineWidth)
                .padding(.vertical, PulseDesign.spacing16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.hero")
    }

    private var stylePreviews: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            Text("store.preview.section")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseDesign.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: PulseDesign.spacing12) {
                    ForEach(
                        PulseWidgetStyle.allCases.filter(
                            PulseWidgetStyleAccessPolicy.requiresEnhancement
                        )
                    ) { style in
                        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                            if let snapshot = model.widgetPresentationSnapshot {
                                PulseWidgetStylePreview(
                                    style: style,
                                    snapshot: snapshot
                                )
                                .frame(
                                    width: PulseDesign.storePreviewWidth,
                                    height: PulseDesign.storePreviewHeight
                                )
                            }

                            Text(style.localizedName(locale: locale))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseDesign.ink)
                        }
                        .padding(PulseDesign.spacing8)
                        .background(
                            PulseDesign.appSurface(for: visualTheme).opacity(0.84),
                            in: RoundedRectangle(
                                cornerRadius: PulseDesign.widgetPreviewCornerRadius,
                                style: .continuous
                            )
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var capabilityList: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            Text("store.capabilities.section")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseDesign.secondary)
                .padding(.bottom, PulseDesign.spacing8)

            ForEach(PulseEnhancementContract.currentCapabilities) { capability in
                HStack(alignment: .top, spacing: PulseDesign.spacing16) {
                    Image(systemName: capability.systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PulseDesign.appAccent(for: visualTheme))
                        .frame(
                            width: PulseDesign.storeCapabilityIconSize,
                            height: PulseDesign.storeCapabilityIconSize
                        )
                        .background(
                            visualTheme == .tideArchive
                                ? PulseDesign.archiveMist.opacity(0.24)
                                : PulseDesign.field.opacity(0.12),
                            in: Circle()
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(capability.titleKey)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PulseDesign.ink)
                        Text(capability.detailKey)
                            .font(.footnote)
                            .foregroundStyle(PulseDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: PulseDesign.storeCapabilityMinimumHeight,
                    alignment: .topLeading
                )
                .padding(PulseDesign.spacing16)
                .background(PulseDesign.appSurface(for: visualTheme).opacity(0.82), in: RoundedRectangle(
                    cornerRadius: PulseDesign.storeCapabilityCornerRadius,
                    style: .continuous
                ))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("store.capability.\(capability.rawValue)")
            }
        }
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
        .background(
            visualTheme == .tideArchive
                ? PulseDesign.archiveNight.opacity(
                    PulseDesign.archiveNavigationSurfaceOpacity
                )
                : PulseDesign.background.opacity(PulseDesign.navigationSurfaceOpacity)
        )
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
                    .frame(maxWidth: .infinity, minHeight: PulseDesign.storePurchaseButtonMinimumHeight)
                    .background(storeActionSurface, in: storeActionShape)
                    .accessibilityIdentifier("store.processing")
            case .pending:
                Label("store.pending", systemImage: "hourglass")
                    .foregroundStyle(PulseDesign.secondary)
                    .frame(maxWidth: .infinity, minHeight: PulseDesign.storePurchaseButtonMinimumHeight)
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
                                format: PulseLocalization.string("store.buy_format", locale: locale),
                                product.displayPrice
                            )
                        )
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(
                            visualTheme == .tideArchive
                                ? PulseDesign.archiveNight
                                : PulseDesign.actionForeground
                        )
                        .frame(
                            maxWidth: .infinity,
                            minHeight: PulseDesign.storePurchaseButtonMinimumHeight
                        )
                    }
                    .buttonStyle(.plain)
                    .background(
                        visualTheme == .tideArchive
                            ? PulseDesign.archiveForeground
                            : PulseDesign.action,
                        in: storeActionShape
                    )
                    .shadow(color: PulseDesign.shadow.opacity(0.12), radius: 16, y: 6)
                    .accessibilityLabel(product.displayName)
                    .accessibilityValue(product.displayPrice)
                    .accessibilityIdentifier("store.buy")
                }
            case .unavailable:
                VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
                    Label("store.unavailable", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(PulseDesign.secondary)
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
        visualTheme == .tideArchive ? PulseDesign.archiveForeground : PulseDesign.surface
    }

    private var storeActionShape: AnyShape {
        if visualTheme == .tideArchive {
            return AnyShape(
                RoundedRectangle(
                    cornerRadius: PulseDesign.archiveHistoryPanelCornerRadius,
                    style: .continuous
                )
            )
        }
        return AnyShape(Capsule())
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
                    .foregroundStyle(PulseDesign.ink)

                Text(verbatim: activityString("store.activity.preview.section"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseDesign.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("store.activity.preview.signature")

            PulseReminderActivityStoreShowcase(
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: locale
            )
        }
        .padding(PulseDesign.spacing16)
        .background(
            visualTheme == .tideArchive
                ? PulseDesign.archivePaper
                : PulseDesign.surface.opacity(0.90),
            in: RoundedRectangle(
                cornerRadius: cardCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: cardCornerRadius,
                style: .continuous
            )
            .stroke(
                visualTheme == .tideArchive
                    ? PulseDesign.archiveCopper.opacity(
                        PulseDesign.archiveHistorySurfaceBorderOpacity
                    )
                    : PulseDesign.separator.opacity(0.72),
                lineWidth: PulseDesign.thinLineWidth
            )
        }
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

    private var cardCornerRadius: CGFloat {
        visualTheme == .tideArchive
            ? PulseDesign.archiveHistoryPanelCornerRadius
            : PulseDesign.activityStoreCardCornerRadius
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
                    visualTheme == .tideArchive
                        ? PulseDesign.archiveCopper.opacity(
                            PulseDesign.archiveNavigationDividerOpacity
                        )
                        : PulseDesign.separator.opacity(0.54),
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
            .foregroundStyle(PulseDesign.secondary)
            .lineLimit(1)
    }

    private func compactPreview(phase: PulseReminderActivityPhase) -> some View {
        HStack(spacing: PulseDesign.spacing8) {
            PulseReminderActivityMark(
                phase: phase,
                layout: .islandCompact
            )

            Spacer(minLength: PulseDesign.activityStoreCompactMinimumSpacing)

            PulseReminderActivityCompactTrailing(
                phase: phase,
                reminderDate: reminderDate,
                timeZoneIdentifier: timeZoneIdentifier,
                locale: locale
            )
        }
        .padding(.horizontal, PulseDesign.activityStoreCompactHorizontalInset)
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
        case .advancedWidgetCompositions:
            "store.capability.widgets.title"
        case .scheduledLiveActivity:
            "store.capability.live_activity.title"
        }
    }

    var detailKey: LocalizedStringKey {
        switch self {
        case .advancedWidgetCompositions:
            "store.capability.widgets.detail"
        case .scheduledLiveActivity:
            "store.capability.live_activity.detail"
        }
    }

    var systemImage: String {
        switch self {
        case .advancedWidgetCompositions:
            "square.grid.2x2.fill"
        case .scheduledLiveActivity:
            "waveform.path.ecg.rectangle.fill"
        }
    }
}
