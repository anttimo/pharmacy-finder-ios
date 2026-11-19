import Foundation
import Observation

/// Drives the screen: finds the pharmacies nearest to the device or to a place the user chose, on
/// the device. The iOS counterpart of the web app's `useNearestPharmacies` and
/// `usePlaceSuggestions` hooks.
///
/// Each `useMyLocation()`, `choose(_:)` or `retryPlaceSearch()` starts a new search and cancels the
/// one still running, so only the latest result is shown.
@Observable
final class NearestPharmaciesModel {
    enum State: Hashable {
        case idle
        case locating
        /// The location is known, or a place was chosen and is being looked up. The pharmacy list
        /// may still be loading.
        case loading
        case results([NearbyPharmacy], from: Origin)
        case denied
        case locationError
        /// The chosen or typed place wasn't found in Finland.
        case noMatches
        /// Apple's place search couldn't be reached.
        case searchError
    }

    /// What the field says about its suggestions. Separate from `state`: it never touches the
    /// results, which change only when a place is chosen (as on the web).
    enum SuggestionStatus: Hashable {
        case none
        /// Apple found nothing for the text, or only places outside Finland.
        case noMatches
        case failed
    }

    /// Where a search started from, for the results' heading and notes.
    enum Origin: Hashable {
        /// `isApproximate`: the user shared only an approximate location and didn't allow a
        /// precise one, so the order may differ from the real nearest (ADR 0103).
        case myLocation(isApproximate: Bool)
        /// A place chosen from the suggestions, by its name.
        case place(String)
    }

    /// How many pharmacies to show. There's no distance limit: the nearest are shown however far.
    static let resultCount = 3
    /// Shorter text gets no suggestions: one letter matches too much to be useful (as on the web).
    static let minimumQueryLength = 2

    private(set) var state = State.idle
    /// When the pharmacy list was generated, for the footer. Nil until the list has loaded, so it
    /// also tells whether the list is ready.
    private(set) var listGeneratedAt: Date?

    /// The search field's text. Changing it updates the suggestions.
    var searchText = "" {
        didSet { suggest() }
    }
    /// Places matching `searchText`. The previous ones stay while new ones load, so the list
    /// doesn't flicker as the user types.
    private(set) var suggestions: [PlaceSuggestion] = []
    /// Reset as soon as the text changes, so a message never describes older text.
    private(set) var suggestionStatus = SuggestionStatus.none

    private let listLoader: any PharmacyListLoader
    private let locationProvider: any LocationProvider
    private let placeSearch: any PlaceSearch
    /// The one load of the list, shared by the launch and every search. Once finished, awaiting
    /// it returns the list at once.
    @ObservationIgnored private var listTask: Task<PharmacyList, Never>?
    @ObservationIgnored private var search: Task<Void, Never>?
    @ObservationIgnored private var suggestionSearch: Task<Void, Never>?
    /// The query the current suggestions are for, so text that trims to the same query, such as
    /// an added space, doesn't ask again.
    @ObservationIgnored private var suggestedQuery = ""
    /// The name of the place last chosen. While the field shows it, there's nothing to suggest.
    @ObservationIgnored private var chosenPlaceName: String?
    /// What `retryPlaceSearch()` repeats: a chosen suggestion, or the text Return was pressed on.
    @ObservationIgnored private var placeToRetry: PlaceToRetry?

    private enum PlaceToRetry {
        case suggestion(PlaceSuggestion)
        case text(String)
    }
    /// Precise location is asked for at most once per launch (ADR 0103). The model lives as long
    /// as the app, so this flag does too.
    @ObservationIgnored private var hasAskedForPreciseLocation = false

    init(
        listLoader: any PharmacyListLoader, locationProvider: any LocationProvider,
        placeSearch: any PlaceSearch
    ) {
        self.listLoader = listLoader
        self.locationProvider = locationProvider
        self.placeSearch = placeSearch
    }

    /// Loads the pharmacy list. The screen calls this at launch so the footer has its date; a
    /// search that starts earlier waits for the same load instead of starting another.
    func loadList() async {
        _ = await pharmacyList()
    }

    /// Finds the pharmacies nearest to the device, and empties the search field so it doesn't
    /// name some other place. Returns the search so tests can wait for it.
    @discardableResult
    func useMyLocation() -> Task<Void, Never> {
        chosenPlaceName = nil
        searchText = ""
        return startSearch(.locating) { await $0.locateAndShowNearest() }
    }

    /// Finds the pharmacies nearest to a suggested place, and puts its name in the field.
    @discardableResult
    func choose(_ suggestion: PlaceSuggestion) -> Task<Void, Never> {
        // Before the text, so changing the text doesn't ask for suggestions for the name.
        chosenPlaceName = suggestion.title
        searchText = suggestion.title
        placeToRetry = .suggestion(suggestion)
        return startSearch(.loading) { await $0.showNearest(to: suggestion) }
    }

