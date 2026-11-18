import Foundation
import Testing

@testable import pharmacy_finder_ios

struct FormattingTests {
    private let english = Locale(identifier: "en_GB")
    private let finnish = Locale(identifier: "fi_FI")

    @Test func usesMetresUnder1KmRoundedTo10M() {
        #expect(Formatting.distance(meters: 348, width: .abbreviated, locale: english) == "350 m")
        #expect(Formatting.distance(meters: 348, width: .wide, locale: english) == "350 metres")
        #expect(Formatting.distance(meters: 348, width: .wide, locale: finnish) == "350 metriä")
    }

    @Test func usesKilometresWithADecimalCommaInFinnish() {
        #expect(Formatting.distance(meters: 1234, width: .abbreviated, locale: finnish) == "1,2 km")
        #expect(
            Formatting.distance(meters: 1234, width: .wide, locale: finnish) == "1,2 kilometriä")
        #expect(
            Formatting.distance(meters: 1234, width: .wide, locale: english) == "1.2 kilometres")
    }

    @Test func keepsTheDecimalFrom10KmUp() {
        #expect(
            Formatting.distance(meters: 10_500, width: .abbreviated, locale: finnish) == "10,5 km")
        #expect(
            Formatting.distance(meters: 12_640, width: .abbreviated, locale: english) == "12.6 km")
    }

    @Test func roundsHalvesUp() {
        // 1.25 and 10.25 are exact in binary, so these are true ties.
        #expect(
            Formatting.distance(meters: 1_250, width: .abbreviated, locale: english) == "1.3 km")
        #expect(
            Formatting.distance(meters: 10_250, width: .abbreviated, locale: english) == "10.3 km")
    }

    @Test func dropsATrailingZeroDecimal() {
        #expect(Formatting.distance(meters: 2_010, width: .abbreviated, locale: english) == "2 km")
        #expect(
            Formatting.distance(meters: 13_020, width: .abbreviated, locale: english) == "13 km")
    }

    @Test func switchesToKilometresWhenMetresRoundUpTo1000() {
        #expect(Formatting.distance(meters: 996, width: .wide, locale: english) == "1 kilometre")
    }

    @Test func writesTheListDateInTheGivenLanguage() throws {
        let date = try Date("2026-11-16T12:00:00Z", strategy: .iso8601)
        #expect(Formatting.listDate(date, locale: english) == "16 November 2026")
        #expect(Formatting.listDate(date, locale: finnish) == "16. marraskuuta 2026")
    }

    @Test func usesFinnishTimeForTheListDate() throws {
        // 23:30 UTC is already the next day in Helsinki.
        let date = try Date("2026-11-16T23:30:00Z", strategy: .iso8601)
        #expect(Formatting.listDate(date, locale: english) == "17 November 2026")
    }

    @Test func turnsAFinnishNumberIntoAnInternationalTelURL() {
        #expect(Formatting.phoneURL("(09) 849 2370")?.absoluteString == "tel:+35898492370")
        #expect(Formatting.phoneURL("010 5824430")?.absoluteString == "tel:+358105824430")
    }

    @Test func keepsANumberThatAlreadyHasACountryCode() {
        #expect(Formatting.phoneURL("+358 40 123 4567")?.absoluteString == "tel:+358401234567")
    }

    @Test func hasNoTelURLWithoutDigits() {
        #expect(Formatting.phoneURL("") == nil)
        #expect(Formatting.phoneURL("–") == nil)
    }
}
