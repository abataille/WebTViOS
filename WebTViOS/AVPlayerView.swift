//
//  AVPlayerView.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 29.11.22.
//  Copyright © 2022 Raymund Vorwerk. All rights reserved.
//

import Foundation
import AVKit
import UIKit
import SwiftUI
import AVFoundation

/// Wraps `AVPlayerViewController` for the primary playback surface.
struct AVPlayerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = AVPlayerViewController
    // For the multiplayer window
    
    let player: AVPlayer
    let showControls: Bool
    let muted: Bool
    
    /// Updates the hosted player controller when SwiftUI state changes.
    func updateUIViewController(_ playerController: AVPlayerViewController, context: Context) {
        if playerController.player !== player {
            playerController.player = player
        }
        playerController.showsPlaybackControls = showControls
        playerController.player?.isMuted = muted
    }

    /// Creates and configures the player controller used by SwiftUI.
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerController = AVPlayerViewController()
        playerController.modalPresentationStyle = .automatic
        playerController.showsPlaybackControls = showControls
        playerController.player = player
       
        playerController.player?.isMuted = muted
        playerController.player?.play()
        
        // the following does not work. suppression of contol handling
//        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak player] _ in
//            guard let player = player else { return }
//            if player.timeControlStatus == .paused {
//                // Check reason for pause
//                player.play()
//            }
//        }
//        NotificationCenter.default.addObserver(
//            forName: AVAudioSession.interruptionNotification,
//            object: nil,
//            queue: .main
//        ) { notification in
//            // Handle interruption, e.g., start playing again if interrupted
//            if let userInfo = notification.userInfo,
//               let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
//               let type = AVAudioSession.InterruptionType(rawValue: typeValue) {
//                if type == .ended {
//                    player.play() // Resume playback
//                }
//            }
//        }
        return playerController
    }
    /// Releases the hosted player when SwiftUI removes the controller.
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
          // Pause and release the player when the view is removed. This is ignored by now
        uiViewController.player = nil
      }
   
}


/*
 import SwiftUI
 import AVKit

 struct VideoPlayerView: UIViewRepresentable {
     let url: URL
     let playWithSound: Bool

     func makeUIView(context: Context) -> UIView {
         let view = UIView()
         view.backgroundColor = .black // Ensure the background is visible if the video is not loading

         let player = AVPlayer(url: url)
         player.isMuted = !playWithSound

         // Create and configure AVPlayerLayer
         let playerLayer = AVPlayerLayer(player: player)
         playerLayer.videoGravity = .resizeAspectFill // Fill the view while keeping the aspect ratio
         playerLayer.frame = view.bounds

         // Add the player layer to the view
         view.layer.addSublayer(playerLayer)

         // Start playing
         player.play()

         // Store the player in the context coordinator
         context.coordinator.player = player
         context.coordinator.playerLayer = playerLayer

         return view
     }

     func updateUIView(_ uiView: UIView, context: Context) {
         // Update the player layer frame to match the UIView's bounds
         if let playerLayer = context.coordinator.playerLayer {
             playerLayer.frame = uiView.bounds
         }
     }

     func makeCoordinator() -> Coordinator {
         Coordinator()
     }

     class Coordinator {
         var player: AVPlayer?
         var playerLayer: AVPlayerLayer?
     }

     static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
         // Pause and clean up the player when the view is removed
         coordinator.player?.pause()
         coordinator.player = nil
         coordinator.playerLayer = nil
     }
 }
 */

