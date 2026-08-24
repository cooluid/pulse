import OSLog
import PulseCore
import SwiftUI
import UIKit

struct PulseDetailSheetScaffold<Content: View, Actions: View>: View {
    let title: LocalizedStringKey
    let detents: Set<PresentationDetent>
    private let content: Content
    private let actions: Actions

    @Environment(\.dismiss) private var dismiss
    @Environment(\.pulseVisualTheme) private var visualTheme

    init(
        title: LocalizedStringKey,
        detents: Set<PresentationDetent>,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.detents = detents
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PulseDesign.spacing20) {
                    content
                }
                .frame(maxWidth: PulseDesign.mediaCardMaxWidth, alignment: .leading)
                .padding(PulseDesign.spacing24)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(PulseScreenBackground())
            .foregroundStyle(PulseDesign.appInk(for: visualTheme))
            .tint(PulseDesign.appAccent(for: visualTheme))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("action.close")
                    .accessibilityIdentifier("detail.sheet.close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    actions
                }
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
    }
}

struct PulseDetailActionsMenu<Content: View>: View {
    let accessibilityLabel: LocalizedStringKey
    let accessibilityHint: LocalizedStringKey
    let accessibilityIdentifier: String
    let isBusy: Bool
    private let content: Content
    @Environment(\.pulseVisualTheme) private var visualTheme

    init(
        accessibilityLabel: LocalizedStringKey,
        accessibilityHint: LocalizedStringKey,
        accessibilityIdentifier: String,
        isBusy: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.accessibilityIdentifier = accessibilityIdentifier
        self.isBusy = isBusy
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.semibold))
                }
            }
            .foregroundStyle(PulseDesign.appInk(for: visualTheme))
            .frame(
                width: PulseDesign.detailActionHitSize,
                height: PulseDesign.detailActionHitSize
            )
            .contentShape(Rectangle())
            .accessibilityHidden(true)
        }
        .menuOrder(.fixed)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct ImprintMediaPreview: View {
    let media: ImprintMediaSnapshot
    let load: (ImprintMediaSnapshot) async throws -> Data

    @State private var state: PreviewLoadState = .loading
    @Environment(\.pulseVisualTheme) private var visualTheme

    private static let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "media-preview"
    )

    private struct LoadIdentity: Hashable {
        let mediaID: UUID
        let thumbnailRelativePath: String
        let thumbnailSHA256: String
    }

    private enum PreviewLoadState {
        case loading
        case image(UIImage)
        case failed
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                Color.clear
                    .aspectRatio(mediaAspectRatio, contentMode: .fit)
                    .overlay {
                        ProgressView()
                    }
            case .image(let image):
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(mediaAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            case .failed:
                ContentUnavailableView(
                    "media.preview.unavailable",
                    systemImage: "photo.badge.exclamationmark"
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: PulseDesign.mediaPreviewFailureMinimumHeight
                )
            }
        }
        .background(PulseDesign.appSurface(for: visualTheme))
        .clipShape(
            RoundedRectangle(
                cornerRadius: PulseDesign.mediaCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: PulseDesign.mediaCornerRadius,
                style: .continuous
            )
            .stroke(
                PulseDesign.appDivider(for: visualTheme),
                lineWidth: PulseDesign.thinLineWidth
            )
        }
        .task(
            id: LoadIdentity(
                mediaID: media.id,
                thumbnailRelativePath: media.thumbnailRelativePath,
                thumbnailSHA256: media.thumbnailSHA256
            )
        ) {
            state = .loading
            do {
                let data = try await load(media)
                try Task.checkCancellation()
                guard let image = UIImage(data: data) else {
                    Self.logger.error(
                        "Failed to decode thumbnail for media \(media.id.uuidString, privacy: .public); bytes=\(data.count, privacy: .public)."
                    )
                    state = .failed
                    return
                }
                state = .image(image)
            } catch is CancellationError {
                Self.logger.debug(
                    "Cancelled thumbnail presentation for media \(media.id.uuidString, privacy: .public)."
                )
            } catch {
                let error = error as NSError
                Self.logger.error(
                    "Failed to read thumbnail for media \(media.id.uuidString, privacy: .public); domain=\(error.domain, privacy: .public), code=\(error.code, privacy: .public)."
                )
                state = .failed
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("media.preview.accessibility")
    }

    private var mediaAspectRatio: CGFloat {
        CGFloat(media.pixelWidth) / CGFloat(media.pixelHeight)
    }
}

