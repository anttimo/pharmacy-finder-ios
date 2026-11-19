#if DEBUG
    import SwiftUI

    /// The screen with fake services, for Xcode previews. `answer` is what the location gives;
    /// nil keeps it locating. With `searches`, it taps "Use my location" when it appears.
    struct PreviewScreen: View {
        @State private var model: NearestPharmaciesModel
        private let searches: Bool

        init(answer: Result<LocationFix, LocationError>?, searches: Bool = true) {
            _model = State(
                initialValue: NearestPharmaciesModel(
                    listLoader: PreviewPharmacyListLoader(),
                    locationProvider: PreviewLocationProvider(answer: answer),
                    placeSearch: FixedPlaceSearch()))
            self.searches = searches
        }

        var body: some View {
            NearestPharmaciesView(model: model)
                .task { if searches { model.useMyLocation() } }
        }
    }

    extension LocationFix {
        /// Helsinki railway station.
        static let preview = LocationFix(
            coordinate: Coordinate(latitude: 60.171, longitude: 24.941), isApproximate: false)
    }

    private struct PreviewLocationProvider: LocationProvider {
        let answer: Result<LocationFix, LocationError>?

        func currentLocation() async throws(LocationError) -> LocationFix {
            guard let answer else {
                try? await Task.sleep(for: .seconds(86_400))
                throw .unavailable
            }
            return try answer.get()
        }

        func requestPreciseLocation() async -> Bool { false }
    }

    private struct PreviewPharmacyListLoader: PharmacyListLoader {
        func load() async -> PharmacyList {
            PharmacyList(
                generatedAt: Date(timeIntervalSince1970: 1_794_865_713),
                pharmacies: [
                    Pharmacy(
                        id: "1", name: "Helsingin Rautatieaseman apteekki",
                        address: "Rautatieasema", postcode: "00100", city: "Helsinki",
                        phone: "(09) 1234 567", isBranch: false,
                        coordinate: Coordinate(latitude: 60.1712, longitude: 24.9413)),
                    Pharmacy(
                        id: "2", name: "Kampin apteekki", address: "Urho Kekkosen katu 1",
                        postcode: "00100", city: "Helsinki", phone: "(09) 2345 678",
                        isBranch: false,
                        coordinate: Coordinate(latitude: 60.1690, longitude: 24.9330)),
                    Pharmacy(
                        id: "3", name: "Kallion apteekki, sivuapteekki", address: "Hämeentie 1",
                        postcode: "00530", city: "Helsinki", phone: nil, isBranch: true,
                        coordinate: Coordinate(latitude: 60.1830, longitude: 24.9520)),
                ])
        }
    }
#endif
