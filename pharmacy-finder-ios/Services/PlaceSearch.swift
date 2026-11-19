import MapKit

/// Finds places in Finland from what the user types: suggestions while typing, then the
/// coordinates of the one they choose (ADR 0003). The iOS counterpart of the web app's
/// `/api/geocode`, without a proxy or key.
///
/// The search area is all of Finland, never the user's location: the location stays on the
/// device. What the user types does go to Apple, which the field's hint says.
@MainActor
protocol PlaceSearch {
    /// Suggestions for `text`. A newer call supersedes an older one still waiting, which then
    /// returns nothing: only the latest text's suggestions matter.
    func suggestions(for text: String) async throws(PlaceSearchError) -> [PlaceSuggestion]

    /// The place a suggestion stands for, with its coordinates.
    func place(for suggestion: PlaceSuggestion) async throws(PlaceSearchError) -> Place
}

/// A suggestion as the user sees it, such as "Kamppi" and "Helsinki, Suomi".
nonisolated struct PlaceSuggestion: Identifiable, Hashable, Sendable {
    var title: String
    var subtitle: String

    /// The two lines together. Apple's suggestions have no other id, and two that read the same
    /// would look the same to the user anyway.
    var id: String { "\(title)\n\(subtitle)" }
}

/// A place the user chose, to find the pharmacies nearest to.
nonisolated struct Place: Hashable, Sendable {
    /// The suggestion's title, for "Pharmacies near {name}".
    var name: String
    var coordinate: Coordinate
}

nonisolated enum PlaceSearchError: Error, Hashable, Sendable {
    /// No network, Apple's service failed, or the chosen place couldn't be found any more.
    case failed
}

/// `PlaceSearch` on MapKit: `MKLocalSearchCompleter` for the suggestions, and `MKLocalSearch` for
/// the chosen one's coordinates. (`CLGeocoder` is deprecated since iOS 26.)
final class LivePlaceSearch: NSObject, PlaceSearch {
    /// A box around Finland, from Hanko to Nuorgam and from Åland to Ilomantsi.
    static let finland = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 64.9, longitude: 25.3),
        span: MKCoordinateSpan(latitudeDelta: 10.6, longitudeDelta: 12.6))

    private let completer = MKLocalSearchCompleter()
    /// The latest completions by suggestion id, because `MKLocalSearch` needs the completion
    /// object itself, which isn't `Sendable` and so can't travel inside a `PlaceSuggestion`.
    private var completions: [PlaceSuggestion.ID: MKLocalSearchCompletion] = [:]
    private var waiter: CheckedContinuation<Result<[PlaceSuggestion], PlaceSearchError>, Never>?

    override init() {
        super.init()
        completer.delegate = self
        completer.region = Self.finland
        // Addresses and places, not "search for…" queries, which have no single location.
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func suggestions(for text: String) async throws(PlaceSearchError) -> [PlaceSuggestion] {
        finish(.success([]))
        // The completer only answers when the text changes, so asking again for the same text
        // (after "Kam" → "Ka" → "Kam") would wait forever.
        if completer.queryFragment == text, !completer.isSearching {
            return suggestions(from: completer.results)
        }
        let result = await withCheckedContinuation { continuation in
            waiter = continuation
            completer.queryFragment = text
        }
        return try result.get()
    }

    func place(for suggestion: PlaceSuggestion) async throws(PlaceSearchError) -> Place {
        guard let completion = completions[suggestion.id] else { throw .failed }
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
        guard let item = try? await search.start().mapItems.first else { throw .failed }
        return Place(name: suggestion.title, coordinate: Self.coordinate(of: item))
    }

    private static func coordinate(of item: MKMapItem) -> Coordinate {
        let coordinate =
            if #available(iOS 26, *) {
                item.location.coordinate
            } else {
                item.placemark.coordinate
            }
        return Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func suggestions(from results: [MKLocalSearchCompletion]) -> [PlaceSuggestion] {
        completions = [:]
        var suggestions: [PlaceSuggestion] = []
        for completion in results {
            let suggestion = PlaceSuggestion(title: completion.title, subtitle: completion.subtitle)
            guard completions[suggestion.id] == nil else { continue }
            completions[suggestion.id] = completion
            suggestions.append(suggestion)
        }
        return suggestions
    }

    private func finish(_ result: Result<[PlaceSuggestion], PlaceSearchError>) {
        waiter?.resume(returning: result)
        waiter = nil
    }
}

// The completer is created on the main thread and calls its delegate there. The conformance is
// main-actor isolated (Swift 6.2), so Swift checks that at run time.
extension LivePlaceSearch: @MainActor MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        finish(.success(suggestions(from: completer.results)))
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        finish(.failure(.failed))
    }
}
