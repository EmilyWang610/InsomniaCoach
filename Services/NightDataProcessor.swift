//
//  NightDataProcessor.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import Foundation

final class NightDataProcessor: ObservableObject {
    
    init() {}
    
    // MARK: - Data Processing
    
    func processSleepData(_ sleepData: [String: Any]) -> NightData? {
        guard let userId = sleepData["userId"] as? String,
              let nightDateLocal = sleepData["nightDateLocal"] as? String,
              let date = sleepData["date"] as? String,
              let sleepStartTime = sleepData["sleepStartTime"] as? String,
              let sleepEndTime = sleepData["sleepEndTime"] as? String,
              let totalSleepDuration = sleepData["totalSleepDuration"] as? Int,
              let sleepEfficiency = sleepData["sleepEfficiency"] as? Double,
              let awakeningCount = sleepData["awakeningCount"] as? Int,
              let stagesData = sleepData["stages"] as? [[String: Any]],
              let vitalsData = sleepData["vitals"] as? [[String: Any]] else {
            return nil
        }
        
        let stages = stagesData.compactMap { stageData -> SleepStage? in
            guard let stage = stageData["stage"] as? String,
                  let startTime = stageData["startTime"] as? String,
                  let endTime = stageData["endTime"] as? String,
                  let duration = stageData["duration"] as? Int else {
                return nil
            }
            return SleepStage(stage: stage, startTime: startTime, endTime: endTime, duration: duration)
        }
        
        let vitals = vitalsData.compactMap { vitalData -> VitalData? in
            guard let type = vitalData["type"] as? String,
                  let value = vitalData["value"] as? Double,
                  let timestamp = vitalData["timestamp"] as? String else {
                return nil
            }
            return VitalData(type: type, value: value, timestamp: timestamp)
        }
        
        return NightData(
            userId: userId,
            nightDateLocal: nightDateLocal,
            date: date,
            sleepStartTime: sleepStartTime,
            sleepEndTime: sleepEndTime,
            totalSleepDuration: totalSleepDuration,
            sleepEfficiency: sleepEfficiency,
            awakeningCount: awakeningCount,
            stages: stages,
            vitals: vitals
        )
    }
    
    func createMockNightData(userId: String) -> NightData {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        
        let stages = [
            SleepStage(stage: "inBed", startTime: formatter.string(from: now), endTime: formatter.string(from: now.addingTimeInterval(1800)), duration: 1800),
            SleepStage(stage: "asleepDeep", startTime: formatter.string(from: now.addingTimeInterval(1800)), endTime: formatter.string(from: now.addingTimeInterval(7200)), duration: 5400),
            SleepStage(stage: "asleepCore", startTime: formatter.string(from: now.addingTimeInterval(7200)), endTime: formatter.string(from: now.addingTimeInterval(14400)), duration: 7200),
            SleepStage(stage: "asleepREM", startTime: formatter.string(from: now.addingTimeInterval(14400)), endTime: formatter.string(from: now.addingTimeInterval(16200)), duration: 1800),
            SleepStage(stage: "awake", startTime: formatter.string(from: now.addingTimeInterval(16200)), endTime: formatter.string(from: now.addingTimeInterval(18000)), duration: 1800)
        ]
        
        let vitals = [
            VitalData(type: "heartRate", value: 65.0, timestamp: formatter.string(from: now)),
            VitalData(type: "heartRateVariability", value: 42.0, timestamp: formatter.string(from: now.addingTimeInterval(3600))),
            VitalData(type: "breathingRate", value: 16.0, timestamp: formatter.string(from: now.addingTimeInterval(7200)))
        ]
        
        return NightData(
            userId: userId,
            nightDateLocal: formatter.string(from: now),
            date: formatter.string(from: now),
            sleepStartTime: formatter.string(from: now),
            sleepEndTime: formatter.string(from: now.addingTimeInterval(18000)),
            totalSleepDuration: 16200, // 4.5 hours
            sleepEfficiency: 0.85,
            awakeningCount: 2,
            stages: stages,
            vitals: vitals
        )
    }
    
    // MARK: - Analysis
    
    func analyzeSleepQuality(_ nightData: NightData) -> SleepAnalysis {
        let totalSleepHours = Double(nightData.totalSleepDuration) / 3600.0
        let deepSleepPercentage = calculateDeepSleepPercentage(nightData.stages)
        let remSleepPercentage = calculateREMSleepPercentage(nightData.stages)
        
        let qualityScore = calculateQualityScore(
            totalSleepHours: totalSleepHours,
            sleepEfficiency: nightData.sleepEfficiency,
            awakeningCount: nightData.awakeningCount,
            deepSleepPercentage: deepSleepPercentage,
            remSleepPercentage: remSleepPercentage
        )
        
        return SleepAnalysis(
            qualityScore: qualityScore,
            totalSleepHours: totalSleepHours,
            deepSleepPercentage: deepSleepPercentage,
            remSleepPercentage: remSleepPercentage,
            sleepEfficiency: nightData.sleepEfficiency,
            awakeningCount: nightData.awakeningCount,
            recommendations: generateRecommendations(qualityScore: qualityScore, awakeningCount: nightData.awakeningCount)
        )
    }
    
    private func calculateDeepSleepPercentage(_ stages: [SleepStage]) -> Double {
        let deepSleepDuration = stages.filter { $0.stage == "asleepDeep" }.reduce(0) { $0 + $1.duration }
        let totalSleepDuration = stages.reduce(0) { $0 + $1.duration }
        return totalSleepDuration > 0 ? Double(deepSleepDuration) / Double(totalSleepDuration) : 0.0
    }
    
    private func calculateREMSleepPercentage(_ stages: [SleepStage]) -> Double {
        let remSleepDuration = stages.filter { $0.stage == "asleepREM" }.reduce(0) { $0 + $1.duration }
        let totalSleepDuration = stages.reduce(0) { $0 + $1.duration }
        return totalSleepDuration > 0 ? Double(remSleepDuration) / Double(totalSleepDuration) : 0.0
    }
    
    private func calculateQualityScore(totalSleepHours: Double, sleepEfficiency: Double, awakeningCount: Int, deepSleepPercentage: Double, remSleepPercentage: Double) -> Double {
        let sleepHoursScore = min(totalSleepHours / 8.0, 1.0) * 25
        let efficiencyScore = sleepEfficiency * 25
        let awakeningScore = max(0, 25 - Double(awakeningCount) * 5)
        let deepSleepScore = min(deepSleepPercentage * 100, 25)
        let remSleepScore = min(remSleepPercentage * 100, 25)
        
        return sleepHoursScore + efficiencyScore + awakeningScore + deepSleepScore + remSleepScore
    }
    
    private func generateRecommendations(qualityScore: Double, awakeningCount: Int) -> [String] {
        var recommendations: [String] = []
        
        if qualityScore < 60 {
            recommendations.append("Consider improving your sleep environment")
        }
        
        if awakeningCount > 3 {
            recommendations.append("Try to reduce nighttime awakenings")
        }
        
        if qualityScore < 80 {
            recommendations.append("Maintain a consistent sleep schedule")
        }
        
        return recommendations
    }
}

// MARK: - Data Models

struct SleepAnalysis {
    let qualityScore: Double
    let totalSleepHours: Double
    let deepSleepPercentage: Double
    let remSleepPercentage: Double
    let sleepEfficiency: Double
    let awakeningCount: Int
    let recommendations: [String]
}