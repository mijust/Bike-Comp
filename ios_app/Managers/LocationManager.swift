import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var speed: CLLocationSpeed = 0 // meters per second
    @Published var distance: CLLocationDistance = 0 // cumulative meters

    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5 // Update every 5 meters
    }

    func requestPermissions() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        // Optionally reset cumulative stats if this represents stopping a ride
        // distance = 0
        // speed = 0
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        self.location = newLocation

        // Use the location's speed if valid (m/s)
        if newLocation.speed >= 0 {
            self.speed = newLocation.speed
        }

        // Calculate cumulative distance
        if let last = lastLocation {
            let delta = newLocation.distance(from: last)
            if delta > 0 {
                self.distance += delta
            }
        }

        lastLocation = newLocation
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if newHeading.headingAccuracy >= 0 {
            self.heading = newHeading
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            // startTracking() could be called here, but usually controlled by UI
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed: \(error.localizedDescription)")
    }
}
