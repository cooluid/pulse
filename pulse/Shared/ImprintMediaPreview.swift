import PulseCore
import SwiftUI
import UIKit

struct ImprintMediaPreview: View {
    let media: ImprintMediaSnapshot
    let load: (ImprintMediaSnapshot) async throws -> Data

    @State private var state: PreviewLoadState = .loading

    private enum PreviewLoadState {
        case loading
        case image(UIImage)
        case failed
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: PulseDesign.mediaPreviewHeight)
            case .image(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: PulseDesign.mediaPreviewHeight)
                    .clipped()
            case .failed:
                ContentUnavailableView(
                    "media.preview.unavailable",
                    systemImage: "photo.badge.exclamationmark"
                )
                .frame(maxWidth: .infinity, minHeight: PulseDesign.mediaPreviewHeight)
            }
        }
        .background(PulseDesign.surface)
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
            .stroke(PulseDesign.separator, lineWidth: PulseDesign.thinLineWidth)
        }
        .task(id: media.modifiedAt) {
            state = .loading
            do {
                let data = try await load(media)
                guard let image = UIImage(data: data) else {
                    state = .failed
                    return
                }
                state = .image(image)
            } catch {
                state = .failed
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("media.preview.accessibility")
    }
}
