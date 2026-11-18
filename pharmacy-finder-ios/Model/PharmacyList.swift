import Foundation

/// The whole `pharmacies.json` file (ADR 0001). Only the fields the app uses are decoded.
nonisolated struct PharmacyList: Sendable {
    /// When the web repo's build script wrote the file. Shown in the footer.
    let generatedAt: Date
    let pharmacies: [Pharmacy]
}

nonisolated extension PharmacyList: Decodable {
    private enum CodingKeys: String, CodingKey {
        case generatedAt, pharmacies
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The file writes JavaScript's toISOString(), with milliseconds ("2026-11-16T21:48:33.649Z"),
        // which JSONDecoder's built-in .iso8601 strategy rejects.
        let generatedAtText = try container.decode(String.self, forKey: .generatedAt)
        guard
            let generatedAt = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true)
                .parse(generatedAtText)
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .generatedAt, in: container,
                debugDescription: "Not an ISO 8601 date with milliseconds: \(generatedAtText)")
        }
        self.generatedAt = generatedAt
        pharmacies = try container.decode([Pharmacy].self, forKey: .pharmacies)
    }

    static func decode(from data: Data) throws -> PharmacyList {
        try JSONDecoder().decode(PharmacyList.self, from: data)
    }
}
