import Foundation
import Testing

@testable import pharmacy_finder_ios

struct FinlandTests {
    private static let names = Finland.otherCountryNames(in: [
        Locale(identifier: "en"), Locale(identifier: "fi"),
    ])

    @Test(arguments: ["FI", "AX", "fi"])
    func includesFinlandAndAland(code: String) {
        #expect(Finland.includes(regionCode: code))
    }

    @Test(arguments: ["SE", "RU", "NO"])
    func excludesOtherCountries(code: String) {
        #expect(!Finland.includes(regionCode: code))
    }

    @Test func letsAPlaceWithNoCodeThrough() {
        #expect(Finland.includes(regionCode: nil))
    }

    /// The English ones as Apple gave them in a live test; the Finnish ones as they would read.
    @Test(arguments: [
        "Sweden", "Haparanda, Sweden", "Russia", "Ruotsi", "Haaparanta, Ruotsi",
        "Bristol, England", "Edinburgh, Skotlanti",
    ])
    func hidesSuggestionsInAnotherCountry(subtitle: String) {
        #expect(Finland.namesAnotherCountry(subtitle, otherCountryNames: Self.names))
    }

    @Test(arguments: [
        "Helsinki, Finland", "Kemijärvi, Suomi", "Åland Islands, Finland",
        "Mariehamn, Åland Islands",
        "Ahvenanmaa", "00100 Helsinki", "",
    ])
    func keepsSuggestionsInFinland(subtitle: String) {
        #expect(!Finland.namesAnotherCountry(subtitle, otherCountryNames: Self.names))
    }
}
