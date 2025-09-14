//
//  AudioConcatenator.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import AVFoundation

final class AudioConcatenator {
    static let shared = AudioConcatenator()

    enum ConcatenateError: Error {
        case noTracks(URL)
        case exportFailed
    }

    func concatenate(_ a: URL, _ b: URL, outputKey: String) async throws -> URL {
        // 1) 读入两个 asset，并确保有轨道
        let assetA = AVURLAsset(url: a)
        let assetB = AVURLAsset(url: b)

        // iOS 15+ 的异步加载
        _ = try await assetA.load(.tracks)
        _ = try await assetB.load(.tracks)

        guard try await !assetA.load(.tracks).isEmpty else { throw ConcatenateError.noTracks(a) }
        guard try await !assetB.load(.tracks).isEmpty else { throw ConcatenateError.noTracks(b) }

        // 2) 组合
        let mix = AVMutableComposition()
        
        // Load tracks and durations asynchronously
        let tracksA = try await assetA.loadTracks(withMediaType: .audio)
        let tracksB = try await assetB.loadTracks(withMediaType: .audio)
        let durationA = try await assetA.load(.duration)
        let durationB = try await assetB.load(.duration)
        
        guard
            let trackA = tracksA.first,
            let trackB = tracksB.first,
            let compTrack = mix.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw ConcatenateError.exportFailed
        }

        try compTrack.insertTimeRange(CMTimeRange(start: .zero, duration: durationA), of: trackA, at: .zero)
        try compTrack.insertTimeRange(CMTimeRange(start: .zero, duration: durationB), of: trackB, at: durationA)

        // 3) 导出为 m4a (AAC)
        let caches = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let outURL = caches.appendingPathComponent("AudioCache/\(outputKey).m4a")

        // 目录存在性
        try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: outURL.path) {
            try FileManager.default.removeItem(at: outURL)
        }

        guard let exporter = AVAssetExportSession(asset: mix, presetName: AVAssetExportPresetAppleM4A) else {
            throw ConcatenateError.exportFailed
        }
        exporter.shouldOptimizeForNetworkUse = true

        // iOS 18：使用现代 async 版本
        try await exporter.export(to: outURL, as: .m4a)

        return outURL
    }
}
