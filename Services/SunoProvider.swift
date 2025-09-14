//
//  SunoProvider.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import Foundation
import AVFoundation
import CryptoKit

// Real Suno API integration for music generation
struct SunoProvider: PlanMusicProviding {
    let cache: AudioCache = .shared
    
    // Suno API configuration
    private let sunoAPIKey: String
    private let sunoBaseURL = "https://studio-api.prod.suno.com/api/v2/external/hackmit"
    
    // Rate limiting
    private let maxRequestsPerMinute = 60
    private static var requestTimes: [Date] = []
    private static let rateLimitQueue = DispatchQueue(label: "suno.rate.limit")
    
    init(apiKey: String = "7e74d019b8be4c558e17660a807cf1d8") {
        self.sunoAPIKey = apiKey
    }
    
    func generateTrack(prompt: String, style: String?, durationSec: Int?) async throws -> URL {
        // Generate multiple shorter segments and loop them for long durations
        let segmentDuration = min(durationSec ?? 30, 300) // Max 5 minutes per segment
        let totalDuration = durationSec ?? 30
        let segmentsNeeded = max(1, (totalDuration + segmentDuration - 1) / segmentDuration)
        
        var segmentURLs: [URL] = []
        
        // Generate segments
        for i in 0..<segmentsNeeded {
            let segmentPrompt = createSegmentPrompt(prompt: prompt, style: style, segmentIndex: i, totalSegments: segmentsNeeded)
            let segmentURL = try await generateSunoTrack(prompt: segmentPrompt, durationSec: segmentDuration)
            segmentURLs.append(segmentURL)
        }
        
        // If only one segment and it matches the duration, return it directly
        if segmentsNeeded == 1 && segmentDuration == totalDuration {
            return segmentURLs[0]
        }
        
        // Otherwise, concatenate segments and loop to match total duration
        return try await concatenateAndLoop(segments: segmentURLs, targetDuration: totalDuration)
    }
    
    // MARK: - PlanMusicProviding Methods
    
    func generatePlanAudio(plan: AdaptivePlan) async throws -> [URL] {
        var generatedAudio: [URL] = []
        
        for (index, block) in plan.blocks.enumerated() {
            print("🎵 Generating audio for block \(index + 1)/\(plan.blocks.count): \(block.musicType)")
            let audioURL = try await generateBlockAudio(block: block)
            generatedAudio.append(audioURL)
        }
        
        return generatedAudio
    }
    
    func generateBlockAudio(block: MusicBlock) async throws -> URL {
        // Check cache first
        let cacheKey = "block|\(block.id)|\(block.llmPrompt)|\(block.durationSeconds)"
        
        if let cachedURL = try? await cache.cachedFile(forRemoteURL: URL(string: "suno://cache")!, cacheKey: cacheKey) {
            print("📦 Using cached audio for block: \(block.musicType)")
            return cachedURL
        }
        
        // Generate audio with block-specific parameters
        let audioURL = try await generateTrackWithBlockParams(block: block)
        
        return audioURL
    }
    
    private func generateTrackWithBlockParams(block: MusicBlock) async throws -> URL {
        // Create enhanced prompt with block parameters
        var enhancedPrompt = block.llmPrompt
        
        // Add frequency range information
        enhancedPrompt += " Frequency range: \(block.frequencyRange.low)-\(block.frequencyRange.high) Hz, target: \(block.frequencyRange.target) Hz"
        
        // Add binaural beat information
        if let binauralBeat = block.binauralBeatFreq {
            enhancedPrompt += " Binaural beat: \(binauralBeat) Hz"
        }
        
        // Add volume and style information
        enhancedPrompt += " Style: \(block.musicType), Target volume: \(block.targetVolume)"
        
        // Generate the track
        let audioURL = try await generateTrack(
            prompt: enhancedPrompt,
            style: block.musicType,
            durationSec: block.durationSeconds
        )
        
        // Apply volume adjustment if needed
        if block.targetVolume != 1.0 {
            return try await applyVolumeAdjustment(audioURL: audioURL, volume: block.targetVolume)
        }
        
        return audioURL
    }
    
