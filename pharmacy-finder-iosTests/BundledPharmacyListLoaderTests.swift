import Foundation
import Testing

@testable import pharmacy_finder_ios

/// Checks the bundled file itself, so a bad copy from the web repo fails here before it reaches
/// users (ADR 0101).
struct BundledPharmacyListLoaderTests {
    @Test func bundledListHasPharmaciesWithUniqueIdsNamesAddressesAndCoordinatesInFinland()
        async throws
    {
        let list = await BundledPharmacyListLoader().load()
        #expect(list.pharmacies.count > 500)
        #expect(Set(list.pharmacies.map(\.id)).count == list.pharmacies.count)
        for pharmacy in list.pharmacies {
            #expect(!pharmacy.name.isEmpty, "\(pharmacy.id)")
            #expect(!pharmacy.address.isEmpty, "\(pharmacy.id)")
            #expect((59.4...70.2).contains(pharmacy.coordinate.latitude), "\(pharmacy.id)")
            #expect((19...31.7).contains(pharmacy.coordinate.longitude), "\(pharmacy.id)")
        }
    }
}
