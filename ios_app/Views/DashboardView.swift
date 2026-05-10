import SwiftUI
import MapKit

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {

                    // 1. Connection Status
                    BLEStatusView(state: viewModel.bleManager.connectionState) {
                        if viewModel.bleManager.connectionState == .disconnected {
                            viewModel.bleManager.startScanning()
                        } else {
                            viewModel.bleManager.disconnect()
                        }
                    }
                    .padding(.top, 10)

                    // 2. Main Stats (Speed, HR, Distance)
                    HStack(spacing: 30) {
                        StatBox(title: "SPEED", value: formatSpeed(viewModel.locationManager.speed), unit: "km/h")
                        StatBox(title: "HEART", value: formatHR(viewModel.healthManager.currentHeartRate), unit: "bpm")
                        StatBox(title: "DIST", value: formatDistance(viewModel.locationManager.distance), unit: "km")
                    }
                    .padding(.horizontal)

                    // 3. Start/Stop Ride Button
                    Button(action: {
                        if viewModel.isRideActive {
                            viewModel.stopRide()
                        } else {
                            viewModel.startRide()
                        }
                    }) {
                        Text(viewModel.isRideActive ? "STOP RIDE" : "START RIDE")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.isRideActive ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(viewModel.isRideActive ? Color.red : Color.green)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)

                    // 4. Live iOS Map
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: viewModel.locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )), showsUserLocation: true)
                    .frame(height: 200)
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .allowsHitTesting(false) // Just for viewing

                    // 5. Hardware Preview (400x240 Dithered Image)
                    VStack {
                        Text("HARDWARE PREVIEW")
                            .font(.caption)
                            .foregroundColor(.gray)

                        if let previewImage = viewModel.hardwarePreviewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300, height: 180) // Scaled down for UI, but maintains 400x240 aspect ratio
                                .border(Color.gray, width: 1)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 300, height: 180)
                                .overlay(Text("Waiting for map...").foregroundColor(.gray))
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle("BikeComp")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Formatting Helpers

    private func formatSpeed(_ speed: CLLocationSpeed) -> String {
        guard speed > 0 else { return "0.0" }
        let kmh = speed * 3.6
        return String(format: "%.1f", kmh)
    }

    private func formatHR(_ hr: Double?) -> String {
        guard viewModel.isRideActive else { return "--" }
        guard let hr = hr, hr > 0 else { return "--" } // Handled by graceful fallback
        return String(format: "%.0f", hr)
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let km = meters / 1000.0
        return String(format: "%.2f", km)
    }
}

// MARK: - Subviews

struct StatBox: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(unit)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BLEStatusView: View {
    let state: BLEConnectionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(statusText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(20)
        }
    }

    private var statusColor: Color {
        switch state {
        case .disconnected: return .red
        case .scanning: return .yellow
        case .connecting: return .orange
        case .connected: return .blue // Using blue to represent Bluetooth Active
        }
    }

    private var statusText: String {
        switch state {
        case .disconnected: return "Tap to Connect"
        case .scanning: return "Scanning..."
        case .connecting: return "Connecting..."
        case .connected: return "BikeComp Connected"
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
