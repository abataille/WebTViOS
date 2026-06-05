//
//  AVController.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 04.02.20.
//  Copyright © 2020 Raymund Vorwerk. All rights reserved.
//

import Foundation
import AVKit
import UIKit
import SwiftUI

/// Legacy test controller for direct AVPlayer playback.
class AVViewController: UIViewController {
    
    
    
    /// Starts a demo stream when the view loads.
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.orange
        startAV()
    }
    
    /// Embeds an `AVPlayerViewController` and begins playback.
    func startAV() {
        let videoURL = URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")
        let player = AVPlayer(url: videoURL!)
        let controller=AVPlayerViewController()
        controller.player=player
        player.play()
        self.addChild(controller)
        self.view.addSubview(controller.view)
        controller.view.frame = self.view.frame
        
        
    }
    
    
}
