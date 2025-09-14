//
//  MusicLibrary.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

// Services/MusicLibrary.swift
import Foundation
import AVFoundation

/// 音乐条目（存索引用；不要在索引里保存绝对路径，换沙盒会失效）
struct MusicItem: Identifiable, Codable, Equatable {
    let id: UUID
    let key: String        // 你在业务里生成的唯一键（例如 "concat-<timestamp>"）
    var title: String
    var fileName: String   // 真实文件名（存库时生成）
    var duration: TimeInterval
    var createdAt: Date

    // 运行时计算路径（不持久化）
    func fileURL(baseDir: URL) -> URL {
        baseDir.appendingPathComponent(fileName, conformingTo: .audio)
    }
}

/// 简单本地音乐库：管理缓存文件 + 一个 JSON 索引
final class MusicLibrary: ObservableObject {
    static let shared = MusicLibrary()

    @Published private(set) var items: [MusicItem] = []

    // 你可以改成 .documentDirectory，如果希望“卸载不清缓存”
    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "MusicLibrary.queue", qos: .userInitiated)

    private lazy var baseDir: URL = {
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioLibrary", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private lazy var indexURL: URL = {
        baseDir.appendingPathComponent("index.json")
    }()

    private init() {
        loadIndex()
    }

    // MARK: - Public API

    /// 把一个“已经存在”的音频文件纳入库中（会 move 到库目录），返回库内条目
    @discardableResult
    func add(title: String, key: String, fileURL src: URL) throws -> MusicItem {
        try ensureDir()
        // 生成库内文件名
        let ext = (src.pathExtension.isEmpty ? "m4a" : src.pathExtension)
        let fileName = "\(UUID().uuidString).\(ext)"
        let dst = baseDir.appendingPathComponent(fileName)

        // 如果是跨卷拷贝/生成于临时目录，先 move 不成就 copy
        do {
            try fm.moveItem(at: src, to: dst)
        } catch {
            try fm.copyItem(at: src, to: dst)
        }

        let dur = Self.probeDuration(url: dst) ?? 0
        let item = MusicItem(
            id: UUID(),
            key: key,
            title: title,
            fileName: fileName,
            duration: dur,
            createdAt: Date()
        )

        queue.sync {
            self.items.insert(item, at: 0) // 新的放前面
            self.saveIndex()
        }
        return item
    }

    /// 通过 key 找回条目（例如你用 concat 的 key）
    func item(forKey key: String) -> MusicItem? {
        items.first(where: { $0.key == key })
    }

    /// 取文件 URL（用于播放）
    func fileURL(for item: MusicItem) -> URL {
        item.fileURL(baseDir: baseDir)
    }

    /// 删除一个条目（索引 + 文件）
    func remove(_ item: MusicItem) {
        queue.sync {
            let url = item.fileURL(baseDir: baseDir)
            try? fm.removeItem(at: url)
            if let idx = items.firstIndex(of: item) {
                items.remove(at: idx)
            }
            saveIndex()
        }
    }

    /// 清理多余缓存（例如只保留最近 N 首）
    func trim(keepLatest count: Int) {
        guard items.count > count else { return }
        let toDelete = items.suffix(from: count)
        toDelete.forEach { try? fm.removeItem(at: $0.fileURL(baseDir: baseDir)) }
        items = Array(items.prefix(count))
        saveIndex()
    }

    /// 全清
    func clearAll() {
        queue.sync {
            items.forEach { try? fm.removeItem(at: $0.fileURL(baseDir: baseDir)) }
            items.removeAll()
            saveIndex()
        }
    }

    // MARK: - Index

    private func ensureDir() throws {
        if !fm.fileExists(atPath: baseDir.path) {
            try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        if let decoded = try? JSONDecoder().decode([MusicItem].self, from: data) {
            // 按时间降序
            self.items = decoded.sorted(by: { $0.createdAt > $1.createdAt })
        }
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Utils

    private static func probeDuration(url: URL) -> TimeInterval? {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            return p.duration
        } catch {
            return nil
        }
    }
}
