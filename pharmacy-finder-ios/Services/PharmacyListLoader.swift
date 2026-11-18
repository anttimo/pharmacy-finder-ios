import Foundation

/// Where the pharmacy list comes from (ADR 0101). The bundled file is the only source for now;
/// live loading would be a second implementation, without changes to the model or views.
///
/// Loading can't fail: the list has no error state. A live loader would fall back to the bundled
/// copy instead of failing.
nonisolated protocol PharmacyListLoader: Sendable {
    func load() async -> PharmacyList
}

/// Reads `pharmacies.json` from the app bundle.
nonisolated struct BundledPharmacyListLoader: PharmacyListLoader {
    /// Runs off the main actor: decoding about 800 entries shouldn't block the UI.
    ///
    /// A missing or broken file is a build mistake, like a missing image, so it stops the app
    /// instead of becoming a state the UI has to handle. iOS checks the app's signature, so the
    /// file can't change after install, and `BundledPharmacyListLoaderTests` decodes the real
    /// file, so a bad copy fails the tests before it can ship.
    @concurrent
    func load() async -> PharmacyList {
        guard let url = Bundle.main.url(forResource: "pharmacies", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("pharmacies.json is missing from the app bundle")
        }
        do {
            return try PharmacyList.decode(from: data)
        } catch {
            fatalError("pharmacies.json doesn't decode: \(error)")
        }
    }
}
