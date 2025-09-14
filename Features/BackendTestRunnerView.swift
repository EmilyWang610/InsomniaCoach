//
//  BackendTestRunnerView.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import SwiftUI

struct BackendTestRunnerView: View {
    @StateObject private var testRunner = BackendTestRunner()
    @State private var selectedTest: TestType = .healthCheck
    
    enum TestType: String, CaseIterable {
        case healthCheck = "Health Check"
        case userCreation = "User Creation"
        case nightIngestion = "Night Ingestion"
        case completePipeline = "Complete Pipeline"
        case agentAnalysis = "Agent Analysis"
        case getLatestPlan = "Get Latest Plan"
        case getAllPlans = "Get All Plans"
        case agentStatus = "Agent Status"
        case nightProcessor = "Night Processor"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Test Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Test")
                        .font(.headline)
                    
                    Picker("Test Type", selection: $selectedTest) {
                        ForEach(TestType.allCases, id: \.self) { test in
                            Text(test.rawValue).tag(test)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Run Test Button
                Button("Run Selected Test") {
                    runSelectedTest()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(testRunner.isRunning)
                
                // Run All Tests Button
                Button("Run All Tests") {
                    runAllTests()
                }
                .buttonStyle(.bordered)
                .disabled(testRunner.isRunning)
                
                // Test Status
                if testRunner.isRunning {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        
                        Text("Running tests...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                // Test Results
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(testRunner.testResults, id: \.id) { result in
                            TestResultView(result: result)
                        }
                    }
                }
                .frame(maxHeight: 400)
                
                // Clear Results Button
                if !testRunner.testResults.isEmpty {
                    Button("Clear Results") {
                        testRunner.clearResults()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Backend Test Runner")
        }
    }
    
    private func runSelectedTest() {
        Task {
            await testRunner.runTest(selectedTest)
        }
    }
    
    private func runAllTests() {
        Task {
            await testRunner.runAllTests()
        }
    }
}

struct TestResultView: View {
    let result: TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                
                Text(result.testName)
                    .font(.headline)
                    .foregroundColor(result.success ? .green : .red)
                
                Spacer()
                
                Text(result.duration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !result.message.isEmpty {
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
            
            if !result.details.isEmpty {
                ScrollView {
                    Text(result.details)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
                .padding(.leading, 20)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Test Runner
class BackendTestRunner: ObservableObject {
    @Published var isRunning = false
    @Published var testResults: [TestResult] = []
    
    private let backendAPI = BackendAPIManager.shared
    private let nightProcessor = NightDataProcessor()
    
    func runTest(_ testType: BackendTestRunnerView.TestType) async {
        isRunning = true
        let startTime = Date()
        
        do {
            let result = try await executeTest(testType)
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                testResults.append(TestResult(
                    id: UUID(),
                    testName: testType.rawValue,
                    success: result.success,
                    message: result.message,
                    details: result.details,
                    duration: String(format: "%.2fs", duration)
                ))
                isRunning = false
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                testResults.append(TestResult(
                    id: UUID(),
                    testName: testType.rawValue,
                    success: false,
                    message: "Test failed: \(error.localizedDescription)",
                    details: "",
                    duration: String(format: "%.2fs", duration)
                ))
                isRunning = false
            }
        }
    }
    
    func runAllTests() async {
        isRunning = true
        testResults.removeAll()
        
        for testType in BackendTestRunnerView.TestType.allCases {
            await runTest(testType)
            // Small delay between tests
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        isRunning = false
    }
    
    func clearResults() {
        testResults.removeAll()
    }
    
    private func executeTest(_ testType: BackendTestRunnerView.TestType) async throws -> TestResult {
        switch testType {
        case .healthCheck:
            return try await testHealthCheck()
        case .userCreation:
            return try await testUserCreation()
        case .nightIngestion:
            return try await testNightIngestion()
        case .completePipeline:
            return try await testCompletePipeline()
        case .agentAnalysis:
            return try await testAgentAnalysis()
        case .getLatestPlan:
            return try await testGetLatestPlan()
        case .getAllPlans:
            return try await testGetAllPlans()
        case .agentStatus:
            return try await testAgentStatus()
        case .nightProcessor:
            return try await testNightProcessor()
        }
    }
    
    // MARK: - Individual Test Methods
    private func testHealthCheck() async throws -> TestResult {
        backendAPI.checkHealth()
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        return TestResult(
            id: UUID(),
            testName: "Health Check",
            success: backendAPI.isConnected,
            message: backendAPI.isConnected ? "Backend is connected" : "Backend is not connected",
            details: "Status: \(backendAPI.isConnected ? "Connected" : "Disconnected")",
            duration: "2.0s"
        )
    }
    
    private func testUserCreation() async throws -> TestResult {
        let preferences = UserPreferences(
            sleepGoal: 8,
            wakeTime: "07:00",
            bedtime: "23:00",
            notifications: true
        )
        
        let userId = try await backendAPI.createUser(preferences: preferences)
        
        return TestResult(
            id: UUID(),
            testName: "User Creation",
            success: !userId.isEmpty,
            message: "User created successfully",
            details: "User ID: \(userId)",
            duration: "0.0s"
        )
    }
    
    private func testNightIngestion() async throws -> TestResult {
        let userId = try await backendAPI.createUser()
        let mockNightData = createMockNightData(userId: userId)
        
        let response = try await backendAPI.ingestNightData(mockNightData)
        
        return TestResult(
            id: UUID(),
            testName: "Night Ingestion",
            success: response.success,
            message: response.message,
            details: "Night ID: \(response.nightId)\nReady for Analysis: \(response.readyForAnalysis)",
            duration: "0.0s"
        )
    }
    
    private func testCompletePipeline() async throws -> TestResult {
        let mockSession = createMockSleepSession()
        let quality = 85
        let notes = "Test sleep session from iOS app"
        
        let plan = try await backendAPI.processNightData(
            sleepSession: mockSession,
            quality: quality,
            notes: notes
        )
        
        var details = "Plan ID: \(plan.id)\n"
        details += "Night Date: \(plan.nightDate)\n"
        details += "Blocks: \(plan.blocks.count)\n"
        details += "Summary: \(plan.summary)\n"
        
        for (index, block) in plan.blocks.enumerated() {
            details += "Block \(index + 1): \(block.title) (\(block.duration)s)\n"
        }
        
        return TestResult(
            id: UUID(),
            testName: "Complete Pipeline",
            success: true,
            message: "Complete pipeline test successful",
            details: details,
            duration: "0.0s"
        )
    }
    
    private func testAgentAnalysis() async throws -> TestResult {
        let userId = try await backendAPI.createUser()
        let nightDate = "2024-01-15"
        
        let response = try await backendAPI.triggerAgentAnalysis(
            userId: userId,
            nightDate: nightDate
        )
        
        return TestResult(
            id: UUID(),
            testName: "Agent Analysis",
            success: response.success,
            message: "Agent analysis completed",
            details: "Report ID: \(response.reportId)\nPlan ID: \(response.planId)\nLoop IDs: \(response.loopIds.joined(separator: ", "))",
            duration: "0.0s"
        )
    }
    
    private func testGetLatestPlan() async throws -> TestResult {
        let userId = try await backendAPI.createUser()
        let plan = try await backendAPI.getLatestPlan(userId: userId)
        
        return TestResult(
            id: UUID(),
            testName: "Get Latest Plan",
            success: !plan.id.isEmpty,
            message: "Latest plan retrieved",
            details: "Plan ID: \(plan.id)\nUser ID: \(plan.userId)\nNight Date: \(plan.nightDate)\nBlocks: \(plan.blocks.count)",
            duration: "0.0s"
        )
    }
    
    private func testGetAllPlans() async throws -> TestResult {
        let userId = try await backendAPI.createUser()
        let plans = try await backendAPI.getAllPlans(userId: userId)
        
        var details = "Total plans: \(plans.count)\n"
        for (index, plan) in plans.enumerated() {
            details += "Plan \(index + 1): \(plan.id) - \(plan.nightDate)\n"
        }
        
        return TestResult(
            id: UUID(),
            testName: "Get All Plans",
            success: !plans.isEmpty,
            message: "All plans retrieved",
            details: details,
            duration: "0.0s"
        )
    }
    
    private func testAgentStatus() async throws -> TestResult {
        let userId = try await backendAPI.createUser()
        let status = try await backendAPI.getAgentStatus(userId: userId)
        
        return TestResult(
            id: UUID(),
            testName: "Agent Status",
            success: true,
            message: "Agent status retrieved",
            details: "Ready: \(status.ready)\nOpenAI Configured: \(status.openaiConfigured)\nSuno Stub: \(status.features.sunoStub)\nAnalysis Enabled: \(status.features.analysisEnabled)",
            duration: "0.0s"
        )
    }
    
    private func testNightProcessor() async throws -> TestResult {
        let mockSession = createMockSleepSession()
        let quality = 90
        let notes = "High quality sleep session"
        
        await nightProcessor.processNightData(
            sleepSession: mockSession,
            quality: quality,
            notes: notes
        )
        
        return TestResult(
            id: UUID(),
            testName: "Night Processor",
            success: nightProcessor.hasActivePlan,
            message: nightProcessor.hasActivePlan ? "Night processor successful" : "Night processor failed",
            details: "Plan Summary: \(nightProcessor.planSummary)\nTotal Duration: \(nightProcessor.formattedDuration)\nBlocks: \(nightProcessor.planBlocks.count)",
            duration: "0.0s"
        )
    }
    
    // MARK: - Helper Methods
    private func createMockNightData(userId: String) -> NightDTO {
        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let nightDate = dateFormatter.string(from: Date())
        let startTime = formatter.string(from: Date().addingTimeInterval(-28800))
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
            vitals: nil,
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
            startTime: Date().addingTimeInterval(-28800),
            endTime: Date()
        )
    }
}

// MARK: - Test Result Model
struct TestResult: Identifiable {
    let id: UUID
    let testName: String
    let success: Bool
    let message: String
    let details: String
    let duration: String
}

#Preview {
    BackendTestRunnerView()
}
