import Foundation

/// A point on the Earth in degrees (WGS 84), as the pharmacy list and CoreLocation give it.
nonisolated struct Coordinate: Hashable, Sendable {
    var latitude: Double
    var longitude: Double
}

nonisolated extension Coordinate {
    /// Mean Earth radius. The web app uses the same value, so both apps show the same distances.
    private static let earthRadiusMeters = 6_371_008.8

    /// Great-circle (straight-line) distance in metres, with the haversine formula.
    func distance(to other: Coordinate) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let sinLat = sin(dLat / 2)
        let sinLon = sin(dLon / 2)
        let h = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon
        return 2 * Self.earthRadiusMeters * asin(min(1, h.squareRoot()))
    }
}
