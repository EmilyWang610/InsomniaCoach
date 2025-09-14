//
//  AppEnvironment.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/13/25.
//

import Foundation

final class AppEnvironment: ObservableObject {
    let healthKit: HealthKitServicing
    let backendAPI = BackendAPIManager.shared
    let nightProcessor = NightDataProcessor()

    init(healthKit: HealthKitServicing = HealthKitService()) {
        self.healthKit = healthKit
    }
}
