//
//  MusicPlayer.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

// Services/MusicPlayer.swift
import Foundation
import AVFoundation
import Combine

/// 轻量音乐播放器：本地文件 URL 播放
final class MusicPlayer: ObservableObject {
    static let shared = MusicPlayer()

    // 对外可观察状态
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var volume: Float = 1.0

    private var player: AVAudioPlayer?
    private var timeObserver: CADisplayLink?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 后台播放类别
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])

        // 处理中断（来电/闹钟等）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )

        // 处理音频路由变化（耳机拔出等）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    // MARK: - Public API

    /// 播放本地文件；loop=true 则无限循环
    func play(url: URL, loop: Bool = true, startAt: TimeInterval = 0) throws {
        stop() // 确保切歌不叠音
        player = try AVAudioPlayer(contentsOf: url)
        guard let p = player else { return }

        p.numberOfLoops = loop ? -1 : 0
        p.prepareToPlay()
        p.currentTime = startAt
        p.volume = volume
        p.play()

        duration = p.duration
        startTick()
        isPlaying = true
    }

    func pause() {
        guard let p = player, p.isPlaying else { return }
        p.pause()
        isPlaying = false
        stopTick()
    }

    func resume() {
        guard let p = player, !p.isPlaying else { return }
        p.play()
        isPlaying = true
        startTick()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTick()
    }

    /// 跳转到秒
    func seek(to seconds: TimeInterval) {
        guard let p = player else { return }
        p.currentTime = max(0, min(seconds, p.duration))
        currentTime = p.currentTime
    }

    /// 设置音量（0~1）
    func setVolume(_ value: Float) {
        volume = max(0, min(value, 1))
        player?.volume = volume
    }

    /// 淡入：在 duration 秒内从当前音量渐进到 target
    func fade(to target: Float, duration: TimeInterval = 1.0) {
        guard duration > 0 else { setVolume(target); return }
        let steps = 30
        let interval = duration / Double(steps)
        let start = player?.volume ?? volume
        let delta = (target - start) / Float(steps)

        var count = 0
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            count += 1
            self.setVolume(start + Float(count) * delta)
            if count >= steps { t.invalidate() }
        }
    }

    // MARK: - Private

    private func startTick() {
        stopTick()
        timeObserver = CADisplayLink(target: self, selector: #selector(onTick))
        timeObserver?.add(to: .main, forMode: .common)
    }

    private func stopTick() {
        timeObserver?.invalidate()
        timeObserver = nil
    }

    @objc private func onTick() {
        guard let p = player else { return }
        currentTime = p.currentTime
        // 当非循环且自然播放结束，重置状态
        if !p.isPlaying && p.numberOfLoops == 0 && currentTime >= duration {
            stop()
        }
    }

    // MARK: - Notifications

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // 被打断，更新 UI
            isPlaying = false
            stopTick()
        case .ended:
            // 可恢复时带上 option 判断是否自动继续
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue ?? 0)
            if options.contains(.shouldResume) {
                player?.play()
                isPlaying = true
                startTick()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        // 耳机拔出时自动暂停
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }
}
