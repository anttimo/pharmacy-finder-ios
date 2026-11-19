import SwiftUI

@main
struct PharmacyFinderApp: App {
    /// One model for the app's lifetime: it remembers whether precise location was already asked
    /// for this launch (ADR 0103).
    @State private var model = NearestPharmaciesModel(
        listLoader: BundledPharmacyListLoader(), locationProvider: Self.locationProvider())

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
}
