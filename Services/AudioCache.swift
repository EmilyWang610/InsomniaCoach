//
//  AudioCache.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import Foundation
import CryptoKit   // 用于生成哈希，避免文件名冲突

final class AudioCache {
    static let shared = AudioCache()
    private let fm = FileManager.default
    private let dir: URL

    private init() {
        // 在 App 沙盒里找一个缓存目录：.../Library/Caches/AudioCache
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        dir = base.appendingPathComponent("AudioCache", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // 根据 key 生成唯一文件路径
    private func fileURL(forKey key: String, ext: String = "m4a") -> URL {
        let hash = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent("\(hash).\(ext)")
    }

    // ✅ 下载并缓存：如果文件已存在则直接返回，否则下载保存
    func cachedFile(forRemoteURL remote: URL, cacheKey: String) async throws -> URL {
        let ext = remote.pathExtension.isEmpty ? "m4a" : remote.pathExtension
        let local = fileURL(forKey: cacheKey, ext: ext)
        if fm.fileExists(atPath: local.path) { return local }

        let (data, _) = try await URLSession.shared.data(from: remote)
        try data.write(to: local, options: .atomic)
        return local
    }

    // ✅ 如果你已经有 Data，可以手动写入缓存
    func write(_ data: Data, cacheKey: String, ext: String = "m4a") throws -> URL {
        let url = fileURL(forKey: cacheKey, ext: ext)
        try data.write(to: url, options: .atomic)
        return url
    }

    // ✅ 清空缓存
    func clearAll() {
        try? fm.removeItem(at: dir)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
