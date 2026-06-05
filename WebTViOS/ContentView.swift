//
//  ContentView.swift
//  WebTViOS
//
//  Created by Raymund Vorwerk on 27.01.20.
//  Copyright © 2020 Raymund Vorwerk. All rights reserved.
//

import AVKit
import CoreData
import SwiftUI
import AVFoundation
import Combine

// MARK: - Player Managers
/// Central registry for grid and fullscreen `AVPlayer` instances.
final class PlayerManager {
    static let shared = PlayerManager()
    private let gridPreviewBitrate: Double = 350_000
    private let fullscreenBitrate: Double = 0
    private var maxGridPreviewPlayers = 6
    private var defaultPlaybackBitrate: Double = 0
    private var playerBitrates = [String: Double]()
    private var activeGridPreviewNames: [String] = []
    
    private(set) var players = [String: AVPlayer]()
    private(set) var playerViews = [String: AVPlayerView]()
    private(set) var playerURLs = [String: URL]()
    private var itemObservers = [String: [NSObjectProtocol]]()
    private var retryCounts = [String: Int]()
    private var retryWorkItems = [String: DispatchWorkItem]()
    
    /// Creates or returns a cached player for the given channel.
    func addPlayer(for name: String, withURL urlString: String) -> AVPlayer {
        if let existingPlayer = players[name] {
            return existingPlayer
        }
        
        guard let url = URL(string: urlString) else {
            assertionFailure("Invalid URL for player: \(urlString)")
            let fallbackPlayer = AVPlayer()
            players[name] = fallbackPlayer
            return fallbackPlayer
        }
        
        let player = AVPlayer(playerItem: makePlayerItem(for: url, name: name))
        player.automaticallyWaitsToMinimizeStalling = true
        players[name] = player
        playerURLs[name] = url
        playerBitrates[name] = defaultPlaybackBitrate
        return player
    }
    
    /// Returns the cached player for a channel if one exists.
    func getPlayer(for name: String) -> AVPlayer? {
        return players[name]
    }
    
    /// Stops and removes the cached player and retry state for a channel.
    func removePlayer(for name: String) {
        if let player = players[name] {
            player.pause()
            players.removeValue(forKey: name)
            playerURLs.removeValue(forKey: name)
            playerBitrates.removeValue(forKey: name)
            clearObservers(for: name)
            retryCounts.removeValue(forKey: name)
            retryWorkItems[name]?.cancel()
            retryWorkItems.removeValue(forKey: name)
        }
    }
    
    
    /// Mutes every managed player.
    func muteAllPlayers() {
        players.values.forEach { player in
            player.isMuted = true
        }
    }

    /// Applies the low-bitrate profile used while the multi-stream grid is visible.
    func applyGridPlaybackProfile() {
        defaultPlaybackBitrate = gridPreviewBitrate
        players.forEach { name, player in
            applyPlaybackProfile(to: player, name: name, bitrate: gridPreviewBitrate)
        }
    }

    /// Restores the selected player to full quality for fullscreen playback.
    func applyFocusedPlaybackProfile(for name: String) {
        defaultPlaybackBitrate = fullscreenBitrate
        activeGridPreviewNames.removeAll { $0 == name }
        guard let player = players[name] else { return }
        applyPlaybackProfile(to: player, name: name, bitrate: fullscreenBitrate)
    }

    /// Starts one muted grid preview while capping total concurrent previews.
    func startGridPreview(for name: String) {
        guard let player = players[name] else { return }

        ensureItem(for: name)
        applyPlaybackProfile(to: player, name: name, bitrate: gridPreviewBitrate)
        player.isMuted = true

        if !activeGridPreviewNames.contains(name) {
            activeGridPreviewNames.append(name)
        }

        while activeGridPreviewNames.count > maxGridPreviewPlayers {
            let overflowName = activeGridPreviewNames.removeFirst()
            guard overflowName != name else { continue }
            players[overflowName]?.pause()
        }
        PlayerManager.shared.resumePlayerReliably(player, for: name, isMuted: true)
    }

    /// Stops a grid preview when its tile is no longer visible.
    func stopGridPreview(for name: String) {
        activeGridPreviewNames.removeAll { $0 == name }
        players[name]?.pause()
    }

