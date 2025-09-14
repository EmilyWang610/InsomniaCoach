//
//  TrackStore.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//


import Foundation

struct TrackItem: Identifiable, Codable, Equatable {
    let id: String              // 唯一 key（同时用作文件名）
    var title: String
    var createdAt: Date
    var durationSec: Double?
    // 只在运行时拼出来的路径，JSON 里只存 id
    var fileURL: URL {
        TrackStore.libraryDir.appendingPathComponent("\(id).m4a")
    }
}

final class TrackStore: ObservableObject {
    static let shared = TrackStore()
    @Published private(set) var items: [TrackItem] = []

    // Library 路径 & 索引文件
    static var libraryDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioLibrary", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    private let indexURL = libraryDir.appendingPathComponent("index.json")

    private init() {
        loadIndex()
    }

    // MARK: - Public API

    @discardableResult
    func add(title: String, from tempFileURL: URL, forceKey: String? = nil, durationSec: Double? = nil) throws -> TrackItem {
        let id = forceKey ?? "mix-\(Int(Date().timeIntervalSince1970))"
        let dest = Self.libraryDir.appendingPathComponent("\(id).m4a")

        // 如果不是库内文件，拷贝进来（覆盖旧文件）
        if tempFileURL.standardizedFileURL != dest.standardizedFileURL {
            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: tempFileURL, to: dest)
        }

        let item = TrackItem(id: id, title: title, createdAt: Date(), durationSec: durationSec)
        items.insert(item, at: 0) // 最新在最前
        saveIndex()
        return item
    }

    func fileURL(for item: TrackItem) -> URL {
        item.fileURL
    }

    func remove(_ item: TrackItem) {
        // 删文件
        let url = item.fileURL
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        // 删索引
        if let idx = items.firstIndex(of: item) {
            items.remove(at: idx)
            saveIndex()
        }
    }

    /// 只保留最近 N 首
    func trim(keepLatest n: Int) {
        guard items.count > n else { return }
        let toDelete = items.suffix(from: n)
        toDelete.forEach { remove($0) } // remove 内部会 saveIndex
    }

    // MARK: - Persistence

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        if let decoded = try? JSONDecoder().decode([TrackItem].self, from: data) {
            self.items = decoded
        }
    }

    private func saveIndex() {
        let data = try? JSONEncoder().encode(items)
        try? data?.write(to: indexURL, options: [.atomic])
    }
}
