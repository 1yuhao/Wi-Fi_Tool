import CoreLocation
import Foundation

@MainActor
final class WiFiNameAccess: NSObject, CLLocationManagerDelegate {
    var onAuthorizationChange: (() -> Void)?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    var needsAuthorization: Bool {
        locationManager.authorizationStatus == .notDetermined
    }

    func requestAuthorizationIfNeeded() {
        guard CLLocationManager.locationServicesEnabled(),
              locationManager.authorizationStatus == .notDetermined else {
            return
        }

        locationManager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.onAuthorizationChange?()
        }
    }
}
