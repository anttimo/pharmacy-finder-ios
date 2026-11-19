import SwiftUI

@main
struct PharmacyFinderApp: App {
    /// One model for the app's lifetime: it remembers whether precise location was already asked
    /// for this launch (ADR 0103).
    @State private var model = NearestPharmaciesModel(
        listLoader: BundledPharmacyListLoader(), locationProvider: Self.locationProvider(),
        placeSearch: Self.placeSearch())

    var body: some Scene {
        WindowGroup {
            NearestPharmaciesView(model: model)
        }
    }

    private static func locationProvider() -> any LocationProvider {
        #if DEBUG
            // UI tests use a fixed location instead of real permission prompts.
            if let fixed = FixedLocationProvider.fromLaunchArguments() { return fixed }
        #endif
        return LiveLocationProvider()
    }

    private static func placeSearch() -> any PlaceSearch {
        #if DEBUG
            // UI tests use a few fixed places instead of Apple's service.
            if FixedPlaceSearch.isRequested { return FixedPlaceSearch() }
        #endif
        return LivePlaceSearch()
    }
}
