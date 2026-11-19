import Foundation
import Testing

@testable import pharmacy_finder_ios

/// The status line for each state, in both languages. The results count uses the catalog's
/// plural forms, so one and several are checked separately.
@MainActor
struct StatusTextTests {
    private static func results(_ count: Int) -> NearestPharmaciesModel.State {
        let pharmacies = (0..<count).map { index in
            NearbyPharmacy(
                pharmacy: Pharmacy(
                    id: "\(index)", name: "Apteekki", address: "Katu 1", postcode: "00100",
                    city: "Helsinki", phone: nil, isBranch: false,
                    coordinate: Coordinate(latitude: 60, longitude: 25)),
                distanceMeters: 100)
        }
        return .results(pharmacies, isApproximate: false)
    }

    private static func text(_ state: NearestPharmaciesModel.State, _ language: String) -> String? {
        guard var resource = state.statusText else { return nil }
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    @Test func idleSaysNothing() {
        #expect(NearestPharmaciesModel.State.idle.statusText == nil)
    }

    @Test func eachStateHasItsText() {
        #expect(Self.text(.locating, "en") == "Finding your location…")
        #expect(Self.text(.loading, "fi") == "Haetaan lähellä olevia apteekkeja…")
        #expect(Self.text(.denied, "en") == "Location access is turned off.")
        #expect(Self.text(.locationError, "fi") == "Sijaintiasi ei saatu haettua.")
    }

    @Test func resultsCountUsesPluralForms() {
        #expect(Self.text(Self.results(1), "en") == "Showing the nearest pharmacy.")
        #expect(Self.text(Self.results(3), "en") == "Showing the 3 nearest pharmacies.")
        #expect(Self.text(Self.results(1), "fi") == "Näytetään lähin apteekki.")
        #expect(Self.text(Self.results(3), "fi") == "Näytetään 3 lähintä apteekkia.")
    }

    @Test func onlyLocatingAndLoadingAreBusy() {
        #expect(NearestPharmaciesModel.State.locating.isBusy)
        #expect(NearestPharmaciesModel.State.loading.isBusy)
        #expect(!Self.results(3).isBusy)
        #expect(!NearestPharmaciesModel.State.denied.isBusy)
    }
}
