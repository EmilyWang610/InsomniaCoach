//
//  BackendTestView.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import SwiftUI

struct BackendTestView: View {
    @EnvironmentObject var env: AppEnvironment
    @StateObject private var trackStore = TrackStore.shared
    @StateObject private var musicPlayer = MusicPlayer.shared
    @State private var testLog = "Ready to test backend integration"
    @State private var isProcessing = false
    @State private var showBackendData = false
    @State private var backendData: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                HStack {
                    Circle()
                        .fill(env.backendAPI.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(env.backendAPI.isConnected ? "Connected to Backend" : "Disconnected")
                        .foregroundColor(env.backendAPI.isConnected ? .green : .red)
                    
                    Spacer()
                    
                    Button("Check Health") {
                        env.backendAPI.checkHealth()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Test Buttons
                VStack(spacing: 12) {
                    Button("Test Night Data Processing") {
                        testNightDataProcessing()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isProcessing)
                    
                    Button("Get Latest Plan") {
                        getLatestPlan()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                    
                    Button("Check Agent Status") {
                        checkAgentStatus()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                    
                    // Audio Library Section
                    VStack(spacing: 8) {
                        Text("Audio Library (\(trackStore.items.count) tracks)")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        HStack(spacing: 12) {
                            Button("🎵 Test Music") {
                                testMusicPlayback()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .disabled(trackStore.items.isEmpty || isProcessing)
                            
                            Button("📊 Show Backend Data") {
                                loadBackendData()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isProcessing)
                            
                            Button("⏹️ Stop Audio") {
                                musicPlayer.stop()
                                testLog += "Audio stopped\n"
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        
                        // Quick test audio generation
                        if trackStore.items.isEmpty {
                            Button("🎼 Generate Test Audio") {
                                generateTestAudio()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(isProcessing)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Processing Status
                if isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Backend Data Display
                if showBackendData && !backendData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Backend Data")
                                .font(.headline)
                            Spacer()
                            Button("Hide") {
                                showBackendData = false
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        ScrollView {
                            Text(backendData)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Test Log
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Log")
                        .font(.headline)
                    
                    ScrollView {
                        Text(testLog)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Backend Test")
        }
    }
    
    private func testNightDataProcessing() {
        isProcessing = true
        testLog = "Starting night data processing test...\n"
        
        Task {
            do {
                // Create a mock sleep session
                let mockSession = SleepSession(
                    startTime: Date().addingTimeInterval(-28800), // 8 hours ago
                    endTime: Date()
                )
                
                testLog += "Created mock sleep session\n"
                testLog += "Duration: \(Int(mockSession.duration / 3600)) hours\n"
                
                // Process the night data
                await env.nightProcessor.processNightData(
                    sleepSession: mockSession,
                    quality: 85,
                    notes: "Test sleep session from iOS app"
                )
                
                await MainActor.run {
                    if let plan = env.nightProcessor.currentPlan {
                        testLog += "✅ Success! Generated plan with \(plan.blocks.count) blocks\n"
                        testLog += "Plan ID: \(plan.id)\n"
                        testLog += "Summary: \(plan.summary)\n"
                    } else if let error = env.nightProcessor.processingError {
                        testLog += "❌ Error: \(error)\n"
                    }
                    isProcessing = false
                }
                
            } catch {
                await MainActor.run {
                    testLog += "❌ Error: \(error.localizedDescription)\n"
                    isProcessing = false
                }
            }
        }
    }
    
    private func getLatestPlan() {
        isProcessing = true
        testLog = "Getting latest plan...\n"
        
        Task {
            await env.nightProcessor.refreshLatestPlan()
            
            await MainActor.run {
                if let plan = env.nightProcessor.currentPlan {
                    testLog += "✅ Latest plan retrieved\n"
                    testLog += "Plan ID: \(plan.id)\n"
                    testLog += "Night Date: \(plan.nightDate)\n"
                    testLog += "Blocks: \(plan.blocks.count)\n"
                } else {
                    testLog += "No plan available\n"
                }
                isProcessing = false
            }
        }
    }
    
    private func checkAgentStatus() {
        isProcessing = true
        testLog = "Checking agent status...\n"
        
        Task {
            if let status = await env.nightProcessor.checkAgentStatus() {
                await MainActor.run {
                    testLog += "✅ Agent Status:\n"
                    testLog += "Ready: \(status.ready)\n"
                    testLog += "OpenAI Configured: \(status.openaiConfigured)\n"
                    testLog += "Suno Stub: \(status.features.sunoStub)\n"
                    testLog += "Analysis Enabled: \(status.features.analysisEnabled)\n"
                    isProcessing = false
                }
            } else {
                await MainActor.run {
                    testLog += "❌ Failed to get agent status\n"
                    isProcessing = false
                }
            }
        }
    }
    
    // MARK: - New Functions
    
    private func testMusicPlayback() {
        guard !trackStore.items.isEmpty else {
            testLog += "❌ No audio tracks available in library\n"
            return
        }
        
        testLog += "🎵 Testing music playback...\n"
        
        // Get the most recent track
        let latestTrack = trackStore.items.first!
        testLog += "Playing: \(latestTrack.title)\n"
        
        do {
            let url = trackStore.fileURL(for: latestTrack)
            try musicPlayer.play(url: url, loop: true)
            testLog += "✅ Audio started successfully\n"
        } catch {
            testLog += "❌ Audio playback error: \(error.localizedDescription)\n"
        }
    }
    
    private func loadBackendData() {
        isProcessing = true
        testLog += "📊 Loading backend data...\n"
        
        Task {
            do {
                // Collect data from multiple endpoints safely
                var dataString = "=== BACKEND DATA SUMMARY ===\n\n"
                
                // 1. Health Check
                dataString += "🏥 HEALTH STATUS:\n"
                if env.backendAPI.isConnected {
                    dataString += "✅ Backend is connected\n"
                } else {
                    dataString += "❌ Backend is disconnected\n"
                }
                
                // 2. Agent Status
                dataString += "\n🤖 AGENT STATUS:\n"
                if let status = await env.nightProcessor.checkAgentStatus() {
                    dataString += "Ready: \(status.ready)\n"
                    dataString += "OpenAI Configured: \(status.openaiConfigured)\n"
                    dataString += "Features: \(status.features)\n"
                } else {
                    dataString += "❌ Failed to get agent status\n"
                }
                
                // 3. Current Plan
                dataString += "\n📋 CURRENT PLAN:\n"
                if let plan = env.nightProcessor.currentPlan {
                    dataString += "Plan ID: \(plan.id)\n"
                    dataString += "Night Date: \(plan.nightDate)\n"
                    dataString += "Blocks: \(plan.blocks.count)\n"
                    dataString += "Summary: \(plan.summary)\n"
                } else {
                    dataString += "No current plan available\n"
                }
                
                // 4. Audio Library Info
                dataString += "\n🎵 AUDIO LIBRARY:\n"
                dataString += "Total Tracks: \(trackStore.items.count)\n"
                if !trackStore.items.isEmpty {
                    dataString += "Latest Track: \(trackStore.items.first!.title)\n"
                    dataString += "Created: \(trackStore.items.first!.createdAt.formatted())\n"
                }
                
                // 5. Processing Status
                dataString += "\n⚙️ PROCESSING STATUS:\n"
                if let error = env.nightProcessor.processingError {
                    dataString += "Last Error: \(error)\n"
                } else {
                    dataString += "No recent errors\n"
                }
                
                await MainActor.run {
                    self.backendData = dataString
                    self.showBackendData = true
                    self.testLog += "✅ Backend data loaded successfully\n"
                    self.isProcessing = false
                }
                
            } catch {
                await MainActor.run {
                    self.testLog += "❌ Error loading backend data: \(error.localizedDescription)\n"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func generateTestAudio() {
        isProcessing = true
        testLog += "🎼 Generating test audio...\n"
        
        Task {
            do {
                let provider = MockMusicProvider()
                let audioURL = try await provider.generateTrack(
                    prompt: "Test audio for backend testing",
                    style: "ambient",
                    durationSec: 30
                )
                
                let item = try trackStore.add(
                    title: "Test Audio - \(Date().formatted(date: .abbreviated, time: .shortened))",
                    from: audioURL,
                    durationSec: 30.0
                )
                
                await MainActor.run {
                    testLog += "✅ Test audio generated: \(item.title)\n"
                    isProcessing = false
                }
                
            } catch {
                await MainActor.run {
                    testLog += "❌ Failed to generate test audio: \(error.localizedDescription)\n"
                    isProcessing = false
                }
            }
        }
    }
}

#Preview {
    BackendTestView()
        .environmentObject(AppEnvironment())
}
