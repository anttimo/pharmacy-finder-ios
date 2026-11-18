import Testing

@testable import pharmacy_finder_ios

struct CoordinateTests {
    @Test func isZeroForTheSamePoint() {
        let point = Coordinate(latitude: 60.17, longitude: 24.94)
        #expect(point.distance(to: point) == 0)
    }

    @Test func matchesTheKnownHelsinkiTampereDistance() {
        // Helsinki Central Station → Tampere station: about 160 km in a straight line.
        let helsinki = Coordinate(latitude: 60.1719, longitude: 24.9414)
        let tampere = Coordinate(latitude: 61.4985, longitude: 23.7737)
        #expect(abs(helsinki.distance(to: tampere) / 1000 - 160.3) < 0.5)
    }

    @Test func isTheSameInBothDirections() {
        let a = Coordinate(latitude: 60.1719, longitude: 24.9414)
        let b = Coordinate(latitude: 65.0121, longitude: 25.4651)
        #expect(a.distance(to: b) == b.distance(to: a))
    }
}
