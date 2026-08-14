import PulseCore
import SwiftUI

struct WidgetStyleGalleryView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.locale) private var locale
    @State private var showsStore = false

    var body: some View {
        ZStack {
            PulseScreenBackground()
            PulseFieldBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                    galleryIntroduction

                    if let snapshot = model.widgetPresentationSnapshot {
                        LazyVGrid(columns: columns, spacing: PulseDesign.spacing20) {
                            ForEach(PulseWidgetStyle.allCases) { style in
                                styleCard(style, snapshot: snapshot)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "widget.gallery.unavailable.title",
                            systemImage: "exclamationmark.circle",
                            description: Text("widget.gallery.unavailable.message")
                        )
                    }
                }
                .frame(maxWidth: PulseDesign.historyMaxWidth, alignment: .leading)
                .padding(PulseDesign.horizontalPadding)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("widget.gallery.navigation_title")
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .navigationDestination(isPresented: $showsStore) {
            EnhancementStoreView(model: model)
        }
    }

    private var galleryIntroduction: some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing8) {
            Text("widget.gallery.introduction.title")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseDesign.ink)
            Text("widget.gallery.introduction.message")
                .font(.footnote)
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, PulseDesign.spacing4)
    }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: PulseDesign.spacing20), count: count)
    }

    @ViewBuilder
    private func styleCard(
        _ style: PulseWidgetStyle,
        snapshot: PulseWidgetSnapshot
    ) -> some View {
        let isLocked = PulseWidgetStyleAccessPolicy.requiresEnhancement(style)
            && !model.featureAccess.hasEnhancement

        if isLocked {
            Button {
                showsStore = true
            } label: {
                styleCardContent(style, snapshot: snapshot, isLocked: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("widget.gallery.style.\(style.rawValue)")
        } else {
            styleCardContent(style, snapshot: snapshot, isLocked: false)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("widget.gallery.style.\(style.rawValue)")
        }
    }

    private func styleCardContent(
        _ style: PulseWidgetStyle,
        snapshot: PulseWidgetSnapshot,
        isLocked: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: PulseDesign.spacing12) {
            GeometryReader { proxy in
                let gap = PulseDesign.spacing8
                let previewHeight = max(
                    1,
                    (proxy.size.width - gap) / (1 + PulseDesign.widgetMediumAspectRatio)
                )

                HStack(spacing: gap) {
                    PulseWidgetStylePreview(
                        style: style,
                        snapshot: snapshot,
                        usesMediumMetrics: false
                    )
                    .frame(width: previewHeight, height: previewHeight)

                    PulseWidgetStylePreview(
                        style: style,
                        snapshot: snapshot,
                        usesMediumMetrics: true
                    )
                    .frame(
                        width: previewHeight * PulseDesign.widgetMediumAspectRatio,
                        height: previewHeight
                    )
                }
            }
            .aspectRatio(PulseDesign.widgetPreviewPairAspectRatio, contentMode: .fit)

            HStack(alignment: .firstTextBaseline) {
                Text(style.localizedName(locale: locale))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PulseDesign.ink)
                Spacer()
                if isLocked {
                    galleryBadge(
                        title: "widget.gallery.locked",
                        systemImage: "lock.fill",
                        foreground: PulseDesign.action,
                        background: PulseDesign.field.opacity(0.12)
                    )
                } else if PulseWidgetStyleAccessPolicy.requiresEnhancement(style) {
                    galleryBadge(
                        title: "widget.gallery.unlocked",
                        systemImage: "checkmark",
                        foreground: PulseDesign.action,
                        background: PulseDesign.field.opacity(0.10)
                    )
                } else {
                    galleryBadge(
                        title: "widget.gallery.included",
                        systemImage: "checkmark",
                        foreground: PulseDesign.action,
                        background: PulseDesign.field.opacity(0.10)
                    )
                }
            }

            Text(verbatim: style.localizedDescription(locale: locale))
                .font(.footnote)
                .foregroundStyle(PulseDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PulseDesign.spacing12)
        .background {
            RoundedRectangle(
                cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
                style: .continuous
            )
            .fill(PulseDesign.surface.opacity(0.90))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
                style: .continuous
            )
            .stroke(
                isLocked
                    ? PulseDesign.field.opacity(0.32)
                    : PulseDesign.separator.opacity(0.72),
                lineWidth: PulseDesign.thinLineWidth
            )
        }
        .shadow(color: PulseDesign.shadow.opacity(0.05), radius: 12, y: 5)
        .contentShape(RoundedRectangle(
            cornerRadius: PulseDesign.widgetGalleryCardCornerRadius,
            style: .continuous
        ))
    }

    private func galleryBadge(
        title: LocalizedStringKey,
        systemImage: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, PulseDesign.spacing8)
            .padding(.vertical, PulseDesign.spacing4)
            .background(background, in: Capsule())
    }
}

struct PulseWidgetStylePreview: View {
    let style: PulseWidgetStyle
    let snapshot: PulseWidgetSnapshot
    let usesMediumMetrics: Bool

    init(
        style: PulseWidgetStyle,
        snapshot: PulseWidgetSnapshot,
        usesMediumMetrics: Bool = true
    ) {
        self.style = style
        self.snapshot = snapshot
        self.usesMediumMetrics = usesMediumMetrics
    }

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PulseWidgetHomeRenderer(
            snapshot: snapshot,
            style: style,
            usesMediumMetrics: usesMediumMetrics,
            usesFullColorPalette: true,
            allowsMotion: !reduceMotion,
            statusText: PulseLocalization.string(
                snapshot.isCheckedToday
                    ? "today.navigation.checked"
                    : "today.navigation.pending",
                locale: locale
            ),
            pathSummaryFormat: PulseLocalization.string(
                "widget.path.summary.format",
                locale: locale
            ),
            actionText: PulseLocalization.string(
                "widget.gallery.action.short",
                locale: locale
            ),
            emptyPlaceText: PulseLocalization.string(
                "widget.place.empty",
                locale: locale
            ),
            placeStatusText: PulseLocalization.string(
                snapshot.isCheckedToday
                    ? "widget.place.checked"
                    : "widget.place.pending",
                locale: locale
            )
        )
        .clipShape(RoundedRectangle(
            cornerRadius: PulseDesign.widgetPreviewCornerRadius,
            style: .continuous
        ))
        .accessibilityHidden(true)
    }
}
