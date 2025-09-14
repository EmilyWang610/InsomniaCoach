//
//  InsomniaCoachApp.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/13/25.
//

import SwiftUI

@main
struct InsomniaCoachApp: App {
    @StateObject private var env = AppEnvironment() // 服务容器（下一步创建）

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(env)
        }
    }
}