    /// Updates the concurrent grid preview cap.
    func setMaxGridPreviewPlayers(_ limit: Int) {
        maxGridPreviewPlayers = max(limit, 1)
        while activeGridPreviewNames.count > maxGridPreviewPlayers {
            let overflowName = activeGridPreviewNames.removeFirst()
            players[overflowName]?.pause()
        }
    }
    
    /// Starts playback for all managed players, restoring missing items if needed.
    func playAllPlayers() {
        players.values.forEach { player in
            if player.currentItem == nil,
               let name = players.first(where: { $0.value == player })?.key {
                ensureItem(for: name)
            }
            player.seek(to: .positiveInfinity)
            player.playImmediately(atRate: 1.0)
        }
    }
    
    /// Pauses all players except the named one and optionally removes their items.
//    func stopPlayersExcept(name: String, removeItems: Bool = false) {
//        for (playerName, player) in players {
////            if playerName != name && playerName != MEDIATHEK_NAME {
//                if playerName != name  {
//                     player.pause()
//                activeGridPreviewNames.removeAll { $0 == playerName }
//                if removeItems {
//                    clearObservers(for: playerName)
//                    player.replaceCurrentItem(with: nil)
//                }
//            } else {
//                player.seek(to: .positiveInfinity)
//                player.play()
//                player.isMuted = false
//            }
//        }
//    }
    /// Pauses every player except the selected one and reliably resumes the active one.
    func stopPlayersExcept(name: String, removeItems: Bool = false, selectedMuted: Bool = false) {
        for (playerName, player) in players {
            if playerName != name {
                player.pause()
                activeGridPreviewNames.removeAll { $0 == playerName }
                
                if removeItems {
                    clearObservers(for: playerName)
                    player.replaceCurrentItem(with: nil)
                }
            } else {
                resumePlayerReliably(player, for: playerName, isMuted: selectedMuted)
            }
        }
    }
    
    /// Recreates the current player item for a channel and restarts playback.
    func resetPlayer(for name: String) {
        guard let player = players[name],
              let url = playerURLs[name] else {
            return
        }
        
        let item = makePlayerItem(for: url, name: name)
        player.replaceCurrentItem(with: item)
        player.seek(to: .positiveInfinity)
        player.playImmediately(atRate: 1)
    }
    