    /// Return in the field: chooses the top suggestion, waiting for the suggestions if they're
    /// still on their way, as on the web. With none, asks Apple again for the text, so Return
    /// after "no places found" or an error says so in the status (or finds a place this time).
    @discardableResult
    func chooseTopSuggestion() -> Task<Void, Never> {
        let text = query
        let pending = suggestionSearch
        return Task {
            await pending?.value
            // The text changed meanwhile, or the user started another search.
            guard query == text, text.count >= Self.minimumQueryLength else { return }
            if let top = suggestions.first {
                await choose(top).value
            } else {
                await showNearestToTopSuggestion(for: text).value
            }
        }
    }

    /// "Try again" after `.searchError`: repeats the last place search.
    @discardableResult
    func retryPlaceSearch() -> Task<Void, Never> {
        switch placeToRetry {
        case .suggestion(let suggestion): choose(suggestion)
        case .text(let text): showNearestToTopSuggestion(for: text)
        case nil: Task {}
        }
    }

    private func showNearestToTopSuggestion(for text: String) -> Task<Void, Never> {
        placeToRetry = .text(text)
        // The status line says it now, so the field doesn't repeat it.
        suggestionStatus = .none
        return startSearch(.loading) { await $0.findTopSuggestionAndShowNearest(for: text) }
    }

    /// Cancels the running search and starts `operation` as the new one.
    private func startSearch(
        _ initialState: State, _ operation: @escaping (NearestPharmaciesModel) async -> Void
    ) -> Task<Void, Never> {
        search?.cancel()
        state = initialState
        let task = Task { await operation(self) }
        search = task
        return task
    }

    // MARK: - Suggestions

    /// The text to suggest places for: none while the field shows the chosen place.
    private var query: String {
        searchText == chosenPlaceName ? "" : searchText.trimmingCharacters(in: .whitespaces)
    }

    private func suggest() {
        let text = query
        guard text != suggestedQuery else { return }
        suggestedQuery = text
        suggestionSearch?.cancel()
        suggestionStatus = .none
        // New text, so "not found" or the error no longer describes it. Results stay.
        if state == .noMatches || state == .searchError { state = .idle }
        guard text.count >= Self.minimumQueryLength else {
            suggestionSearch = nil
            suggestions = []
            return
        }
        suggestionSearch = Task {
            do throws(PlaceSearchError) {
                let found = try await placeSearch.suggestions(for: text)
                guard !Task.isCancelled else { return }
                suggestions = found
                suggestionStatus = found.isEmpty ? .noMatches : .none
            } catch {
                guard !Task.isCancelled else { return }
                // The old suggestions are for other text, and the message replaces them.
                suggestions = []
                suggestionStatus = .failed
            }
        }
    }

    // MARK: - Searching

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

        if listGeneratedAt == nil { state = .loading }
        let pharmacies = await pharmacyList().pharmacies
        guard !Task.isCancelled else { return }
        state = .results(
            pharmacies.nearest(to: fix.coordinate, count: Self.resultCount),
            from: .myLocation(isApproximate: fix.isApproximate))
    }

    private func showNearest(to suggestion: PlaceSuggestion) async {
        let place: Place
        do throws(PlaceSearchError) {
            place = try await placeSearch.place(for: suggestion)
        } catch {
            guard !Task.isCancelled else { return }
            state = error == .notFound ? .noMatches : .searchError
            return
        }
        guard !Task.isCancelled else { return }
        let pharmacies = await pharmacyList().pharmacies
        guard !Task.isCancelled else { return }
        state = .results(
            pharmacies.nearest(to: place.coordinate, count: Self.resultCount),
            from: .place(place.name))
    }

    private func findTopSuggestionAndShowNearest(for text: String) async {
        let found: [PlaceSuggestion]
        do throws(PlaceSearchError) {
            found = try await placeSearch.suggestions(for: text)
        } catch {
            guard !Task.isCancelled else { return }
            state = .searchError
            return
        }
        guard !Task.isCancelled else { return }
        guard let top = found.first else {
            state = .noMatches
            return
        }
        // As `choose(_:)` does, but within this search, which a newer one can still cancel.
        chosenPlaceName = top.title
        searchText = top.title
        placeToRetry = .suggestion(top)
        await showNearest(to: top)
    }

    /// For an approximate fix, asks once per launch for a precise location and takes a new fix.
    /// Declining, or a failed precise fix, keeps the approximate one.
    private func preciseIfAllowed(_ fix: LocationFix) async -> LocationFix {
        // A cancelled search mustn't use up the one ask: the newer search would then skip it.
        guard fix.isApproximate, !hasAskedForPreciseLocation, !Task.isCancelled else { return fix }
        hasAskedForPreciseLocation = true
        guard await locationProvider.requestPreciseLocation(), !Task.isCancelled else { return fix }
        return (try? await locationProvider.currentLocation()) ?? fix
    }

    private func pharmacyList() async -> PharmacyList {
        let task = listTask ?? Task { [listLoader] in await listLoader.load() }
        listTask = task
        let loaded = await task.value
        listGeneratedAt = loaded.generatedAt
        return loaded
    }
}
