//
//  MockMusicProvider.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import Foundation
import AVFoundation

// 抽象协议：将来换 SunoProvider 也用它
protocol MusicProviding {
    /// 返回"已缓存到本地"的音频文件 URL
    func generateTrack(prompt: String, style: String?, durationSec: Int?) async throws -> URL
}

// 扩展协议以支持计划生成
protocol PlanMusicProviding: MusicProviding {
    /// 生成整个睡眠计划的音频
    func generatePlanAudio(plan: AdaptivePlan) async throws -> [URL]
    /// 生成单个块的音频
    func generateBlockAudio(block: MusicBlock) async throws -> URL
}

// 音乐块数据结构
struct MusicBlock: Codable {
    let id: String
    let musicType: String
    let targetSleepStage: String
    let startMinute: Int
    let endMinute: Int
    let targetVolume: Float
    let frequencyRange: FrequencyRange
    let binauralBeatFreq: Float?
    let audioLoopId: String
    let llmPrompt: String
    let createdAt: String
    
    var durationMinutes: Int {
        return endMinute - startMinute
    }
    
    var durationSeconds: Int {
        return durationMinutes * 60
    }
}

struct FrequencyRange: Codable {
    let low: Float
    let high: Float
    let target: Float
}

// 自适应计划数据结构
struct AdaptivePlan: Codable {
    let id: String
    let name: String
    let provider: String
    let isActive: Bool
    let createdAt: String
    let expiresAt: String?
    let blocks: [MusicBlock]
    let sleepAnalysisData: String
    let llmModel: String
    let generationPrompt: String
}

// Mock 实现：不连 Suno，用两条公开 https 音频当"生成结果"
struct MockMusicProvider: PlanMusicProviding {
    let cache: AudioCache = .shared
    private let maxCacheDays = 2 // 存储最多2晚的音频

    func generateTrack(prompt: String, style: String?, durationSec: Int?) async throws -> URL {
        // 你可以换成别的 https 音频链接（必须是 https）
        let demo1 = URL(string:
          "https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Komiku/Its_time_for_adventure/Komiku_-_01_-_Chibi_Ninja.mp3"
        )!
        let demo2 = URL(string:
          "https://files.freemusicarchive.org/storage-freemusicarchive-org/music/no_curator/Komiku/Its_time_for_adventure/Komiku_-_06_-_Battle_of_Pogs.mp3"
        )!

        // 简单分流：prompt 含 "B" 用第二首，否则第一首
        let remote = prompt.contains("B") ? demo2 : demo1

        // 缓存键（相同参数下次直接命中缓存）
        let key = "mock|\(prompt)|\(style ?? "")|\(durationSec ?? 0)|\(remote.absoluteString)"

        // 下载并缓存，返回本地文件 URL
        return try await cache.cachedFile(forRemoteURL: remote, cacheKey: key)
    }
    
    // MARK: - Plan Music Generation
    
    func generatePlanAudio(plan: AdaptivePlan) async throws -> [URL] {
        var generatedAudio: [URL] = []
        
        // 清理旧缓存（保留最近2晚）
        try await cleanOldCache()
        
        for (index, block) in plan.blocks.enumerated() {
            print("🎵 Generating audio for block \(index + 1)/\(plan.blocks.count): \(block.musicType)")
            let audioURL = try await generateBlockAudio(block: block)
            generatedAudio.append(audioURL)
        }
        
        return generatedAudio
    }
    
    func generateBlockAudio(block: MusicBlock) async throws -> URL {
        // 检查缓存
        let cacheKey = "block|\(block.id)|\(block.llmPrompt)|\(block.durationSeconds)"
        
        if let cachedURL = try? getCachedAudio(cacheKey: cacheKey) {
            print("📦 Using cached audio for block: \(block.musicType)")
            return cachedURL
        }
        
        // 生成音频
        let audioURL = try await generateTrackWithFade(
            prompt: block.llmPrompt,
            style: block.musicType,
            durationSec: block.durationSeconds,
            volume: block.targetVolume,
            frequencyRange: block.frequencyRange,
            binauralBeat: block.binauralBeatFreq
        )
        
        // 缓存音频
        try await cacheAudio(audioURL: audioURL, cacheKey: cacheKey)
        
        return audioURL
    }
    
    // MARK: - Private Methods
    
