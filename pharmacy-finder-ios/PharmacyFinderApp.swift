import SwiftUI

@main
struct PharmacyFinderApp: App {
    /// One model for the app's lifetime: it remembers whether precise location was already asked
    /// for this launch (ADR 0103).
    @State private var model = NearestPharmaciesModel(
        listLoader: BundledPharmacyListLoader(), locationProvider: LiveLocationProvider())

    var body: some Scene {
        WindowGroup {
            NearestPharmaciesView(model: model)
        }
    }
}