    /// Stops and removes all managed players and retry bookkeeping.
    func clearAllPlayers() {
        players.values.forEach { player in
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        players.removeAll()
        playerURLs.removeAll()
        playerBitrates.removeAll()
        activeGridPreviewNames.removeAll()
        itemObservers.keys.forEach { clearObservers(for: $0) }
        retryCounts.removeAll()
        retryWorkItems.values.forEach { $0.cancel() }
        retryWorkItems.removeAll()
    }

    /// Ensures a player has an item attached before playback starts.
    func ensureItem(for name: String) {
        guard let player = players[name],
              player.currentItem == nil,
              let url = playerURLs[name] else {
            return
        }
        let item = makePlayerItem(for: url, name: name)
        player.replaceCurrentItem(with: item)
    }

    /// Creates a tuned player item and attaches retry observers.
    private func makePlayerItem(for url: URL, name: String) -> AVPlayerItem {
        let item = AVPlayerItem(url: url)
        item.preferredPeakBitRate = playerBitrates[name] ?? defaultPlaybackBitrate
        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) {
            item.preferredForwardBufferDuration = 2
        }
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, *) {
            item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        }
        attachObservers(to: item, name: name)
        return item
    }

    /// Updates a player and its current item to the requested bitrate profile.
    private func applyPlaybackProfile(to player: AVPlayer, name: String, bitrate: Double) {
        playerBitrates[name] = bitrate
        player.currentItem?.preferredPeakBitRate = bitrate
    }

    /// Adds playback error and recovery observers for a player item.
    private func attachObservers(to item: AVPlayerItem?, name: String) {
        clearObservers(for: name)
        guard let item = item else { return }

        let center = NotificationCenter.default
        var tokens = [NSObjectProtocol]()

        tokens.append(
            center.addObserver(forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main) { [weak self] _ in
                self?.scheduleRetry(for: name, reason: "stalled")
            }
        )

        tokens.append(
            center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                self?.scheduleRetry(for: name, reason: "failed")
            }
        )

        tokens.append(
            center.addObserver(forName: .AVPlayerItemNewAccessLogEntry, object: item, queue: .main) { [weak self] _ in
                self?.retryCounts[name] = 0
            }
        )

        itemObservers[name] = tokens
    }

    func resumePlayerReliably(_ player: AVPlayer, for name: String, isMuted: Bool) {
        player.isMuted = isMuted
        
        // Always seek to live edge with completion handler
        player.seek(to: .positiveInfinity) { completed in
            guard completed else {
                // Fallback if seek fails
                player.playImmediately(atRate: 1.0)
                return
            }
            
            // Prefer playImmediately after seek for live streams
            player.playImmediately(atRate: 1.0)
            
            // Extra safety: force play again after a tiny delay if still not playing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if player.timeControlStatus != .playing {
                    player.playImmediately(atRate: 1.0)
                }
            }
        }
    }
    
    /// Removes all notification observers for a managed player.
    private func clearObservers(for name: String) {
        if let tokens = itemObservers[name] {
            let center = NotificationCenter.default
            tokens.forEach { center.removeObserver($0) }
        }
        itemObservers.removeValue(forKey: name)
    }

    /// Schedules a bounded exponential-backoff retry for a failing stream.
    private func scheduleRetry(for name: String, reason: String) {
        guard retryWorkItems[name] == nil else { return }
        guard shouldRetryPlayer(named: name, reason: reason) else { return }
        let attempt = (retryCounts[name] ?? 0) + 1
        retryCounts[name] = attempt
        let delay = min(pow(2.0, Double(attempt)), 30.0)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.retryWorkItems[name] = nil
            if self.players[name] != nil {
                self.resetPlayer(for: name)
            }
        }
        retryWorkItems[name] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Returns whether a player is in a state that warrants rebuilding its item.
    private func shouldRetryPlayer(named name: String, reason: String) -> Bool {
        guard let player = players[name],
              let item = player.currentItem else {
            return false
        }

        if item.status == .failed {
            return true
        }

        switch reason {
        case "stalled":
            return player.timeControlStatus != .playing
        case "failed":
            return true
        default:
            return false
        }
    }
}

// MARK: - ContentView
/// Root view that coordinates the grid, fullscreen player, and channel management.
struct ContentView: View {
    // MARK: - State Properties
    @State private var currentChannelName: String = ""
    @State private var showChannelGrid = true
    @State private var isChannelDialogSheetPresented: Bool = false
    @State private var isPlaying: Bool = true
    @State private var reduceDataUsage: Bool = false
    @State private var previewImages: [String: UIImage] = [:]
    @State private var gridPreparationTask: Task<Void, Never>?
    @State private var lastGridPreparationDate = Date.distantPast
    
