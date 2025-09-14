//
//  AdaptivePlanView.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import SwiftUI

struct AdaptivePlanView: View {
    @StateObject private var nightProcessor = NightDataProcessor()
    @State private var showingPlan = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if nightProcessor.isProcessing {
                    processingView
                } else if let plan = nightProcessor.currentPlan {
                    planDisplayView(plan)
                } else {
                    emptyStateView
                }
            }
            .padding()
            .navigationTitle("Sleep Plan")
            .onAppear {
                Task {
                    await nightProcessor.refreshLatestPlan()
                }
            }
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: nightProcessor.processingProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                .scaleEffect(x: 1, y: 2)
            
            Text(nightProcessor.processingStep)
                .font(.headline)
                .foregroundColor(.primary)
            
            if let error = nightProcessor.processingError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func planDisplayView(_ plan: AdaptivePlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Plan Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Personalized Sleep Plan")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Generated for \(plan.nightDate)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Total Duration: \(formatDuration(plan.blocks.reduce(0) { $0 + $1.duration }))")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            // Plan Summary
            if !plan.summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)
                    
                    Text(plan.summary)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Plan Blocks
            VStack(alignment: .leading, spacing: 12) {
                Text("Plan Steps")
                    .font(.headline)
                
                ForEach(Array(plan.blocks.enumerated()), id: \.offset) { index, block in
                    PlanBlockView(block: block, order: index + 1)
                }
            }
            
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.stars")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("No Sleep Plan Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Complete a sleep session to get your personalized adaptive plan")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Refresh Plan") {
                Task {
                    await nightProcessor.refreshLatestPlan()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
        .padding()
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct PlanBlockView: View {
    let block: PlanBlock
    let order: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Order number
            Text("\(order)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.purple))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title)
                    .font(.headline)
                
                Text(block.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(formatDuration(block.duration))
                        .font(.caption)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    if let mix = block.mix, mix.audioUrl != nil {
                        Image(systemName: "music.note")
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes) min"
    }
}

#Preview {
    AdaptivePlanView()
}
