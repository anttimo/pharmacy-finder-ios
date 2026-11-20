import Foundation

/// Which places count as Finland in place search. Apple's search can't be limited to a country:
/// the Finland box is only a hint, and `regionPriority = .required` (iOS 18+) still let Stockholm,
/// Saint Petersburg and Haparanda through when tried on iOS 26. So the app filters twice: the
/// suggestions by the country their second line names, and the chosen place by its country code.
nonisolated enum Finland {
    /// Åland is part of Finland but has its own code: iOS 26 gives Mariehamn "AX", older APIs "FI".
    static let regionCodes: Set<String> = ["FI", "AX"]

    /// Whether a place with this country code is in Finland. A place with no code is let through:
    /// it was suggested for the Finland box, and the nearest pharmacies are found either way.
    static func includes(regionCode: String?) -> Bool {
        guard let regionCode else { return true }
        return regionCodes.contains(regionCode.uppercased())
    }

    /// The names of every other country in these languages, such as "Sweden" and "Ruotsi".
    static func otherCountryNames(in locales: [Locale]) -> Set<String> {
        var names = Set<String>()
        // Two letters: the countries, not the continents and other areas ("150" is Europe).
        for region in Locale.Region.isoRegions
        where region.identifier.count == 2 && !regionCodes.contains(region.identifier) {
            for locale in locales {
                if let name = locale.localizedString(forRegionCode: region.identifier) {
                    names.insert(name)
                }
            }
        }
        return names
    }

    /// Whether a suggestion's second line ends with another country, as in "Haparanda, Sweden".
    /// Finnish places end with "Finland", a town, or "Åland Islands". A name that doesn't match
    /// lets the suggestion through, and choosing it is then caught by its country code.
    static func namesAnotherCountry(_ subtitle: String, otherCountryNames: Set<String>) -> Bool {
        guard let last = subtitle.split(separator: ",").last else { return false }
        return otherCountryNames.contains(last.trimmingCharacters(in: .whitespaces))
    }
}
