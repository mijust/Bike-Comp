import Foundation
import HealthKit

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var currentHeartRate: Double?
    @Published var isAuthorized: Bool = false

    private var activeQuery: HKQuery?

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device.")
            return
        }

        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let readTypes: Set = [heartRateType]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                if success {
                    self?.startHeartRateQuery()
                } else if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Stop any existing query
        stopHeartRateQuery()

        // Query to get recent samples and observe for updates
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] (query, samples, deletedObjects, newAnchor, error) in
            self?.processSamples(samples)
        }

        query.updateHandler = { [weak self] (query, samples, deletedObjects, newAnchor, error) in
            self?.processSamples(samples)
        }

        healthStore.execute(query)
        self.activeQuery = query

        // Setup background delivery if needed (requires capabilities setup in Xcode)
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                print("Failed to enable background delivery: \(error.localizedDescription)")
            }
        }
    }

    func stopHeartRateQuery() {
        if let query = activeQuery {
            healthStore.stop(query)
            activeQuery = nil
        }
        currentHeartRate = nil
    }

    private func processSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }

        // Get the most recent sample
        if let mostRecentSample = quantitySamples.sorted(by: { $0.startDate > $1.startDate }).first {
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let value = mostRecentSample.quantity.doubleValue(for: heartRateUnit)

            DispatchQueue.main.async {
                self.currentHeartRate = value
            }
        }
    }

    // MARK: - Simulation for Simulator

    func simulateHeartRateForSimulator() {
        #if targetEnvironment(simulator)
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            let simulatedRate = Double.random(in: 120...150)
            self?.currentHeartRate = simulatedRate
        }
        #endif
    }
}
