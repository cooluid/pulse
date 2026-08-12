import PulseCore
import SwiftUI

struct EnhancementStoreView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.locale) private var locale

    var body: some View {
        ZStack {
            PulsePosterBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing32) {
                    hero
                    stylePreviews
                    capabilityList
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
        .toolbarBackground(PulseDesign.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            purchaseDock
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing16) {
            PulseBrandMark(size: PulseDesign.storeBrandMarkSize)

            Text("store.title")
                .font(.system(size: PulseDesign.storeHeroTitleSize, weight: .black))
                .tracking(-2)
                .foregroundStyle(PulseDesign.ink)

            Text("store.hero.tagline")
                .font(.title2.weight(.black))
                .foregroundStyle(PulseDesign.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("store.hero.promise")
                .font(.body.weight(.medium))
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store.hero")
    }

    private var stylePreviews: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            Text("store.preview.section")
                .font(.caption.weight(.black))
                .textCase(.uppercase)
                .foregroundStyle(PulseDesign.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: PulseDesign.spacing12) {
                    ForEach(PulseWidgetStyle.allCases) { style in
                        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
                            PulseWidgetStylePreview(
                                style: style,
                                dayNumber: model.today?.day,
                                commitmentName: model.habit?.name
                            )
                            .frame(
                                width: PulseDesign.storePreviewWidth,
                                height: PulseDesign.storePreviewHeight
                            )

                            Text(style.localizedName(locale: locale))
                                .font(.caption.weight(.black))
                                .foregroundStyle(PulseDesign.ink)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var capabilityList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("store.capabilities.section")
                .font(.caption.weight(.black))
                .textCase(.uppercase)
                .foregroundStyle(PulseDesign.secondary)
                .padding(.bottom, PulseDesign.spacing8)

            ForEach(PulseEnhancementContract.currentCapabilities) { capability in
                HStack(alignment: .top, spacing: PulseDesign.spacing16) {
                    Image(systemName: capability.systemImage)
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseDesign.action)
                        .frame(
                            width: PulseDesign.storeCapabilityIconSize,
                            height: PulseDesign.storeCapabilityIconSize
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: PulseDesign.spacing4) {
                        Text(capability.titleKey)
                            .font(.headline.weight(.black))
                            .foregroundStyle(PulseDesign.ink)
                        Text(capability.detailKey)
                            .font(.footnote)
                            .foregroundStyle(PulseDesign.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, PulseDesign.spacing16)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(PulseDesign.separator)
                        .frame(height: PulseDesign.thinLineWidth)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("store.capability.\(capability.rawValue)")
            }
        }
    }

    private var purchaseDock: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing16) {
            purchaseState

            if !model.featureAccess.hasEnhancement {
                Button("store.restore") {
                    Task { await model.restoreEnhancement() }
                }
                .disabled(model.featureAccess.operation != nil)
                .accessibilityIdentifier("store.restore")
            }
        }
        .frame(maxWidth: PulseDesign.screenMaxWidth, alignment: .leading)
        .padding(.horizontal, PulseDesign.horizontalPadding)
        .padding(.vertical, PulseDesign.spacing12)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(PulseDesign.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(PulseDesign.ink).frame(height: PulseDesign.emphasisLineWidth)
        }
    }

    @ViewBuilder
    private var purchaseState: some View {
        if model.featureAccess.hasEnhancement {
            Label("store.purchased", systemImage: "checkmark.seal.fill")
                .font(.title3.weight(.black))
                .foregroundStyle(PulseDesign.grass)
                .accessibilityIdentifier("store.status")
        } else if let operation = model.featureAccess.operation {
            switch operation {
            case .purchasing, .restoring:
                ProgressView("store.processing")
                    .accessibilityIdentifier("store.processing")
            case .pending:
                Label("store.pending", systemImage: "hourglass")
                    .foregroundStyle(PulseDesign.secondary)
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
                        .font(.headline.weight(.black))
                        .foregroundStyle(PulseDesign.actionForeground)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: PulseDesign.storePurchaseButtonMinimumHeight
                        )
                    }
                    .buttonStyle(.plain)
                    .background(PulseDesign.action)
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
            }
        }
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
