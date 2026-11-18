import Foundation

/// One pharmacy from `pharmacies.json`, built from the Fimea register by the web repo (ADR 0001).
nonisolated struct Pharmacy: Identifiable, Hashable, Sendable {
    /// Fimea register id, for example "1.2.246.553.1.52".
    let id: String
    let name: String
    let address: String
    let postcode: String
    let city: String
    /// As the register writes it, for example "(09) 849 2370". Some pharmacies have none.
    let phone: String?
    /// A branch pharmacy (sivuapteekki).
    let isBranch: Bool
    let coordinate: Coordinate

    /// The address on one line, as Finnish addresses are written: "Mannerheimintie 1, 00100
    /// Helsinki". The same in every language, so it isn't localized.
    var postalAddress: String { "\(address), \(postcode) \(city)" }
}

nonisolated extension Pharmacy: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, name, address, postcode, city, phone, branch, lat, lon
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        postcode = try container.decode(String.self, forKey: .postcode)
        city = try container.decode(String.self, forKey: .city)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        isBranch = try container.decode(Bool.self, forKey: .branch)
        coordinate = Coordinate(
            latitude: try container.decode(Double.self, forKey: .lat),
            longitude: try container.decode(Double.self, forKey: .lon)
        )
    }
}

/// A pharmacy with its straight-line distance from the search origin.
nonisolated struct NearbyPharmacy: Identifiable, Hashable, Sendable {
    let pharmacy: Pharmacy
    let distanceMeters: Double

    var id: String { pharmacy.id }
}

nonisolated extension Collection where Element == Pharmacy {
    /// The `count` pharmacies nearest to `origin` by straight-line distance, nearest first.
    /// Equal distances are ordered by id, so the result never depends on the list's order.
    func nearest(to origin: Coordinate, count: Int) -> [NearbyPharmacy] {
        let sorted =
            map { NearbyPharmacy(pharmacy: $0, distanceMeters: origin.distance(to: $0.coordinate)) }
            .sorted { a, b in
                a.distanceMeters != b.distanceMeters
                    ? a.distanceMeters < b.distanceMeters
                    : a.pharmacy.id < b.pharmacy.id
            }
        return Array(sorted.prefix(Swift.max(0, count)))
    }
}
