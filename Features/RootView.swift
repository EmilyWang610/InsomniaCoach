//
//  RootView.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/13/25.
//
import SwiftUI

struct RootView: View {
    @EnvironmentObject var env: AppEnvironment
    @State private var authStatus: String = "Not requested"

    var body: some View {
        NavigationStack {
            List {
                Section("HealthKit") {
                    Text("Authorization: \(authStatus)")
                    Button("Request Sleep Read Permission") {
                        Task {
                            do {
                                try await env.healthKit.requestReadAuthorization()
                                authStatus = "Granted / Completed"
                            } catch {
                                authStatus = "Failed: \(error.localizedDescription)"
                            }
                        }
                    }
                }

                NavigationLink("Sleep Dashboard") { Text("Dashboard") }
                NavigationLink("Audio Plan") { Text("Audio Plan") }
                NavigationLink("Settings") { Text("Settings") }
            }
            .navigationTitle("InsomniaCoach")
        }
    }
}