    // MARK: - Environment Objects
    @StateObject private var channelStore = ChannelStore()
    @Environment(\.verticalSizeClass) private var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(\.managedObjectContext) private var viewContext
    
    
    var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // MARK: - UI Constants
    private let headerColor: Color = .white
    private let appBackground = LinearGradient(
        colors: [
            Color(red: 0.07, green: 0.10, blue: 0.16),
            Color(red: 0.04, green: 0.06, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let headerGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.10),
            Color.white.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Computed Properties
    
    // MARK: - Body
    /// Builds the full app shell with header, overlays, and player content.
    var body: some View {
        ZStack {
            appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderToolbarView(
                    isIPhone: isIPhone,
                    verticalSizeClass: verticalSizeClass,
                    horizontalSizeClass: horizontalSizeClass,
                    currentChannelName: currentChannelName,
                    showChannelGrid: $showChannelGrid,
                    reduceDataUsage: $reduceDataUsage,
                    isChannelDialogSheetPresented: $isChannelDialogSheetPresented,
                    headerColor: headerColor,
                    onResetPlayers: resetGridPlayers
                )
                .padding(EdgeInsets(top: 1, leading: isIPhone ? 10 : 50, bottom: 1, trailing: 10))
                .background(
                    headerGradient
                        .background(.ultraThinMaterial)
                )

                ZStack {

                if showChannelGrid {
                    ChannelGridView(
                        channels: channels,
                        livePreviewLimit: maxGridPreviewCount,
                        previewImages: previewImages,
                        selectChannel: handleGridSelection(name:)
                    )
                } else {
                    if !currentChannelName.isEmpty,
                       let player = PlayerManager.shared.players[currentChannelName] {
                        ZStack {
                            VideoPlayer(player: player)
                                .id(currentChannelName)
                                .onAppear {
                                    isPlaying = true
                                    PlayerManager.shared.resumePlayerReliably(player, for: currentChannelName, isMuted: false)
                                }
                                .onDisappear {
                                    isPlaying = false
                                    player.isMuted = true
                                }
                        }
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 20).onEnded { value in
                                handleChannelSwipeGesture(value)
                            }
                        )
                        .edgesIgnoringSafeArea(.all)
                    }
                }
                }
                .zIndex(3)
                .padding(4)
            }
        }
        .task {
            await loadChannels()
        }
        .onChange(of: showChannelGrid) {
            if showChannelGrid {
                scheduleGridPreparation()
            }
        }
        .sheet(isPresented: $isChannelDialogSheetPresented) {
            ImprovedChannelView(channelStore: channelStore)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Methods
    
    // Helper to calculate column count based on screen size
    /// Chooses a grid column count for older geometry-based callers.
    private func calculateColumnCount(for size: CGSize) -> Int {
        var count = 3
        
        #if targetEnvironment(macCatalyst)
        // Restrict columns to 4-6 for Mac
        let columns = Int(size.width / 190)
        count = columns.clamp(low: 4, high: 6)
        #else
        // Different counts for iOS devices
        let deviceIdiom = UIDevice.current.userInterfaceIdiom
        switch deviceIdiom {
        case .phone:
            count = Int(size.width / 120)
        case .pad:
            count = Int(size.width / 190)
        default:
            count = 3
        }
        #endif
        
        return count
    }

    /// Promotes a tapped grid tile into the fullscreen player.
    private func handleGridSelection(name: String) {
        selectChannel(name: name, isMuted: true)
        PlayerManager.shared.stopPlayersExcept(name: name, removeItems: false, selectedMuted: true)
        showChannelGrid = false
    }


    /// Restarts grid playback after data-saving mode is toggled.
    private func resetGridPlayers() {
        Task {
            await stopPlayersExcept(name: "", stop: true)
            PlayerManager.shared.playAllPlayers()
            PlayerManager.shared.applyGridPlaybackProfile()
        }
    }
    
    /// Pauses every player except the selected one.
    private func stopPlayersExcept(name: String, stop: Bool, selectedMuted: Bool = false) async {
        PlayerManager.shared.stopPlayersExcept(name: name, removeItems: stop, selectedMuted: selectedMuted)
        reduceDataUsage = true
    }
    
    /// Loads channel definitions and prepares preview players.
    private func loadChannels() async {
        channelList.removeAll()
        channelStore.load(from: viewContext)
        PlayerManager.shared.clearAllPlayers()
        
        for name in channels.prefix(maxGridPreviewCount) {
            if let channelInfo = channelList[name],
               channelInfo.indices.contains(2),
               channelInfo[2] == "1",
               channelInfo[0].hasSuffix("m3u8") {
                _ = PlayerManager.shared.addPlayer(for: name, withURL: channelInfo[0])
            }
        }
        PlayerManager.shared.applyGridPlaybackProfile()
    }

    private var channels: [String] {
        channelStore.names
    }

    /// Allows all iPad/Mac previews while keeping iPhone preview usage bounded.
    private var maxGridPreviewCount: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? channels.count : min(channels.count, 6)
    }
    