struct ImprintMediaPreviewButton: View {
    let media: ImprintMediaSnapshot
    let load: (ImprintMediaSnapshot) async throws -> Data
    let accessibilityIdentifier: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            ImprintMediaPreview(media: media, load: load)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(
                            width: PulseDesign.minimumHitTarget,
                            height: PulseDesign.minimumHitTarget
                        )
                        .background(.black.opacity(0.62), in: Circle())
                        .padding(PulseDesign.spacing8)
                        .accessibilityHidden(true)
                }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("media.preview.accessibility")
        .accessibilityHint("media.preview.open_fullscreen_hint")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct ImprintMediaFullscreenViewer: View {
    let media: ImprintMediaSnapshot
    let load: (ImprintMediaSnapshot) async throws -> Data

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var state: OriginalLoadState = .loading
    @State private var reloadSequence = 0

    private static let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "media-original-viewer"
    )

    private struct LoadIdentity: Hashable {
        let mediaID: UUID
        let originalRelativePath: String
        let originalSHA256: String
        let reloadSequence: Int
    }

    private enum OriginalLoadState {
        case loading
        case image(UIImage)
        case failed
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch state {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
                    .accessibilityLabel("media.fullscreen.loading")
            case .image(let image):
                ZoomableImprintImage(image: image, animatesZoom: !reduceMotion)
                    .ignoresSafeArea()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("media.preview.accessibility")
                    .accessibilityHint("media.fullscreen.zoom_hint")
            case .failed:
                VStack(spacing: PulseDesign.spacing16) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .accessibilityHidden(true)

                    Text("media.preview.unavailable")
                        .font(.headline)

                    Button("action.retry") {
                        reloadSequence += 1
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .foregroundStyle(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(
                        width: PulseDesign.detailActionHitSize,
                        height: PulseDesign.detailActionHitSize
                    )
                    .background(.black.opacity(0.62), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.28), lineWidth: PulseDesign.thinLineWidth)
                    }
            }
            .accessibilityLabel("action.close")
            .accessibilityIdentifier("media.fullscreen.close")
            .padding(.trailing, PulseDesign.spacing16)
            .safeAreaPadding(.top, PulseDesign.spacing8)
        }
        .statusBarHidden(true)
        .task(
            id: LoadIdentity(
                mediaID: media.id,
                originalRelativePath: media.originalRelativePath,
                originalSHA256: media.sha256,
                reloadSequence: reloadSequence
            )
        ) {
            state = .loading
            do {
                let data = try await load(media)
                try Task.checkCancellation()
                guard let image = UIImage(data: data) else {
                    Self.logger.error(
                        "Failed to decode original for media \(media.id.uuidString, privacy: .public); bytes=\(data.count, privacy: .public)."
                    )
                    state = .failed
                    return
                }
                state = .image(image)
            } catch is CancellationError {
                Self.logger.debug(
                    "Cancelled original presentation for media \(media.id.uuidString, privacy: .public)."
                )
            } catch {
                let error = error as NSError
                Self.logger.error(
                    "Failed to read original for media \(media.id.uuidString, privacy: .public); domain=\(error.domain, privacy: .public), code=\(error.code, privacy: .public)."
                )
                state = .failed
            }
        }
    }
}

private struct ZoomableImprintImage: UIViewRepresentable {
    let image: UIImage
    let animatesZoom: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(animatesZoom: animatesZoom)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = animatesZoom
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.animatesZoom = animatesZoom
        scrollView.bouncesZoom = animatesZoom
        guard context.coordinator.imageView?.image !== image else { return }
        context.coordinator.imageView?.image = image
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        var animatesZoom: Bool

        init(animatesZoom: Bool) {
            self.animatesZoom = animatesZoom
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let horizontalInset = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
            let verticalInset = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(
                    scrollView.minimumZoomScale,
                    animated: animatesZoom
                )
                return
            }

            let zoomScale = min(2.5, scrollView.maximumZoomScale)
            let point = recognizer.location(in: imageView)
            let zoomSize = CGSize(
                width: scrollView.bounds.width / zoomScale,
                height: scrollView.bounds.height / zoomScale
            )
            scrollView.zoom(
                to: CGRect(
                    x: point.x - zoomSize.width / 2,
                    y: point.y - zoomSize.height / 2,
                    width: zoomSize.width,
                    height: zoomSize.height
                ),
                animated: animatesZoom
            )
        }
    }
}

struct ImprintMediaThumbnail: View {
    let media: ImprintMediaSnapshot
    let load: (ImprintMediaSnapshot) async throws -> Data

    @State private var image: UIImage?
    @Environment(\.pulseVisualTheme) private var visualTheme

    private static let logger = Logger(
        subsystem: PulseRuntimeIdentity.bundleIdentifier,
        category: "media-thumbnail"
    )

    private struct LoadIdentity: Hashable {
        let mediaID: UUID
        let thumbnailRelativePath: String
        let thumbnailSHA256: String
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.fill")
                    .font(.caption)
                    .foregroundStyle(PulseDesign.appAccent(for: visualTheme))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PulseDesign.appChromeBackground(for: visualTheme))
            }
        }
        .frame(
            width: PulseDesign.mediaCompanionThumbnailSize,
            height: PulseDesign.mediaCompanionThumbnailSize
        )
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(
                    PulseDesign.appAccent(for: visualTheme),
                    lineWidth: PulseDesign.thinLineWidth
                )
        }
        .task(
            id: LoadIdentity(
                mediaID: media.id,
                thumbnailRelativePath: media.thumbnailRelativePath,
                thumbnailSHA256: media.thumbnailSHA256
            )
        ) {
            do {
                let data = try await load(media)
                try Task.checkCancellation()
                image = UIImage(data: data)
            } catch is CancellationError {
                Self.logger.debug(
                    "Cancelled companion thumbnail for media \(media.id.uuidString, privacy: .public)."
                )
            } catch {
                let error = error as NSError
                Self.logger.error(
                    "Failed to read companion thumbnail for media \(media.id.uuidString, privacy: .public); domain=\(error.domain, privacy: .public), code=\(error.code, privacy: .public)."
                )
                image = nil
            }
        }
        .accessibilityHidden(true)
    }
}
