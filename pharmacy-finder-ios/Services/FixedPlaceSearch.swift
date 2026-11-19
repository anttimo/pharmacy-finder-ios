#if DEBUG
    import Foundation

    /// A place search with a few built-in places, so UI tests and previews don't depend on
    /// Apple's service or the network. Debug builds only. UI tests choose it with the launch
    /// argument `-fixedPlaces YES`, or `-fixedPlaces failing` for a search that always fails.
    struct FixedPlaceSearch: PlaceSearch {
        static let argumentKey = "fixedPlaces"

        static let places = [
            (PlaceSuggestion(title: "Kamppi", subtitle: "Helsinki"), Coordinate(60.1685, 24.9314)),
            (
                PlaceSuggestion(title: "Kampinkuja 2", subtitle: "00100 Helsinki"),
                Coordinate(60.1679, 24.9300)
            ),
            (
                PlaceSuggestion(title: "Keskustori", subtitle: "Tampere"),
                Coordinate(61.4980, 23.7610)
            ),
        ]

        var fails = false

        /// The fixed place search the launch arguments ask for, if any.
        static func fromLaunchArguments() -> FixedPlaceSearch? {
            switch UserDefaults.standard.string(forKey: argumentKey) {
            case "YES": FixedPlaceSearch()
            case "failing": FixedPlaceSearch(fails: true)
            default: nil
            }
        }

        /// The places whose title starts with the text, ignoring case.
        func suggestions(for text: String) async throws(PlaceSearchError) -> [PlaceSuggestion] {
            if fails { throw .failed }
            return Self.places.map(\.0).filter {
                $0.title.range(of: text, options: [.caseInsensitive, .anchored]) != nil
            }
        }

        func place(for suggestion: PlaceSuggestion) async throws(PlaceSearchError) -> Place {
            if fails { throw .failed }
            guard let (_, coordinate) = Self.places.first(where: { $0.0 == suggestion }) else {
                throw .failed
            }
            return Place(name: suggestion.title, coordinate: coordinate)
        }
    }

    extension Coordinate {
        fileprivate init(_ latitude: Double, _ longitude: Double) {
            self.init(latitude: latitude, longitude: longitude)
        }
    }
#endif
