//
//  BackendIntegrationTests.swift
//  InsomniaCoachTests
//
//  Created by Yongyan Wang on 9/14/25.
//

import XCTest
@testable import InsomniaCoach

class BackendIntegrationTests: XCTestCase {
    var backendAPI: BackendAPIManager!
    var nightProcessor: NightDataProcessor!
    
    override func setUpWithError() throws {
        backendAPI = BackendAPIManager.shared
        nightProcessor = NightDataProcessor()
    }
    
    override func tearDownWithError() throws {
        backendAPI = nil
        nightProcessor = nil
    }
    
    // MARK: - Health Check Tests
    func testBackendHealthCheck() async throws {
        // Given
        let expectation = XCTestExpectation(description: "Health check completes")
        
        // When
        backendAPI.checkHealth()
        
        // Wait a moment for the async call to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then
        XCTAssertTrue(backendAPI.isConnected, "Backend should be connected")
        expectation.fulfill()
    }
    
    // MARK: - User Creation Tests
    func testUserCreation() async throws {
        // Given
        let preferences = UserPreferences(
            sleepGoal: 8,
            wakeTime: "07:00",
            bedtime: "23:00",
            notifications: true
        )
        
        // When
        let userId = try await backendAPI.createUser(preferences: preferences)
        
        // Then
        XCTAssertFalse(userId.isEmpty, "User ID should not be empty")
        XCTAssertEqual(backendAPI.currentUserId, userId, "Current user ID should be set")
        print("✅ Created user with ID: \(userId)")
    }
    
    // MARK: - Night Data Ingestion Tests
    func testNightDataIngestion() async throws {
        // Given
        let userId = try await backendAPI.createUser()
        let mockNightData = createMockNightData(userId: userId)
        
        // When
        let response = try await backendAPI.ingestNightData(mockNightData)
        
        // Then
        XCTAssertTrue(response.success, "Night ingestion should succeed")
        XCTAssertFalse(response.nightId.isEmpty, "Night ID should not be empty")
        XCTAssertTrue(response.readyForAnalysis, "Should be ready for analysis")
        print("✅ Night data ingested successfully")
        print("   Night ID: \(response.nightId)")
        print("   Message: \(response.message)")
    }
    
