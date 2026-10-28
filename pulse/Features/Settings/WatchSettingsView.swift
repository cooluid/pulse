import PulseCore
import SwiftUI

struct WatchSettingsView: View {
    @Bindable var model: PulseAppModel

    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    @Environment(\.pulseVisualTheme) private var visualTheme

    var body: some View {
        Form {
            Section {
                PulseWatchSettingsPreview(day: model.today?.day)
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

                if model.watchConnectionStatus.showsOpenWatchAppAction {
                    Button("settings.watch.open_watch_app") {
                        openURL(PulseWatchAppNavigation.watchAppURL)
                    }
                    .accessibilityIdentifier("settings.watch.open-watch-app")
                }
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

    var showsOpenWatchAppAction: Bool {
        switch self {
        case .unpaired, .notInstalled:
            true
        case .unsupported, .activating, .installed:
            false
        }
    }
}

/// The watch face as it waits for today: the dashed seal over slow ink washes.
private struct PulseWatchSettingsPreview: View {
    let day: Int?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let sealSide = min(size.width * 0.3, size.height * 0.42)
            ZStack {
                LinearGradient(
                    colors: [
                        Color("PulseWatchPreviewPaper"),
                        Color("PulseWatchPreviewPaperDeep"),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                previewWave(
                    color: Color("PulseWatchPreviewWashBack"),
                    baseline: 0.66,
                    height: size.height * 0.18,
                    size: size
                )
                previewWave(
                    color: Color("PulseWatchPreviewWashMiddle"),
                    baseline: 0.76,
                    height: size.height * 0.15,
                    size: size
                )
                previewWave(
                    color: Color("PulseWatchPreviewWashFront"),
                    baseline: 0.86,
                    height: size.height * 0.12,
                    size: size
                )

                VStack(spacing: PulseDesign.spacing8) {
                    if let day {
                        PulseDayMark(
                            day: day,
                            state: .awaiting,
                            seed: 0,
                            seal: Color("PulseWatchPreviewSeal"),
                            ink: Color("PulseWatchPreviewInk"),
                            muted: Color("PulseWatchPreviewMuted"),
                            emphasized: true
                        )
                        .frame(width: sealSide, height: sealSide)
                    }
                    Text("settings.watch.preview.check_in")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(Color("PulseWatchPreviewSeal"))
                    Text("settings.watch.preview.pending")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("PulseWatchPreviewMuted"))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
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
