//
//  AudioStudioView.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import Foundation
import SwiftUI

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

struct AudioStudioView: View {
    // 如果你把 TrackStore 放在 AppEnvironment，可改为 @EnvironmentObject var env: AppEnvironment
    @StateObject private var store = TrackStore.shared
    @StateObject private var playlistManager = PlaylistManager.shared

    @State private var log: String = ""
    @State private var isWorking = false
    @State private var showPlaylistControls = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                // 顶部操作区
                VStack(spacing: 12) {
                    Button {
                        Task { await generateConcatSaveAndPlay() }
                    } label: {
                        HStack {
                            if isWorking { ProgressView().tint(.white) }
                            Text(isWorking ? "Working..." : "Generate A/B → Concat → Save → Play")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isWorking)
                    
                    Button {
                        Task { await generatePlanMusic() }
                    } label: {
                        HStack {
                            if isWorking { ProgressView().tint(.white) }
                            Text(isWorking ? "Generating Plan..." : "Generate Sleep Plan Audio")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isWorking)

                    HStack {
                        Button("Trim to 10") { store.trim(keepLatest: 10) }
                            .buttonStyle(.bordered)
                        Button("Stop") { 
                            MusicPlayer.shared.stop()
                            playlistManager.stop()
                        }
                            .buttonStyle(.bordered)
                        Button("Play All") { 
                            playlistManager.loadPlaylist(store.items)
                            showPlaylistControls = true
                        }
                            .buttonStyle(.bordered)
                    }

                    // 简单日志
                    ScrollView {
                        Text(log)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(8)
                    }.frame(maxHeight: 80)
                }
                .padding(.horizontal)
                
                // Playlist Controls
                if showPlaylistControls && !playlistManager.playlist.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Playlist Controls")
                                .font(.headline)
                            Spacer()
                            Button("Hide") { showPlaylistControls = false }
                                .buttonStyle(.bordered)
                        }
                        
                        // Current Track Info
                        if let currentTrack = playlistManager.currentTrack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Now Playing: \(currentTrack.title)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Track \(playlistManager.currentTrackIndex + 1) of \(playlistManager.playlist.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Playback Controls
                        HStack(spacing: 20) {
                            Button(action: { playlistManager.playPrevious() }) {
                                Image(systemName: "backward.fill")
                                    .font(.title2)
                            }
                            .disabled(playlistManager.playlist.isEmpty)
                            
                            Button(action: { 
                                if playlistManager.isPlaying {
                                    playlistManager.pause()
                                } else {
                                    playlistManager.resume()
                                }
                            }) {
                                Image(systemName: playlistManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.largeTitle)
                            }
                            .disabled(playlistManager.playlist.isEmpty)
                            
                            Button(action: { playlistManager.playNext() }) {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                            }
                            .disabled(playlistManager.playlist.isEmpty)
                        }
                        
                        // Progress Bar
                        VStack(spacing: 4) {
                            HStack {
                                Text("\(Int(playlistManager.currentTime))s")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(playlistManager.duration))s")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            
                            ProgressView(value: playlistManager.duration > 0 ? playlistManager.currentTime / playlistManager.duration : 0)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // 曲库列表
                List {
                    Section("Library") {
                        ForEach(store.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title).font(.headline)
                                    Text(item.createdAt.formatted(date: .abbreviated, time: .standard))
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                Spacer()
                                Button {
                                    // Play individual track
                                    do {
                                        let url = store.fileURL(for: item)
                                        try MusicPlayer.shared.play(url: url, loop: true)
                                    } catch {
                                        print("play error:", error)
                                    }
                                } label: {
                                    Image(systemName: "play.circle.fill").font(.title2)
                                }
                                
                                Button {
                                    // Add to playlist and play
                                    if let index = store.items.firstIndex(of: item) {
                                        playlistManager.loadPlaylist(store.items, startFromIndex: index)
                                        showPlaylistControls = true
                                    }
                                } label: {
                                    Image(systemName: "list.bullet").font(.title2)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // 之前：MusicPlayer.shared.play(url: store.fileURL(for: item), loop: true)
                                do {
                                    let url = store.fileURL(for: item)
                                    try MusicPlayer.shared.play(url: url, loop: true)
                                } catch {
                                    print("play error:", error)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.map { store.items[$0] }.forEach { store.remove($0) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Audio Studio")
        }
    }

    // MARK: - Pipeline: A/B -> concat -> save -> play
    private func generateConcatSaveAndPlay() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            // 1) 准备 provider：你可以换成 AppEnvironment 的 provider
            let provider = MockMusicProvider()

            // 2) 生成两段（A/B）
            log = "Generating A..."
            let a = try await provider.generateTrack(prompt: "A soft ambient", style: "ambient", durationSec: 30)
            log = "Generating B..."
            let b = try await provider.generateTrack(prompt: "B soft ambient", style: "ambient", durationSec: 30)

            // 3) 拼接
            log = "Concatenating..."
            let key = "concat-\(Int(Date().timeIntervalSince1970))"
            let mergedURL = try await AudioConcatenator.shared.concatenate(a, b, outputKey: key)

            // 4) 入库 & 播放
            log = "Saving to library..."
            let item = try TrackStore.shared.add(title: "Mock Mix", from: mergedURL, forceKey: key, durationSec: 60)

            log = "Playing..."
            try MusicPlayer.shared.play(url: item.fileURL, loop: true)

            log = "✅ Done. Saved at: \(item.fileURL.lastPathComponent)"
        } catch {
            log = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Plan-based Music Generation
    private func generatePlanMusic() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        
        do {
            // 1) 从后端获取计划（这里需要实际的API调用）
            log = "Fetching sleep plan from backend..."
            // let plan = try await BackendAPIManager.shared.getLatestPlan()
            
            // 2) 创建示例计划用于测试
            let samplePlan = createSamplePlan()
            
            // 3) 生成计划音频
            log = "Generating plan audio with Suno..."
            let provider = SunoProvider() // Use real Suno API
            let audioURLs = try await provider.generatePlanAudio(plan: samplePlan)
            
            // 4) 保存到库并播放
            log = "Saving plan audio to library..."
            var savedItems: [TrackItem] = []
            
            for (index, audioURL) in audioURLs.enumerated() {
                let block = samplePlan.blocks[index]
                let item = try TrackStore.shared.add(
                    title: "\(block.musicType) - \(block.startMinute)-\(block.endMinute)min",
                    from: audioURL,
                    forceKey: "plan-\(block.id)",
                    durationSec: Double(block.durationSeconds)
                )
                savedItems.append(item)
            }
            
            // 5) Load into playlist and start playing
            log = "Loading playlist and starting playback..."
            playlistManager.loadPlaylist(savedItems)
            showPlaylistControls = true
            
            log = "✅ Plan audio generated! \(audioURLs.count) blocks created and loaded into playlist."
            
        } catch {
            log = "❌ Plan generation error: \(error.localizedDescription)"
        }
    }
    
    private func createSamplePlan() -> AdaptivePlan {
        let blocks = [
            MusicBlock(
                id: "block-1",
                musicType: "wind-down",
                targetSleepStage: "inBed",
                startMinute: 0,
                endMinute: 30,
                targetVolume: 0.6,
                frequencyRange: FrequencyRange(low: 40, high: 60, target: 50),
                binauralBeatFreq: nil,
                audioLoopId: "loop-wind-down",
                llmPrompt: "Calming wind-down music with gentle pads and soft piano",
                createdAt: Date().iso8601String
            ),
            MusicBlock(
                id: "block-2",
                musicType: "deep-sleep",
                targetSleepStage: "asleepDeep",
                startMinute: 30,
                endMinute: 150,
                targetVolume: 0.4,
                frequencyRange: FrequencyRange(low: 20, high: 80, target: 40),
                binauralBeatFreq: 2.0,
                audioLoopId: "loop-deep-sleep",
                llmPrompt: "Deep sleep inducing audio with delta waves and nature sounds",
                createdAt: Date().iso8601String
            ),
            MusicBlock(
                id: "block-3",
                musicType: "rem-sleep",
                targetSleepStage: "asleepREM",
                startMinute: 150,
                endMinute: 210,
                targetVolume: 0.5,
                frequencyRange: FrequencyRange(low: 80, high: 300, target: 160),
                binauralBeatFreq: 6.0,
                audioLoopId: "loop-rem-sleep",
                llmPrompt: "Dreamy REM sleep audio with ethereal textures",
                createdAt: Date().iso8601String
            ),
            MusicBlock(
                id: "block-4",
                musicType: "light-sleep",
                targetSleepStage: "asleepCore",
                startMinute: 210,
                endMinute: 450,
                targetVolume: 0.4,
                frequencyRange: FrequencyRange(low: 60, high: 200, target: 120),
                binauralBeatFreq: 10.0,
                audioLoopId: "loop-light-sleep",
                llmPrompt: "Stable light/core sleep audio with consistent rhythm",
                createdAt: Date().iso8601String
            ),
            MusicBlock(
                id: "block-5",
                musicType: "sunrise",
                targetSleepStage: "awake",
                startMinute: 450,
                endMinute: 480,
                targetVolume: 0.7,
                frequencyRange: FrequencyRange(low: 120, high: 800, target: 240),
                binauralBeatFreq: nil,
                audioLoopId: "loop-sunrise",
                llmPrompt: "Gentle sunrise audio with gradual awakening",
                createdAt: Date().iso8601String
            )
        ]
        
        return AdaptivePlan(
            id: "sample-plan-\(Int(Date().timeIntervalSince1970))",
            name: "Sample Sleep Plan",
            provider: "Mock Provider",
            isActive: true,
            createdAt: Date().iso8601String,
            expiresAt: nil,
            blocks: blocks,
            sleepAnalysisData: "Sample sleep analysis data",
            llmModel: "gpt-4",
            generationPrompt: "Sample generation prompt"
        )
    }
}
