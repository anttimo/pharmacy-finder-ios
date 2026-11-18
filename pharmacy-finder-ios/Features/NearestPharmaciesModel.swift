import Foundation
import Observation

/// Drives the screen: finds the pharmacies nearest to the device, on the device. The iOS
/// counterpart of the web app's `useNearestPharmacies` hook.
///
/// Each `useMyLocation()` starts a new search (also used to retry) and cancels the one still
/// running, so only the latest result is shown.
@Observable
final class NearestPharmaciesModel {
    enum State: Hashable {
        case idle
        case locating
        /// The location is known, and the pharmacy list is still loading.
        case loading
        /// `isApproximate`: the user shared only an approximate location and didn't allow a
        /// precise one, so the order may differ from the real nearest (ADR 0103).
        case results([NearbyPharmacy], isApproximate: Bool)
        case denied
        case locationError
    }

    /// How many pharmacies to show. There's no distance limit: the nearest are shown however far.
    static let resultCount = 3

    private(set) var state = State.idle
    /// When the pharmacy list was generated, for the footer. Nil until the list has loaded.
    private(set) var listGeneratedAt: Date?

    private let listLoader: any PharmacyListLoader
    private let locationProvider: any LocationProvider
    @ObservationIgnored private var list: PharmacyList?
    @ObservationIgnored private var listTask: Task<PharmacyList, Never>?
    @ObservationIgnored private var search: Task<Void, Never>?
    /// Precise location is asked for at most once per launch (ADR 0103). The model lives as long
    /// as the app, so this flag does too.
    @ObservationIgnored private var hasAskedForPreciseLocation = false

    init(listLoader: any PharmacyListLoader, locationProvider: any LocationProvider) {
        self.listLoader = listLoader
        self.locationProvider = locationProvider
    }

    /// Loads the pharmacy list. The screen calls this at launch so the footer has its date; a
    /// search that starts earlier waits for the same load instead of starting another.
    func loadList() async {
        _ = await pharmacyList()
    }

    /// Finds the pharmacies nearest to the device. Returns the search so tests can wait for it.
    @discardableResult
    func useMyLocation() -> Task<Void, Never> {
        search?.cancel()
        state = .locating
        let task = Task { await locateAndShowNearest() }
        search = task
        return task
    }

    private func locateAndShowNearest() async {
        let fix: LocationFix
        do throws(LocationError) {
            fix = await preciseIfAllowed(try await locationProvider.currentLocation())
        } catch {
            // A newer search owns the state now.
            guard !Task.isCancelled else { return }
            state = error == .denied ? .denied : .locationError
            return
        }
        guard !Task.isCancelled else { return }

        if list == nil { state = .loading }
        let pharmacies = await pharmacyList().pharmacies
        guard !Task.isCancelled else { return }
        state = .results(
            pharmacies.nearest(to: fix.coordinate, count: Self.resultCount),
            isApproximate: fix.isApproximate)
    }

    /// For an approximate fix, asks once per launch for a precise location and takes a new fix.
    /// Declining, or a failed precise fix, keeps the approximate one.
    private func preciseIfAllowed(_ fix: LocationFix) async -> LocationFix {
        guard fix.isApproximate, !hasAskedForPreciseLocation else { return fix }
        hasAskedForPreciseLocation = true
        guard await locationProvider.requestPreciseLocation(), !Task.isCancelled else { return fix }
        return (try? await locationProvider.currentLocation()) ?? fix
    }

    private func pharmacyList() async -> PharmacyList {
        if let list { return list }
        let task: Task<PharmacyList, Never>
        if let listTask {
            task = listTask
        } else {
            let loader = listLoader
            task = Task { await loader.load() }
            listTask = task
        }
        let loaded = await task.value
        list = loaded
        listGeneratedAt = loaded.generatedAt
        return loaded
    }
}
