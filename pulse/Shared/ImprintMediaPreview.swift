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
