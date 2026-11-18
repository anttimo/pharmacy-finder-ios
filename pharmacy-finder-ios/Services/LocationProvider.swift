import CoreLocation

/// The device's location, one fix at a time. Asks for when-in-use permission only when a fix is
/// first requested, never earlier, and never for Always. The location stays on the device.
protocol LocationProvider {
    /// One location fix. Asks for permission first if the user hasn't answered yet.
    func currentLocation() async throws(LocationError) -> LocationFix

    /// Asks for a precise location for this app session, when the user has shared only an
    /// approximate one (ADR 0103). Returns whether the next fix will be precise.
    func requestPreciseLocation() async -> Bool
}

nonisolated struct LocationFix: Hashable, Sendable {
    var coordinate: Coordinate
    /// The user has turned off Precise Location for the app, so the fix is only accurate to a few
    /// kilometres.
    var isApproximate: Bool
}

nonisolated enum LocationError: Error, Hashable, Sendable {
    /// The user said no, location is restricted, or Location Services are off for the whole device.
    case denied
    /// No fix came: no signal, or it took longer than the timeout.
    case unavailable
}

/// `LocationProvider` on CoreLocation. One `requestLocation()` per fix, no continuous updates.
final class LiveLocationProvider: NSObject, LocationProvider {
    /// The `NSLocationTemporaryUsageDescriptionDictionary` key in `Info.plist`.
    static let precisePurposeKey = "NearestPharmacies"
    /// How long to wait for a fix, as on the web (`timeout: 10_000`).
    static let timeout = Duration.seconds(10)
    /// A fix this recent and accurate is reused, like the web's `maximumAge`. Short, because a
    /// car at 100 km/h moves about 280 m in 10 s, and pharmacies in a city can be closer than that.
    /// While the app has only approximate access, an approximate fix is reused too: a new one
    /// would be no better. After the user allows precise access, the accuracy check skips the
    /// approximate fix, so a precise one is fetched.
    private static let maximumAge: TimeInterval = 10
    private static let maximumReusedAccuracy: CLLocationAccuracy = 500

    private let manager = CLLocationManager()
    private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []
    private var fixWaiters: [CheckedContinuation<Result<CLLocation, LocationError>, Never>] = []
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        // Enough to rank pharmacies, and faster than GPS accuracy (the web's
        // `enableHighAccuracy: false`).
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async throws(LocationError) -> LocationFix {
        try await requireAuthorization()
        let location = try await fix()
        return LocationFix(
            coordinate: Coordinate(
                latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            isApproximate: manager.accuracyAuthorization == .reducedAccuracy)
    }

    func requestPreciseLocation() async -> Bool {
        guard manager.accuracyAuthorization == .reducedAccuracy else { return true }
        await withCheckedContinuation { continuation in
            // `@Sendable`: CoreLocation doesn't promise which thread calls this back, and the
            // closure only resumes the continuation, which is safe from any thread.
            manager.requestTemporaryFullAccuracyAuthorization(
                withPurposeKey: Self.precisePurposeKey
            ) { @Sendable _ in
                continuation.resume()
            }
        }
        return manager.accuracyAuthorization == .fullAccuracy
    }

    /// Asks for when-in-use permission if the user hasn't answered yet, and waits for the answer.
    private func requireAuthorization() async throws(LocationError) {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationWaiters.append(continuation)
                if authorizationWaiters.count == 1 {
                    manager.requestWhenInUseAuthorization()
                }
            }
        }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return
        case .denied, .restricted: throw .denied
        case .notDetermined: throw .unavailable
        @unknown default: throw .unavailable
        }
    }

    /// A recent fix if there is one, otherwise a new one. Calls that overlap share one request.
    private func fix() async throws(LocationError) -> CLLocation {
        if let recent = manager.location,
            -recent.timestamp.timeIntervalSinceNow <= Self.maximumAge,
            recent.horizontalAccuracy >= 0,
            recent.horizontalAccuracy <= Self.maximumReusedAccuracy
                || manager.accuracyAuthorization == .reducedAccuracy
        {
            return recent
        }
        let result = await withCheckedContinuation { continuation in
            fixWaiters.append(continuation)
            if fixWaiters.count == 1 {
                manager.requestLocation()
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(for: Self.timeout) } catch { return }
                    // Cancels the request, so a late answer can't finish the next one.
                    self?.manager.stopUpdatingLocation()
                    self?.finishFix(.failure(.unavailable))
                }
            }
        }
        return try result.get()
    }

    private func finishFix(_ result: Result<CLLocation, LocationError>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let waiters = fixWaiters
        fixWaiters = []
        for waiter in waiters { waiter.resume(returning: result) }
    }
}

// The manager is created on the main thread, so CoreLocation calls the delegate there. The
// conformance is main-actor isolated (Swift 6.2), so Swift checks that at run time.
extension LiveLocationProvider: @MainActor CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Also called once when the manager is created, before anything was asked.
        guard manager.authorizationStatus != .notDetermined else { return }
        let waiters = authorizationWaiters
        authorizationWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        finishFix(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let denied = (error as? CLError)?.code == .denied
        finishFix(.failure(denied ? .denied : .unavailable))
    }
}
