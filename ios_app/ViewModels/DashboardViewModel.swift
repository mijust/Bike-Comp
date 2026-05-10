import Foundation
import Combine
import CoreLocation
import UIKit

class DashboardViewModel: ObservableObject {

    // Dependencies
    let bleManager = BLEManager()
    let locationManager = LocationManager()
    let healthManager = HealthManager()
    let mapRenderer = MapRenderer()

    // Published state for UI
    @Published var isRideActive: Bool = false
    @Published var hardwarePreviewImage: UIImage?

    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    private var mapUpdateTimer: Timer?

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Forward Heart Rate to BLE
        healthManager.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hrDouble in
                guard let self = self, self.isRideActive else { return }

                let hrValue: UInt8
                if let hr = hrDouble {
                    hrValue = UInt8(min(max(hr, 0), 255))
                } else {
                    // 0 represents "No Sensor Connected" as per protocol
                    hrValue = 0
                }

                self.bleManager.sendHeartRate(hrValue)
            }
            .store(in: &cancellables)
    }

    func startRide() {
        isRideActive = true

        // Request Permissions if needed
        locationManager.requestPermissions()
        healthManager.requestAuthorization()

        // Start Tracking
        locationManager.startTracking()

        // Simulator only: healthManager.simulateHeartRateForSimulator()
        #if targetEnvironment(simulator)
        healthManager.simulateHeartRateForSimulator()
        #else
        healthManager.startHeartRateQuery()
        #endif

        // Start Map Render Loop
        startMapUpdateLoop()
    }

    func stopRide() {
        isRideActive = false

        locationManager.stopTracking()
        healthManager.stopHeartRateQuery()
        stopMapUpdateLoop()

        // Tell hardware we stopped tracking heart rate
        bleManager.sendHeartRate(0)
    }

    // MARK: - Map Rendering Loop

    private func startMapUpdateLoop() {
        // Stop any existing timer
        stopMapUpdateLoop()

        // Update map every 3 seconds to avoid overloading BLE and CPU
        mapUpdateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.renderAndSendMap()
        }

        // Trigger initial render immediately
        renderAndSendMap()
    }

    private func stopMapUpdateLoop() {
        mapUpdateTimer?.invalidate()
        mapUpdateTimer = nil
    }

    private func renderAndSendMap() {
        guard isRideActive, let location = locationManager.location else { return }
        let heading = locationManager.heading?.trueHeading ?? locationManager.heading?.magneticHeading

        mapRenderer.renderMap(at: location, heading: heading) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let (previewImage, ditheredData)):
                    self?.hardwarePreviewImage = previewImage
                    self?.bleManager.sendMapData(ditheredData)
                case .failure(let error):
                    print("Map Rendering Error: \(error)")
                }
            }
        }
    }
}