    private func applyVolumeAdjustment(audioURL: URL, volume: Float) async throws -> URL {
        // For now, return the original URL
        // TODO: Implement actual volume adjustment using AVAudioEngine
        return audioURL
    }
    
    // MARK: - Private Methods
    
    private func generateSunoTrack(prompt: String, durationSec: Int) async throws -> URL {
        let cacheKey = "suno|\(prompt)|\(durationSec)|\(sunoAPIKey.prefix(8))"
        
        // Check cache first
        if let cachedURL = try? await cache.cachedFile(forRemoteURL: URL(string: "suno://cache")!, cacheKey: cacheKey) {
            return cachedURL
        }
        
        // Prepare Suno API request
        let request = createSunoRequest(prompt: prompt, durationSec: durationSec)
        
        // Make API call to Suno
        let audioData = try await makeSunoAPICall(request: request)
        
        // Save to cache and return local URL
        return try await saveAudioToCache(audioData: audioData, cacheKey: cacheKey)
    }
    
    private func createSunoRequest(prompt: String, durationSec: Int) -> [String: Any] {
        return [
            "topic": prompt, // Use topic for simple mode include time frame as well
            "tags": "ambient, sleep, relaxation, binaural, instrumental",
            "make_instrumental": true 
        ]
    }
    
