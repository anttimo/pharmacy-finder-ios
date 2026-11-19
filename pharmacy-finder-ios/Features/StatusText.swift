import Foundation

extension NearestPharmaciesModel.State {
    /// The status line under "Use my location", which VoiceOver also announces when it changes.
    /// The iOS counterpart of the web app's `statusMessage` (`src/lib/messages.ts`). Nil when
    /// there's nothing to say yet.
    var statusText: LocalizedStringResource? {
        switch self {
        case .idle:
            nil
        case .locating:
            LocalizedStringResource(
                "status.locating", comment: "Status while waiting for the device's location.")
        case .loading:
            LocalizedStringResource(
                "status.loading",
                comment:
                    "Status after the location is known or a place is chosen, while the nearest pharmacies are found."
            )
        case .results(let pharmacies, _):
            LocalizedStringResource(
                "status.found \(pharmacies.count)",
                comment: "Status above the results. The placeholder is how many are shown.")
        case .denied:
            LocalizedStringResource(
                "status.denied",
                comment:
                    "Status when the app may not use the location, or Location Services are off.")
        case .locationError:
            LocalizedStringResource(
                "status.locationError",
                comment: "Status when the device's location couldn't be found.")
        }
    }

    /// Locating and loading show a spinner beside the status line.
    var isBusy: Bool {
        switch self {
        case .locating, .loading: true
        case .idle, .results, .denied, .locationError: false
        }
    }
}

extension NearestPharmaciesModel.SuggestionStatus {
    /// The message under the search field, which VoiceOver also announces. The web app's
    /// `fieldMessage` for the same states (`PlaceSearch.tsx`), with "in Finland" added.
    var message: LocalizedStringResource? {
        switch self {
        case .none:
            nil
        case .noMatches:
            LocalizedStringResource(
                "search.noMatches",
                comment: "Under the search field when no place in Finland matches the text.")
        case .failed:
            LocalizedStringResource(
                "search.error",
                comment: "Under the search field when Apple's place search couldn't be reached.")
        }
    }
}
