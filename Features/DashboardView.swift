//
//  DashboardView.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/14/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var env: AppEnvironment
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Insomnia Coach")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your Personal Sleep Assistant")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Main Content
                VStack(spacing: 16) {
                    // Quick Actions
                    VStack(spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            NavigationLink(destination: AudioStudioView()) {
                                VStack(spacing: 8) {
                                    Image(systemName: "music.note")
                                        .font(.title2)
                                    Text("Audio Studio")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                            
                            NavigationLink(destination: AdaptivePlanView()) {
                                VStack(spacing: 8) {
                                    Image(systemName: "moon.stars")
                                        .font(.title2)
                                    Text("Sleep Plans")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(12)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            NavigationLink(destination: BackendTestRunnerView()) {
                                VStack(spacing: 8) {
                                    Image(systemName: "network")
                                        .font(.title2)
                                    Text("API Tests")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(12)
                            }
                            
                            NavigationLink(destination: BackendTestView()) {
                                VStack(spacing: 8) {
                                    Image(systemName: "gear")
                                        .font(.title2)
                                    Text("Settings")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.orange.opacity(0.1))
                                .foregroundColor(.orange)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    
                    // Recent Activity
                    VStack(spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "music.note")
                                    .foregroundColor(.blue)
                                Text("Audio Studio")
                                    .font(.subheadline)
                                Spacer()
                                Text("Ready")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(8)
                            
                            HStack {
                                Image(systemName: "moon.stars")
                                    .foregroundColor(.purple)
                                Text("Sleep Plans")
                                    .font(.subheadline)
                                Spacer()
                                Text("Available")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(16)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppEnvironment())
}