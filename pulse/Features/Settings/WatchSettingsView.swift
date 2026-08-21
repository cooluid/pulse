import SwiftUI

struct WatchSettingsView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.locale) private var locale
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        Form {
            Section {
                PulseWatchSettingsPreview()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)

                Text("settings.watch.summary")
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
            }

            Section("settings.watch.connection.section") {
                LabeledContent("settings.watch.connection.status") {
                    Text(model.watchConnectionStatus.titleKey)
                        .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                }

                Text(model.watchConnectionStatus.detailKey)
                    .font(.footnote)
                    .foregroundStyle(PulseDesign.appMuted(for: visualTheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Toggle(
                    "settings.watch.wave_motion",
                    isOn: Binding(
                        get: { model.settings.watchWaveMotionEnabled },
                        set: { model.setWatchWaveMotionEnabled($0) }
                    )
                )
                .accessibilityIdentifier("settings.watch.wave-motion.toggle")
            } header: {
                Text("settings.watch.appearance.section")
            } footer: {
                Text("settings.watch.wave_motion.detail")
            }
        }
        .scrollContentBackground(.hidden)
        .background(PulseScreenBackground())
        .foregroundStyle(PulseDesign.appInk(for: visualTheme))
        .tint(PulseDesign.appAccent(for: visualTheme))
        .navigationTitle(
            PulseLocalization.string("settings.watch.title", locale: locale)
        )
        .navigationBarTitleDisplayMode(.inline)
        .pulseSecondaryNavigation()
        .id("settings.watch.\(locale.identifier)")
    }
}

extension PulseWatchConnectionStatus {
    var titleKey: LocalizedStringKey {
        switch self {
        case .unsupported:
            "settings.watch.status.unsupported"
        case .activating:
            "settings.watch.status.activating"
        case .unpaired:
            "settings.watch.status.unpaired"
        case .notInstalled:
            "settings.watch.status.not_installed"
        case .installed:
            "settings.watch.status.installed"
        }
    }

    var detailKey: LocalizedStringKey {
        switch self {
        case .unsupported:
            "settings.watch.status.unsupported.detail"
        case .activating:
            "settings.watch.status.activating.detail"
        case .unpaired:
            "settings.watch.status.unpaired.detail"
        case .notInstalled:
            "settings.watch.status.not_installed.detail"
        case .installed:
            "settings.watch.status.installed.detail"
        }
    }
}

private struct PulseWatchSettingsPreview: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LinearGradient(
                        colors: [
                            Color("PulseWatchPreviewCanvasTop"),
                            Color("PulseWatchPreviewCanvasBottom"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                previewWave(
                    color: Color("PulseWatchPreviewWaveBack"),
                    baseline: 0.66,
                    height: size.height * 0.18,
                    size: size
                )
                previewWave(
                    color: Color("PulseWatchPreviewWaveMiddle"),
                    baseline: 0.76,
                    height: size.height * 0.15,
                    size: size
                )
                previewWave(
                    color: Color("PulseWatchPreviewWaveFront"),
                    baseline: 0.86,
                    height: size.height * 0.12,
                    size: size
                )

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("settings.watch.preview.today")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.60))
                        Text("settings.watch.preview.check_in")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                        Text("settings.watch.preview.pending")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ZStack {
                        Capsule()
                            .fill(Color("PulseWatchPreviewAxis"))
                            .frame(width: 2, height: size.height * 0.62)
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .overlay {
                                Circle()
                                    .stroke(
                                        Color("PulseWatchPreviewAxis"),
                                        lineWidth: 4
                                    )
                            }
                            .offset(y: -size.height * 0.12)
                    }
                    .frame(width: 48)
                }
                .padding(24)
            }
        }
        .aspectRatio(1.42, contentMode: .fit)
    }

    private func previewWave(
        color: Color,
        baseline: CGFloat,
        height: CGFloat,
        size: CGSize
    ) -> some View {
        Path { path in
            let y = size.height * baseline
            path.move(to: CGPoint(x: 0, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: y))
            path.addCurve(
                to: CGPoint(x: size.width, y: y - height * 0.10),
                control1: CGPoint(x: size.width * 0.28, y: y - height),
                control2: CGPoint(x: size.width * 0.66, y: y + height * 0.52)
            )
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
        .fill(color)
    }
}