    private func makeSunoAPICall(request: [String: Any]) async throws -> Data {
        // Check rate limit
        try await checkRateLimit()
        
        guard let url = URL(string: "\(sunoBaseURL)/generate") else {
            throw SunoError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(sunoAPIKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONSerialization.data(withJSONObject: request)
        urlRequest.httpBody = jsonData
        
        print("🎵 Making Suno API call to: \(url)")
        print("🎵 Request: \(String(data: jsonData, encoding: .utf8) ?? "Invalid JSON")")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SunoError.apiError("Invalid response from Suno API")
        }
        
        print("🎵 Suno API response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SunoError.apiError("Suno API call failed with status \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse response to get job ID
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("🎵 Suno API response: \(json)")
            
            // Check if we got a job ID (asynchronous generation)
            if let jobId = json["id"] as? String {
                print("🎵 Job submitted with ID: \(jobId)")
                // Poll for completion
                return try await pollForCompletion(jobId: jobId)
            } else {
                // Check for immediate audio URL (synchronous generation)
                var audioURLString: String?
                
                if let audioURL = json["audio_url"] as? String {
                    audioURLString = audioURL
                } else if let audioURL = json["audioUrl"] as? String {
                    audioURLString = audioURL
                } else if let result = json["result"] as? [String: Any],
                          let audioURL = result["audio_url"] as? String {
                    audioURLString = audioURL
                } else if let results = json["results"] as? [[String: Any]],
                          let firstResult = results.first,
                          let audioURL = firstResult["audio_url"] as? String {
                    audioURLString = audioURL
                }
                
                if let audioURLString = audioURLString,
                   let audioURL = URL(string: audioURLString) {
                    print("🎵 Downloading audio from: \(audioURLString)")
                    // Download the actual audio file
                    let (audioData, _) = try await URLSession.shared.data(from: audioURL)
                    print("🎵 Downloaded \(audioData.count) bytes of audio data")
                    return audioData
                } else {
                    print("🎵 Could not find audio URL in response")
                    throw SunoError.invalidResponse
                }
            }
        } else {
            throw SunoError.invalidResponse
        }
    }
    
    private func saveAudioToCache(audioData: Data, cacheKey: String) async throws -> URL {
        let fileManager = FileManager.default
        
        // Save to TrackStore directory (iOS app's cache directory)
        let trackStoreDir = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AudioLibrary")
        
        try fileManager.createDirectory(at: trackStoreDir, withIntermediateDirectories: true)
        
        // First save as temporary MP3 file
        let tempFileName = "\(cacheKey).mp3"
        let tempFileURL = trackStoreDir.appendingPathComponent(tempFileName)
        try audioData.write(to: tempFileURL)
        
        // Convert to M4A format for iOS compatibility
        let finalFileName = "\(cacheKey).m4a"
        let finalFileURL = trackStoreDir.appendingPathComponent(finalFileName)
        
        try await convertToM4A(inputURL: tempFileURL, outputURL: finalFileURL)
        
        // Clean up temporary MP3 file
        try? fileManager.removeItem(at: tempFileURL)
        
        // Update TrackStore index
        try await updateTrackStoreIndex(fileURL: finalFileURL, cacheKey: cacheKey)
        
        return finalFileURL
    }
    
    private func createSegmentPrompt(prompt: String, style: String?, segmentIndex: Int, totalSegments: Int) -> String {
        var segmentPrompt = prompt
        
        if let style = style {
            segmentPrompt += " Style: \(style)"
        }
        
        if totalSegments > 1 {
            segmentPrompt += " (Part \(segmentIndex + 1) of \(totalSegments))"
        }
        
        // Add specific instructions for looping
        segmentPrompt += " Seamless loop, no fade in/out, consistent tempo and key throughout."
        
        return segmentPrompt
    }
    
    private func concatenateAndLoop(segments: [URL], targetDuration: Int) async throws -> URL {
        let concatenator = AudioConcatenator.shared
        let outputKey = "suno-concat-\(Int(Date().timeIntervalSince1970))"
        
        // Concatenate all segments
        var currentURL = segments[0]
        for i in 1..<segments.count {
            currentURL = try await concatenator.concatenate(currentURL, segments[i], outputKey: "\(outputKey)-\(i)")
        }
        
        // If we need to loop to reach target duration, create a looped version
        let segmentDuration = try await getAudioDuration(url: currentURL)
        let loopsNeeded = max(1, targetDuration / Int(segmentDuration))
        
        if loopsNeeded > 1 {
            return try await createLoopedAudio(originalURL: currentURL, loops: loopsNeeded, outputKey: outputKey)
        }
        
        return currentURL
    }
    
    private func createLoopedAudio(originalURL: URL, loops: Int, outputKey: String) async throws -> URL {
        // This would create a looped version of the audio
        // For now, we'll use the concatenator to repeat the segment
        var currentURL = originalURL
        
        for i in 1..<loops {
            let loopKey = "\(outputKey)-loop-\(i)"
            currentURL = try await AudioConcatenator.shared.concatenate(currentURL, originalURL, outputKey: loopKey)
        }
        
        return currentURL
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        // Get audio duration using AVURLAsset
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }
    
    private func pollForCompletion(jobId: String) async throws -> Data {
        let maxAttempts = 60 // 5 minutes max wait time
        let pollInterval: TimeInterval = 5 // Poll every 5 seconds
        
        for attempt in 1...maxAttempts {
            print("🎵 Polling job \(jobId) (attempt \(attempt)/\(maxAttempts))")
            
            guard let statusURL = URL(string: "\(sunoBaseURL)/clips?ids=\(jobId)") else {
                throw SunoError.invalidURL
            }
            
            var statusRequest = URLRequest(url: statusURL)
            statusRequest.httpMethod = "GET"
            statusRequest.setValue("Bearer \(sunoAPIKey)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: statusRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw SunoError.apiError("Failed to check job status")
            }
            
            if let clipsArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let clip = clipsArray.first {
                print("🎵 Job status: \(clip)")
                
                if let status = clip["status"] as? String {
                    switch status {
                    case "complete":
                        // Job completed, get the audio URL
                        if let audioURLString = clip["audio_url"] as? String,
                           let audioURL = URL(string: audioURLString) {
                            print("🎵 Job completed! Downloading audio from: \(audioURLString)")
                            let (audioData, _) = try await URLSession.shared.data(from: audioURL)
                            print("🎵 Downloaded \(audioData.count) bytes of audio data")
                            return audioData
                        } else {
                            throw SunoError.audioGenerationFailed
                        }
                    case "streaming":
                        // Job is streaming, get the audio URL
                        if let audioURLString = clip["audio_url"] as? String,
                           let audioURL = URL(string: audioURLString) {
                            print("🎵 Job streaming! Downloading audio from: \(audioURLString)")
                            let (audioData, _) = try await URLSession.shared.data(from: audioURL)
                            print("🎵 Downloaded \(audioData.count) bytes of audio data")
                            return audioData
                        } else {
                            throw SunoError.audioGenerationFailed
                        }
                    case "error":
                        let errorMessage = clip["error_message"] as? String ?? "Unknown error"
                        print("🎵 Job failed with error: \(errorMessage)")
                        throw SunoError.audioGenerationFailed
                    case "submitted", "queued":
                        // Still processing, wait and try again
                        if attempt < maxAttempts {
                            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                            continue
                        } else {
                            throw SunoError.apiError("Job timed out after \(maxAttempts) attempts")
                        }
                    default:
                        throw SunoError.apiError("Unknown job status: \(status)")
                    }
                } else {
                    throw SunoError.invalidResponse
                }
            } else {
                throw SunoError.invalidResponse
            }
        }
        
        throw SunoError.apiError("Job polling timed out")
    }
    
    private func checkRateLimit() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            Self.rateLimitQueue.async {
                let now = Date()
                let oneMinuteAgo = now.addingTimeInterval(-60)
                
                // Remove requests older than 1 minute
                Self.requestTimes = Self.requestTimes.filter { $0 > oneMinuteAgo }
                
                // Check if we're at the rate limit
                if Self.requestTimes.count >= 60 { // Use static value instead of self.maxRequestsPerMinute
                    let oldestRequest = Self.requestTimes.min() ?? now
                    let waitTime = 60 - now.timeIntervalSince(oldestRequest)
                    
                    if waitTime > 0 {
                        print("🎵 Rate limit reached. Waiting \(waitTime) seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
                            Self.requestTimes.append(now)
                            continuation.resume()
                        }
                        return
                    }
                }
                
                // Add current request
                Self.requestTimes.append(now)
                continuation.resume()
            }
        }
    }
    
    // MARK: - Audio Conversion
    
    private func convertToM4A(inputURL: URL, outputURL: URL) async throws {
        let asset = AVURLAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw SunoError.audioGenerationFailed
        }
        
        // Use the modern async export method with built-in error handling
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
            print("🎵 Successfully converted to M4A: \(outputURL.lastPathComponent)")
        } catch {
            print("🎵 M4A conversion failed: \(error.localizedDescription)")
            throw SunoError.audioGenerationFailed
        }
    }
    
    private func updateTrackStoreIndex(fileURL: URL, cacheKey: String) async throws {
        let fileManager = FileManager.default
        let trackStoreDir = fileURL.deletingLastPathComponent()
        let indexURL = trackStoreDir.appendingPathComponent("index.json")
        
        // Create TrackItem for the new file
        let trackItem: [String: Any] = [
            "id": cacheKey,
            "title": "Suno Generated Audio - \(Date().timeIntervalSince1970)",
            "artist": "Suno AI",
            "duration": try await getAudioDuration(url: fileURL),
            "filePath": fileURL.lastPathComponent,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "type": "generated"
        ]
        
        // Load existing index or create new one
        var indexArray: [[String: Any]] = []
        if fileManager.fileExists(atPath: indexURL.path),
           let data = try? Data(contentsOf: indexURL),
           let existingIndex = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            indexArray = existingIndex
        }
        
        // Add new track item
        indexArray.append(trackItem)
        
        // Save updated index
        let indexData = try JSONSerialization.data(withJSONObject: indexArray, options: .prettyPrinted)
        try indexData.write(to: indexURL)
        
        print("🎵 Updated TrackStore index with new track: \(fileURL.lastPathComponent)")
    }
}

// MARK: - Suno Errors

enum SunoError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    case invalidResponse
    case audioGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Suno API URL"
        case .apiError(let message):
            return "Suno API Error: \(message)"
        case .invalidResponse:
            return "Invalid response from Suno API"
        case .audioGenerationFailed:
            return "Failed to generate audio"
        }
    }
}
