//
//  BackendAPIManager.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import Foundation

final class BackendAPIManager: ObservableObject {
    static let shared = BackendAPIManager()
    
    private let baseURL = "http://localhost:3000"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Health Check
    
    func checkHealth() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/health") else {
            throw BackendError.invalidURL
        }
        
        let (_, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }
        
        return httpResponse.statusCode == 200
    }
    
    // MARK: - User Management
    
    func createUser() async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/users") else {
            throw BackendError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.requestFailed
        }
        
        let userData = try JSONDecoder().decode(UserResponse.self, from: data)
        return userData.userId
    }
    
    // MARK: - Night Data
    
    func ingestNightData(_ nightData: NightData) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/nights/ingest") else {
            throw BackendError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(nightData)
        request.httpBody = jsonData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.requestFailed
        }
        
        let result = try JSONDecoder().decode(NightIngestResponse.self, from: data)
        return result.nightId
    }
    
    // MARK: - Agent Analysis
    
    func triggerAgentAnalysis(userId: String, nightDate: String) async throws -> AgentAnalysisResponse {
        guard let url = URL(string: "\(baseURL)/api/users/\(userId)/agent/analyze?night_date=\(nightDate)") else {
            throw BackendError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.requestFailed
        }
        
        return try JSONDecoder().decode(AgentAnalysisResponse.self, from: data)
    }
    
    // MARK: - Plans
    
    func getLatestPlan(userId: String) async throws -> AdaptivePlan {
        guard let url = URL(string: "\(baseURL)/api/users/\(userId)/agent/plans/latest") else {
            throw BackendError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BackendError.requestFailed
        }
        
        return try JSONDecoder().decode(AdaptivePlan.self, from: data)
    }
}

// MARK: - Data Models

struct UserResponse: Codable {
    let userId: String
}

struct NightIngestResponse: Codable {
    let nightId: String
}

struct AgentAnalysisResponse: Codable {
    let reportId: String
    let planId: String
    let loopIds: [String]
}

struct NightData: Codable {
    let userId: String
    let nightDateLocal: String
    let date: String
    let sleepStartTime: String
    let sleepEndTime: String
    let totalSleepDuration: Int
    let sleepEfficiency: Double
    let awakeningCount: Int
    let stages: [SleepStage]
    let vitals: [VitalData]
}

struct SleepStage: Codable {
    let stage: String
    let startTime: String
    let endTime: String
    let duration: Int
}

struct VitalData: Codable {
    let type: String
    let value: Double
    let timestamp: String
}

// MARK: - Errors

enum BackendError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case requestFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .requestFailed:
            return "Request failed"
        case .decodingFailed:
            return "Failed to decode response"
        }
    }
}