    /// Handles horizontal channel navigation and vertical grid dismissal gestures.
    private func handleChannelSwipeGesture(_ gesture: DragGesture.Value) {
        if abs(gesture.translation.height) > 150 {
            returnToGrid()
            return
        }
        
        guard let currentIndex = channels.firstIndex(of: currentChannelName) else { return }

        if let player = PlayerManager.shared.players[currentChannelName] {
            player.isMuted = true
        }
        
        let newIndex: Int
        if gesture.translation.width > 0 {
            newIndex = currentIndex == 0 ? channels.count - 1 : currentIndex - 1
        } else {
            newIndex = currentIndex == channels.count - 1 ? 0 : currentIndex + 1
        }
        
        let nextChannelName = channels[newIndex]
        selectChannel(name: nextChannelName)

        Task {
            await stopPlayersExcept(name: nextChannelName, stop: false)
        }
    }
    
    /// Activates a channel for fullscreen playback.
    private func selectChannel(name: String, isMuted: Bool = false) {
        isPlaying = false
        if currentChannelName == name {
            PlayerManager.shared.resetPlayer(for: name)
        }
        currentChannelName = name

        if let player = player(for: name) {
            PlayerManager.shared.applyFocusedPlaybackProfile(for: name)
            PlayerManager.shared.resumePlayerReliably(player, for: name, isMuted: isMuted)
            prepareNeighborChannels(around: name)
        }
    }

    /// Returns a cached player or creates one on demand for fullscreen playback.
    private func player(for name: String) -> AVPlayer? {
        if let player = PlayerManager.shared.players[name] {
            PlayerManager.shared.ensureItem(for: name)
            return player
        }

        guard let channelInfo = channelList[name],
              let streamURL = channelInfo.first,
              !streamURL.isEmpty else {
            return nil
        }

        return PlayerManager.shared.addPlayer(for: name, withURL: streamURL)
    }

    /// Switches back to the grid after preparing previews to render immediately.
    private func returnToGrid() {
        prepareGridPlayback()
        showChannelGrid = true
    }

    /// Applies the preview profile and starts muted grid playback before rendering the grid.
    private func prepareGridPlayback() {
        let maxPreviews = maxGridPreviewCount
        PlayerManager.shared.setMaxGridPreviewPlayers(maxPreviews)
        currentChannelName = ""
        PlayerManager.shared.applyGridPlaybackProfile()
        PlayerManager.shared.muteAllPlayers()
        lastGridPreparationDate = Date()

        for name in channels.prefix(maxPreviews) {
            guard let channelInfo = channelList[name],
                  channelInfo.indices.contains(2),
                  channelInfo[2] == "1",
                  channelInfo[0].hasSuffix("m3u8") else {
                continue
            }
            _ = player(for: name)
            PlayerManager.shared.startGridPreview(for: name)
        }
    }

    /// Debounces expensive grid preparation so one transition does one prep pass.
    private func scheduleGridPreparation() {
        gridPreparationTask?.cancel()
        gridPreparationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            guard Date().timeIntervalSince(lastGridPreparationDate) > 0.35 else { return }
            lastGridPreparationDate = Date()
            prepareGridPlayback()
        }
    }

    /// Keeps adjacent channel player items ready so swipe navigation starts promptly.
    private func prepareNeighborChannels(around name: String) {
        guard let currentIndex = channels.firstIndex(of: name), channels.count > 1 else { return }

        let neighborIndexes = [
            currentIndex == 0 ? channels.count - 1 : currentIndex - 1,
            currentIndex == channels.count - 1 ? 0 : currentIndex + 1,
        ]

        for index in Set(neighborIndexes) {
            let neighborName = channels[index]
            guard neighborName != name,
                  let neighborPlayer = player(for: neighborName) else {
                continue
            }
            neighborPlayer.isMuted = true
            neighborPlayer.pause()
        }
    }

    /// Extracts a still image from a stream for grid preview use.
    private func makePreviewImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)

        return await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { cgImage, _, _ in
                if let cgImage {
                    continuation.resume(returning: UIImage(cgImage: cgImage))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

/// Adds a small clamping helper for layout calculations.
extension Comparable {
    /// Restricts a comparable value to the provided closed range.
    func clamp(low: Self, high: Self) -> Self {
        if self > high {
            return high
        } else if self < low {
            return low
        }
        return self
    }
}



/// Exposes version metadata from the main app bundle.
extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
    var releaseVersionNumberPretty: String {
        return "v\(releaseVersionNumber ?? "1.0(0)")"
    }
}

/// Preview for the root application view.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
