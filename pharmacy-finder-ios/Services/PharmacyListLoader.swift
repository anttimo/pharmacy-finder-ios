import Foundation

/// Where the pharmacy list comes from (ADR 0101). The bundled file is the only source for now;
/// live loading would be a second implementation, without changes to the model or views.
nonisolated protocol PharmacyListLoader: Sendable {
    func load() async throws -> PharmacyList
}

nonisolated enum PharmacyListLoaderError: Error {
    case missingFile
}

/// Reads `pharmacies.json` from the app bundle.
nonisolated struct BundledPharmacyListLoader: PharmacyListLoader {
    private let url: URL?

    init(url: URL? = Bundle.main.url(forResource: "pharmacies", withExtension: "json")) {
        self.url = url
    }

    /// Runs off the main actor: decoding about 800 entries shouldn't block the UI.
    @concurrent
    func load() async throws -> PharmacyList {
        guard let url else { throw PharmacyListLoaderError.missingFile }
        return try PharmacyList.decode(from: Data(contentsOf: url))
    }
}
