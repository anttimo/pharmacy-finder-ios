import CoreLocation

/// A point on the Earth in degrees (WGS 84), as the pharmacy list and CoreLocation give it.
nonisolated struct Coordinate: Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

nonisolated extension Coordinate {
    /// Straight-line distance in metres along the Earth's surface, from CoreLocation's
    /// `CLLocation.distance(from:)`.
    ///
    /// It comes out about 0.2–0.35 % longer than the web app's spherical (haversine) distance,
    /// and isn't exactly repeatable: the same two points can give results about 0.3 % apart
    /// between calls (seen on the iOS 26.3 simulator). After rounding to 10 m that rarely shows,
    /// so tests check distances with a tolerance, never exact values.
    func distance(to other: Coordinate) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
