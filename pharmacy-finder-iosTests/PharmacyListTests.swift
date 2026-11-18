import Foundation
import Testing

@testable import pharmacy_finder_ios

struct PharmacyListTests {
    private func decode(_ json: String) throws -> PharmacyList {
        try PharmacyList.decode(from: Data(json.utf8))
    }

    @Test func decodesTheFileFormat() throws {
        let list = try decode(
            """
            {
              "generatedAt": "2026-11-16T21:48:33.649Z",
              "sourceTotal": 2, "openTotal": 2, "needsReview": 0,
              "pharmacies": [
                {"id": "1.2.246.553.1.1", "name": "Alppilan apteekki", "address": "Fleminginkatu 1",
                 "postcode": "00530", "city": "Helsinki", "phone": "(09) 849 2370",
                 "branch": false, "lat": 60.19, "lon": 24.94},
                {"id": "1.2.246.553.1.2", "name": "Sivuapteekki", "address": "Kylätie 2",
                 "postcode": "99999", "city": "Korvatunturi", "branch": true,
                 "lat": 68.0, "lon": 29.0}
              ]
            }
            """)
        #expect(abs(list.generatedAt.timeIntervalSince1970 - 1_794_865_713.649) < 0.001)
        #expect(list.pharmacies.count == 2)
        let first = list.pharmacies[0]
        #expect(first.name == "Alppilan apteekki")
        #expect(first.phone == "(09) 849 2370")
        #expect(first.isBranch == false)
        #expect(first.coordinate == Coordinate(latitude: 60.19, longitude: 24.94))
        #expect(list.pharmacies[1].phone == nil)
        #expect(list.pharmacies[1].isBranch)
    }

    @Test func rejectsADateItCannotParse() {
        #expect(throws: DecodingError.self) {
            try decode(#"{"generatedAt": "16.11.2026", "pharmacies": []}"#)
        }
    }

    @Test func rejectsAPharmacyWithoutCoordinates() {
        #expect(throws: DecodingError.self) {
            try decode(
                """
                {"generatedAt": "2026-11-16T21:48:33.649Z", "pharmacies": [
                  {"id": "1", "name": "A", "address": "B", "postcode": "00100", "city": "C",
                   "branch": false}
                ]}
                """)
        }
    }
}