    private func generateTrackWithFade(
        prompt: String,
        style: String?,
        durationSec: Int,
        volume: Float,
        frequencyRange: FrequencyRange,
        binauralBeat: Float?
    ) async throws -> URL {
        // 生成多个较短片段并循环播放
        let segmentDuration = min(durationSec, 300) // 最大5分钟每段
        let segmentsNeeded = max(1, (durationSec + segmentDuration - 1) / segmentDuration)
        
        var segmentURLs: [URL] = []
        
        // 生成片段
        for i in 0..<segmentsNeeded {
            let segmentPrompt = createSegmentPrompt(
                prompt: prompt,
                style: style,
                segmentIndex: i,
                totalSegments: segmentsNeeded,
                frequencyRange: frequencyRange,
                binauralBeat: binauralBeat
            )
            
            let segmentURL = try await generateTrack(
                prompt: segmentPrompt,
                style: style,
                durationSec: segmentDuration
            )
            segmentURLs.append(segmentURL)
        }
        
        // 如果只有一个片段且时长匹配，直接返回
        if segmentsNeeded == 1 && segmentDuration == durationSec {
            return try await applyVolumeAndFade(audioURL: segmentURLs[0], volume: volume)
        }
        
        // 否则，连接片段并循环以匹配总时长
        return try await concatenateAndLoop(
            segments: segmentURLs,
            targetDuration: durationSec,
            volume: volume
        )
    }
    
    private func createSegmentPrompt(
        prompt: String,
        style: String?,
        segmentIndex: Int,
        totalSegments: Int,
        frequencyRange: FrequencyRange,
        binauralBeat: Float?
    ) -> String {
        var segmentPrompt = prompt
        
        if let style = style {
            segmentPrompt += " Style: \(style)"
        }
        
        // 添加频率范围信息
        segmentPrompt += " Frequency range: \(frequencyRange.low)-\(frequencyRange.high) Hz, target: \(frequencyRange.target) Hz"
        
        // 添加双耳节拍信息
        if let binauralBeat = binauralBeat {
            segmentPrompt += " Binaural beat: \(binauralBeat) Hz"
        }
        
        if totalSegments > 1 {
            segmentPrompt += " (Part \(segmentIndex + 1) of \(totalSegments))"
        }
        
        // 添加循环指令
        segmentPrompt += " Seamless loop, no fade in/out, consistent tempo and key throughout."
        
        return segmentPrompt
    }
    
    private func concatenateAndLoop(
        segments: [URL],
        targetDuration: Int,
        volume: Float
    ) async throws -> URL {
        let concatenator = AudioConcatenator.shared
        let outputKey = "plan-concat-\(Int(Date().timeIntervalSince1970))"
        
        // 连接所有片段
        var currentURL = segments[0]
        for i in 1..<segments.count {
            currentURL = try await concatenator.concatenate(
                currentURL,
                segments[i],
                outputKey: "\(outputKey)-\(i)"
            )
        }
        
        // 如果需要循环以达到目标时长，创建循环版本
        let segmentDuration = try await getAudioDuration(url: currentURL)
        let loopsNeeded = max(1, targetDuration / Int(segmentDuration))
        
        if loopsNeeded > 1 {
            currentURL = try await createLoopedAudio(
                originalURL: currentURL,
                loops: loopsNeeded,
                outputKey: outputKey
            )
        }
        
        // 应用音量和淡入淡出
        return try await applyVolumeAndFade(audioURL: currentURL, volume: volume)
    }
    
    private func createLoopedAudio(originalURL: URL, loops: Int, outputKey: String) async throws -> URL {
        var currentURL = originalURL
        
        for i in 1..<loops {
            let loopKey = "\(outputKey)-loop-\(i)"
            currentURL = try await AudioConcatenator.shared.concatenate(
                currentURL,
                originalURL,
                outputKey: loopKey
            )
        }
        
        return currentURL
    }
    
    private func applyVolumeAndFade(audioURL: URL, volume: Float) async throws -> URL {
        // 这里应该实现音量调整和淡入淡出
        // 暂时直接返回原文件
        return audioURL
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        let player = try AVAudioPlayer(contentsOf: url)
        return player.duration
    }
    
    private func getCachedAudio(cacheKey: String) throws -> URL? {
        // 检查缓存是否存在
        let fileManager = FileManager.default
        let cacheDir = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AudioCache")
        
        let cachedFile = cacheDir.appendingPathComponent("\(cacheKey).mp3")
        
        if fileManager.fileExists(atPath: cachedFile.path) {
            return cachedFile
        }
        
        return nil
    }
    
    private func cacheAudio(audioURL: URL, cacheKey: String) async throws {
        let fileManager = FileManager.default
        let cacheDir = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AudioCache")
        
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        let cachedFile = cacheDir.appendingPathComponent("\(cacheKey).mp3")
        try fileManager.copyItem(at: audioURL, to: cachedFile)
    }
    
    private func cleanOldCache() async throws {
        let fileManager = FileManager.default
        let cacheDir = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AudioCache")
        
        let files = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey])
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(maxCacheDays * 24 * 60 * 60))
        
        for file in files {
            let attributes = try fileManager.attributesOfItem(atPath: file.path)
            if let creationDate = attributes[.creationDate] as? Date,
               creationDate < cutoffDate {
                try fileManager.removeItem(at: file)
            }
        }
    }
}
