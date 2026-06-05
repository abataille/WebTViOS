//
//  AVViewController.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 05.02.20.
//  Copyright © 2020 Raymund Vorwerk. All rights reserved.
//

import Foundation
import AVKit
import UIKit
import SwiftUI

/// Bridges a reusable UIKit video controller into SwiftUI.
struct AVView: UIViewControllerRepresentable {
    // MARK: - Properties
    @Binding var sender: String
    @Binding var isPlaying: Bool
    let name: String // Changed from @State to let since it's passed in and not modified
    let muted: Bool  // Changed from @State to let
    
    // MARK: - UIViewControllerRepresentable
    /// Creates the UIKit controller used for playback.
    func makeUIViewController(context: Context) -> AVViewController {
        AVViewController()
    }
    
    /// Applies current playback inputs to the hosted controller.
    func updateUIViewController(_ uiViewController: AVViewController, context: Context) {
        // Configure player settings
        uiViewController.playerVC.player?.isMuted = muted
        
        if name != "ZERO" {  // Multiple players thumbnail view
            uiViewController.loadVideo(url: name)
            configureForThumbnail(uiViewController)
        } else {  // Main player
            uiViewController.loadVideo(url: sender)
        }
    }
    
    // MARK: - Helper Methods
    /// Configures a player controller for muted thumbnail playback.
    private func configureForThumbnail(_ viewController: AVViewController) {
        viewController.playerVC.showsPlaybackControls = false
        viewController.playerVC.videoGravity = .resizeAspectFill
        viewController.view.isUserInteractionEnabled = false
    }
}

/// UIKit controller that manages an embedded `AVPlayerViewController`.
class AVViewController: UIViewController {
    // MARK: - Properties
    let playerVC = AVPlayerViewController()
    
    // MARK: - Lifecycle Methods
    /// Builds the player hierarchy the first time the view appears.
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
    }
    
    /// Configures audio behavior after the view is onscreen.
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupAudioSession()
    }
    
    /// Tears down playback resources when the controller disappears.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cleanupPlayer()
    }
    
    // MARK: - Setup Methods
    /// Lazily creates and embeds the player controller.
    private func setupPlayer() {
        if playerVC.player == nil {
            playerVC.player = AVPlayer()
            
            // Add player view
            view.addSubview(playerVC.view)
            playerVC.view.frame = view.bounds
            playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            playerVC.videoGravity = .resizeAspect
            
        }
    }
    
    /// Sets the audio session category for media playback.
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
        }
    }
    
    /// Stops playback and detaches the player from the view hierarchy.
    private func cleanupPlayer() {
        playerVC.player?.pause()
        playerVC.player?.replaceCurrentItem(with: nil)
        playerVC.player = nil
        playerVC.view.removeFromSuperview()
    }
    
    // MARK: - Public Methods
    /// Loads a video from a string URL.
    func loadVideo(url urlString: String) {
        guard let streamingURL = URL(string: urlString) else { return }
        loadVideo(url: streamingURL)
    }
    
    /// Replaces the current item and starts playback for the provided URL.
    func loadVideo(url: URL) {
        playerVC.player?.pause()
        let avItem = AVPlayerItem(url: url)
        playerVC.player?.replaceCurrentItem(with: avItem)
        playerVC.player?.play()
        playerVC.showsPlaybackControls = true
    }
}
