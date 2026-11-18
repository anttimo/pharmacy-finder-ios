import Testing

@testable import pharmacy_finder_ios

struct NearestTests {
    private let origin = Coordinate(latitude: 60, longitude: 25)

    private func pharmacy(_ id: String, latitude: Double) -> Pharmacy {
        Pharmacy(
            id: id, name: id, address: "Katu 1", postcode: "00100", city: "Helsinki",
            phone: nil, isBranch: false,
            coordinate: Coordinate(latitude: latitude, longitude: 25))
    }

    @Test func returnsTheNearestFirstWithTheDistance() throws {
        let pharmacies = [
            pharmacy("far", latitude: 60.1),
            pharmacy("near", latitude: 60.01),
            pharmacy("middle", latitude: 60.05),
        ]
        let result = pharmacies.nearest(to: origin, count: 2)
        #expect(result.map(\.id) == ["near", "middle"])
        // 0.01° of latitude is about 1112 m.
        let first = try #require(result.first)
        #expect(abs(first.distanceMeters - 1112) < 5)
    }

    @Test func returnsEverythingWhenThereAreFewerThanAskedFor() {
        #expect([pharmacy("only", latitude: 60.1)].nearest(to: origin, count: 3).count == 1)
    }

    @Test func ordersEqualDistancesById() {
        let pharmacies = [pharmacy("b", latitude: 60.1), pharmacy("a", latitude: 60.1)]
        #expect(pharmacies.nearest(to: origin, count: 2).map(\.id) == ["a", "b"])
    }

    @Test func returnsNothingForAZeroOrNegativeCount() {
        let pharmacies = [pharmacy("a", latitude: 60.1)]
        #expect(pharmacies.nearest(to: origin, count: 0).isEmpty)
        #expect(pharmacies.nearest(to: origin, count: -1).isEmpty)
    }
}
