//
//  MusicModels.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import Foundation

// MARK: - Error Types

enum MusicGenerationError: Error, LocalizedError {
    case invalidURL
    case audioGenerationFailed
    case networkError(String)
    case invalidResponse
    case fileSystemError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL provided"
        case .audioGenerationFailed:
            return "Failed to generate audio"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        }
    }
}