import Foundation
import CoreLocation
import Combine

// MARK: - Location Manager

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var nearbyStops: [StopWithDistance] = []
    @Published var isLoadingStops = false
    @Published var error: String?

    private let manager = CLLocationManager()
    private var allStops: [KMBStop] = []
    private var stopsFetched = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = manager.authorizationStatus
    }

    func requestPermission() {
        // macOS uses requestAlwaysAuthorization or requestLocation directly
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        manager.requestLocation()
    }

    func findNearbyStops(radiusMeters: Double = 500) async {
        guard let loc = currentLocation else { return }
        isLoadingStops = true
        error = nil
        do {
            if !stopsFetched {
                allStops = try await KMBAPIClient.allStops()
                stopsFetched = true
            }
            nearbyStops = allStops
                .compactMap { stop -> StopWithDistance? in
                    guard let lat = Double(stop.lat), let lon = Double(stop.long) else { return nil }
                    let stopLoc = CLLocation(latitude: lat, longitude: lon)
                    let dist = loc.distance(from: stopLoc)
                    guard dist <= radiusMeters else { return nil }
                    return StopWithDistance(stop: stop, distanceMeters: dist)
                }
                .sorted { $0.distanceMeters < $1.distanceMeters }
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingStops = false
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = loc
            await self.findNearbyStops()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.error = error.localizedDescription }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}

// MARK: - StopWithDistance
struct StopWithDistance: Identifiable {
    var id: String { stop.stopID }
    let stop: KMBStop
    let distanceMeters: Double

    var distanceText: String {
        distanceMeters < 100  ? "< 100m"
            : distanceMeters < 1000 ? "\(Int(distanceMeters.rounded()))m"
            : String(format: "%.1fkm", distanceMeters / 1000)
    }
}
