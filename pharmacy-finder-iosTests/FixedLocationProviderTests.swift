import Testing

@testable import pharmacy_finder_ios

@MainActor
struct FixedLocationProviderTests {
    @Test func coordinatesGiveAPreciseFix() async throws {
        let provider = try #require(FixedLocationProvider(argument: "60.171,24.941"))
        let fix = try await provider.currentLocation()
        #expect(fix.coordinate == Coordinate(latitude: 60.171, longitude: 24.941))
        #expect(!fix.isApproximate)
    }

    @Test func approximateSuffixGivesAnApproximateFix() async throws {
        let provider = try #require(FixedLocationProvider(argument: "60.171,24.941,approximate"))
        #expect(try await provider.currentLocation().isApproximate)
    }

    @Test(arguments: [("denied", LocationError.denied), ("unavailable", .unavailable)])
    func errorsAreThrown(argument: String, error: LocationError) async throws {
        let provider = try #require(FixedLocationProvider(argument: argument))
        await #expect(throws: error) { try await provider.currentLocation() }
    }

    @Test(arguments: ["", "60.171", "north,east", "60.171,24.941,precise", "60.171,24.941,1"])
    func malformedArgumentsAreIgnored(argument: String) {
        #expect(FixedLocationProvider(argument: argument) == nil)
    }
}