    // MARK: - Complete Pipeline Test
    func testCompleteNightProcessingPipeline() async throws {
        // Given
        let mockSession = createMockSleepSession()
        let quality = 85
        let notes = "Test sleep session from iOS app"
        
        // When
        let expectation = XCTestExpectation(description: "Complete pipeline test")
        
        Task {
            do {
                let plan = try await backendAPI.processNightData(
                    sleepSession: mockSession,
                    quality: quality,
                    notes: notes
                )
                
                // Then
                XCTAssertFalse(plan.id.isEmpty, "Plan ID should not be empty")
                XCTAssertFalse(plan.blocks.isEmpty, "Plan should have blocks")
                XCTAssertFalse(plan.summary.isEmpty, "Plan should have a summary")
                
                print("✅ Complete pipeline test successful!")
                print("   Plan ID: \(plan.id)")
                print("   Night Date: \(plan.nightDate)")
                print("   Blocks: \(plan.blocks.count)")
                print("   Summary: \(plan.summary)")
                
                // Print each block
                for (index, block) in plan.blocks.enumerated() {
                    print("   Block \(index + 1): \(block.title)")
                    print("     Type: \(block.type)")
                    print("     Duration: \(block.duration) seconds")
                    print("     Description: \(block.description)")
                    if let mix = block.mix {
                        print("     Audio: \(mix.fileName ?? "None")")
                    }
                }
                
                expectation.fulfill()
            } catch {
                XCTFail("Pipeline test failed: \(error.localizedDescription)")
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
    
    // MARK: - Agent Analysis Test
    func testAgentAnalysis() async throws {
        // Given
        let userId = try await backendAPI.createUser()
        let nightDate = "2024-01-15"
        
        // When
        let response = try await backendAPI.triggerAgentAnalysis(
            userId: userId,
            nightDate: nightDate
        )
        
        // Then
        XCTAssertTrue(response.success, "Agent analysis should succeed")
        XCTAssertFalse(response.reportId.isEmpty, "Report ID should not be empty")
        XCTAssertFalse(response.planId.isEmpty, "Plan ID should not be empty")
        XCTAssertFalse(response.loopIds.isEmpty, "Loop IDs should not be empty")
        XCTAssertEqual(response.nightDate, nightDate, "Night date should match")
        
        print("✅ Agent analysis successful!")
        print("   Report ID: \(response.reportId)")
        print("   Plan ID: \(response.planId)")
        print("   Loop IDs: \(response.loopIds)")
        print("   Night Date: \(response.nightDate)")
    }
    
    // MARK: - Plan Retrieval Tests
    func testGetLatestPlan() async throws {
        // Given
        let userId = try await backendAPI.createUser()
        
        // When
        let plan = try await backendAPI.getLatestPlan(userId: userId)
        
        // Then
        XCTAssertFalse(plan.id.isEmpty, "Plan ID should not be empty")
        XCTAssertEqual(plan.userId, userId, "User ID should match")
        print("✅ Latest plan retrieved successfully")
        print("   Plan ID: \(plan.id)")
        print("   User ID: \(plan.userId)")
        print("   Night Date: \(plan.nightDate)")
        print("   Blocks: \(plan.blocks.count)")
    }
    
    func testGetAllPlans() async throws {
        // Given
        let userId = try await backendAPI.createUser()
        
        // When
        let plans = try await backendAPI.getAllPlans(userId: userId)
        
        // Then
        XCTAssertFalse(plans.isEmpty, "Should have at least one plan")
        print("✅ All plans retrieved successfully")
        print("   Total plans: \(plans.count)")
        
        for (index, plan) in plans.enumerated() {
            print("   Plan \(index + 1): \(plan.id) - \(plan.nightDate)")
        }
    }
    
    // MARK: - Agent Status Test
    func testAgentStatus() async throws {
        // Given
        let userId = try await backendAPI.createUser()
        
        // When
        let status = try await backendAPI.getAgentStatus(userId: userId)
        
        // Then
        XCTAssertNotNil(status, "Agent status should not be nil")
        print("✅ Agent status retrieved successfully")
        print("   Ready: \(status.ready)")
        print("   OpenAI Configured: \(status.openaiConfigured)")
        print("   Suno Stub: \(status.features.sunoStub)")
        print("   Analysis Enabled: \(status.features.analysisEnabled)")
        print("   Plan Generation: \(status.features.planGeneration)")
    }
    
    // MARK: - Night Data Processor Test
    func testNightDataProcessor() async throws {
        // Given
        let mockSession = createMockSleepSession()
        let quality = 90
        let notes = "High quality sleep session"
        
        // When
        let expectation = XCTestExpectation(description: "Night data processor test")
        
        Task {
            await nightProcessor.processNightData(
                sleepSession: mockSession,
                quality: quality,
                notes: notes
            )
            
            // Then
            XCTAssertTrue(nightProcessor.hasActivePlan, "Should have an active plan")
            XCTAssertFalse(nightProcessor.planSummary.isEmpty, "Plan summary should not be empty")
            XCTAssertFalse(nightProcessor.planBlocks.isEmpty, "Plan should have blocks")
            
            print("✅ Night data processor test successful!")
            print("   Plan Summary: \(nightProcessor.planSummary)")
            print("   Total Duration: \(nightProcessor.formattedDuration)")
            print("   Blocks: \(nightProcessor.planBlocks.count)")
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
    
    // MARK: - Helper Methods
    private func createMockNightData(userId: String) -> NightDTO {
        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let nightDate = dateFormatter.string(from: Date())
        let startTime = formatter.string(from: Date().addingTimeInterval(-28800)) // 8 hours ago
        let endTime = formatter.string(from: Date())
        
        let stages = [
            SleepStage(
                stage: "awake",
                startTime: startTime,
                endTime: formatter.string(from: Date().addingTimeInterval(-28800 + 300)),
                duration: 300
            ),
            SleepStage(
                stage: "light",
                startTime: formatter.string(from: Date().addingTimeInterval(-28800 + 300)),
                endTime: formatter.string(from: Date().addingTimeInterval(-28800 + 3300)),
                duration: 3000
            ),
            SleepStage(
                stage: "deep",
                startTime: formatter.string(from: Date().addingTimeInterval(-28800 + 3300)),
                endTime: formatter.string(from: Date().addingTimeInterval(-28800 + 4500)),
                duration: 1200
            ),
            SleepStage(
                stage: "rem",
                startTime: formatter.string(from: Date().addingTimeInterval(-28800 + 4500)),
                endTime: endTime,
                duration: 3300
            )
        ]
        
        return NightDTO(
            userId: userId,
            date: nightDate,
            stages: stages,
            vitals: Vitals(
                heartRate: [
                    VitalDataPoint(timestamp: startTime, value: 65.0, unit: "bpm"),
                    VitalDataPoint(timestamp: endTime, value: 70.0, unit: "bpm")
                ],
                heartRateVariability: nil,
                oxygenSaturation: nil,
                bodyTemperature: nil
            ),
            metadata: NightMetadata(
                deviceType: "iOS",
                appVersion: "1.0.0",
                timezone: "UTC",
                notes: "Test sleep session"
            )
        )
    }
    
    private func createMockSleepSession() -> SleepSession {
        return SleepSession(
            startTime: Date().addingTimeInterval(-28800), // 8 hours ago
            endTime: Date()
        )
    }
}

// MARK: - SleepSession Mock
struct SleepSession {
    let startTime: Date
    let endTime: Date
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}
