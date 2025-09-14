//
//  HealthKitServicing.swift
//  InsomniaCoach
//
//  Created by Yongyan Wang on 9/13/25.
//

import Foundation
import HealthKit

protocol HealthKitServicing {
    var isAvailable: Bool { get }
    func requestReadAuthorization() async throws
    func fetchLastNightSleep() async throws -> [HKCategorySample]
}

final class HealthKitService: HealthKitServicing {
    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestReadAuthorization() async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sleep type not available"])
        }
        try await store.requestAuthorization(toShare: [], read: [sleepType])
    }
    func fetchLastNightSleep() async throws -> [HKCategorySample] {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let start = cal.date(byAdding: .hour, value: -6, to: startOfToday)!   // 昨晚 18:00
        let end   = cal.date(byAdding: .hour, value: 12, to: startOfToday)!   // 今天 12:00
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType,
                                  predicate: pred,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { _, samples, error in
                if let e = error {
                    cont.resume(throwing: e); return
                }
                cont.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
    }
}
