//
//  PlaylistManager.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import Foundation
import AVFoundation
import Combine

/// Manages playlist playback with sequential audio file playing
final class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTrackIndex: Int = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var volume: Float = 1.0
    @Published private(set) var playlist: [TrackItem] = []
    
    private var player: AVAudioPlayer?
    private var timeObserver: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAudioSession()
        setupNotifications()
    }
    
    // MARK: - Public API
    
    /// Load a playlist and start playing from the first track
    func loadPlaylist(_ tracks: [TrackItem], startFromIndex: Int = 0) {
        playlist = tracks
        currentTrackIndex = max(0, min(startFromIndex, tracks.count - 1))
        
        if !playlist.isEmpty {
            playCurrentTrack()
        }
    }
    
    /// Play the current track in the playlist
    func playCurrentTrack() {
        guard currentTrackIndex < playlist.count else { return }
        
        let track = playlist[currentTrackIndex]
        do {
            try play(url: track.fileURL, loop: false)
        } catch {
            print("❌ Failed to play track: \(error)")
        }
    }
    
    /// Play next track in playlist
    func playNext() {
        guard !playlist.isEmpty else { return }
        
        currentTrackIndex = (currentTrackIndex + 1) % playlist.count
        playCurrentTrack()
    }
    
    /// Play previous track in playlist
    func playPrevious() {
        guard !playlist.isEmpty else { return }
        
        currentTrackIndex = currentTrackIndex > 0 ? currentTrackIndex - 1 : playlist.count - 1
        playCurrentTrack()
    }
    
    /// Play specific track by index
    func playTrack(at index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        
        currentTrackIndex = index
        playCurrentTrack()
    }
    
    /// Pause playback
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimeObserver()
    }
    
    /// Resume playback
    func resume() {
        player?.play()
        isPlaying = true
        startTimeObserver()
    }
    
    /// Stop playback and reset
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimeObserver()
    }
    
    /// Seek to specific time in current track
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        player.currentTime = max(0, min(time, player.duration))
        currentTime = player.currentTime
    }
    
    /// Set volume (0.0 to 1.0)
    func setVolume(_ value: Float) {
        volume = max(0, min(value, 1.0))
        player?.volume = volume
    }
    
    /// Get current track
    var currentTrack: TrackItem? {
        guard currentTrackIndex < playlist.count else { return nil }
        return playlist[currentTrackIndex]
    }
    
    /// Get next track
    var nextTrack: TrackItem? {
        guard !playlist.isEmpty else { return nil }
        let nextIndex = (currentTrackIndex + 1) % playlist.count
        return playlist[nextIndex]
    }
    
    /// Get previous track
    var previousTrack: TrackItem? {
        guard !playlist.isEmpty else { return nil }
        let prevIndex = currentTrackIndex > 0 ? currentTrackIndex - 1 : playlist.count - 1
        return playlist[prevIndex]
    }
    
    // MARK: - Private Methods
    
    private func play(url: URL, loop: Bool = false) throws {
        stop() // Stop current playback
        
        player = try AVAudioPlayer(contentsOf: url)
        guard let player = player else { return }
        
        player.numberOfLoops = loop ? -1 : 0
        player.prepareToPlay()
        player.volume = volume
        player.play()
        
        duration = player.duration
        startTimeObserver()
        isPlaying = true
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        // Handle audio interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        
        // Handle route changes (headphones unplugged, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    private func startTimeObserver() {
        stopTimeObserver()
        timeObserver = CADisplayLink(target: self, selector: #selector(updateTime))
        timeObserver?.add(to: .main, forMode: .common)
    }
    
    private func stopTimeObserver() {
        timeObserver?.invalidate()
        timeObserver = nil
    }
    
    @objc private func updateTime() {
        guard let player = player else { return }
        currentTime = player.currentTime
        
        // If track finished and not looping, play next track
        if !player.isPlaying && player.numberOfLoops == 0 && currentTime >= duration {
            playNext()
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            pause()
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }
}
