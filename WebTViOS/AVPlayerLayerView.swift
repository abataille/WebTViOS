import AVFoundation
import SwiftUI

/// Wraps `AVPlayerLayer` for lightweight live preview rendering in SwiftUI.
struct AVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let muted: Bool
    let videoGravity: AVLayerVideoGravity

    /// Creates the backing `UIView` that hosts the player layer.
    func makeUIView(context: Context) -> PlayerLayerContainer {
        let view = PlayerLayerContainer()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = videoGravity
        view.playerLayer.player = player
        view.playerLayer.player?.isMuted = muted
        return view
    }

    /// Keeps the hosted player and presentation settings in sync.
    func updateUIView(_ uiView: PlayerLayerContainer, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        uiView.playerLayer.videoGravity = videoGravity
        uiView.playerLayer.player?.isMuted = muted
    }
}

/// Minimal container whose root layer is an `AVPlayerLayer`.
final class PlayerLayerContainer: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
