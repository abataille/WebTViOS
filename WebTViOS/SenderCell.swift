import AVKit
import SwiftUI

/// One grid tile showing either a live preview or a captured thumbnail.
struct SenderCell: View {
    let name: String
    let isLive: Bool
    let player: AVPlayer?
    let previewImage: UIImage?
    let action: () -> Void

    /// Renders the tappable channel tile and its overlay label.
    var body: some View {
        ZStack {
            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else if isLive, let player {
                    AVPlayerLayerView(
                        player: player,
                        muted: true,
                        videoGravity: .resizeAspectFill
                    )
                    .allowsHitTesting(false)
                    .onAppear {
                        PlayerManager.shared.startGridPreview(for: name)
                    }
                    .onDisappear {
                        PlayerManager.shared.stopGridPreview(for: name)
                    }
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .foregroundStyle(.white)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
            }
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08))
            }
            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}
