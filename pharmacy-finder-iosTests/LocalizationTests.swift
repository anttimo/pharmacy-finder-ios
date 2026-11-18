import Foundation
import Testing

@testable import pharmacy_finder_ios

/// Every string the user can see exists in both Finnish and English (CLAUDE.md). Reads the
/// String Catalogs' source files: the built app has them compiled per language, where a key
/// missing from one language no longer shows.
struct LocalizationTests {
    static let catalogs = ["Localizable", "InfoPlist"]
    static let languages = ["en", "fi"]

    @Test(arguments: catalogs)
    func everyKeyIsTranslatedIntoFinnishAndEnglish(catalog: String) throws {
        let strings = try Self.strings(in: catalog)
        #expect(!strings.isEmpty)
        for (key, entry) in strings {
            for language in Self.languages {
                let values = entry.localizations?[language]?.translatedValues ?? []
                #expect(!values.isEmpty, "\(catalog): \(key) has no translated \(language)")
            }
        }
    }

    /// A placeholder or link missing from one language would crash or lose the attribution.
    @Test(arguments: catalogs)
    func finnishAndEnglishHaveTheSamePlaceholdersAndLinks(catalog: String) throws {
        for (key, entry) in try Self.strings(in: catalog) {
            let en = entry.localizations?["en"]?.mainValue ?? ""
            let fi = entry.localizations?["fi"]?.mainValue ?? ""
            #expect(Self.placeholders(in: en) == Self.placeholders(in: fi), "\(catalog): \(key)")
            #expect(Self.links(in: en) == Self.links(in: fi), "\(catalog): \(key)")
        }
    }

    /// The catalog is in the app target and compiled into a Finnish localization.
    @Test func theAppHasTheFinnishStrings() throws {
        let path = try #require(Bundle.main.path(forResource: "fi", ofType: "lproj"))
        let finnish = try #require(Bundle(path: path))
        #expect(
            finnish.localizedString(forKey: "locate.button", value: nil, table: nil)
                == "Käytä sijaintiani")
    }

    // MARK: - Reading the catalog

    private struct Catalog: Decodable {
        let strings: [String: Entry]
    }

    private struct Entry: Decodable {
        let localizations: [String: Localization]?
    }

    private struct Localization: Decodable {
        struct Unit: Decodable {
            struct StringUnit: Decodable {
                let state: String
                let value: String
            }
            let stringUnit: StringUnit?
        }
        struct Variations: Decodable {
            let plural: [String: Unit]?
        }
        let stringUnit: Unit.StringUnit?
        let variations: Variations?

        /// The translated texts: one, or one per plural form. Empty if any is untranslated.
        var translatedValues: [String] {
            let units =
                stringUnit.map { [$0] } ?? variations?.plural?.values.map(\.stringUnit) ?? []
            let translated = units.compactMap { $0?.state == "translated" ? $0?.value : nil }
            return translated.count == units.count && !translated.contains("") ? translated : []
        }

        /// The text, or its "other" plural form, which is the one with every placeholder.
        var mainValue: String? {
            stringUnit?.value ?? variations?.plural?["other"]?.stringUnit?.value
        }
    }

    private static func strings(in catalog: String) throws -> [String: Entry] {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "pharmacy-finder-ios/Resources/\(catalog).xcstrings")
        return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url)).strings
    }

    /// Format specifiers such as `%@`, `%lld` or `%2$@`, in order of argument.
    private static func placeholders(in text: String) -> [String] {
        text.matches(of: /%(\d+\$)?(lld|ld|d|@)/).enumerated().map { index, match in
            let position = match.output.1.map { String($0.dropLast()) } ?? String(index + 1)
            return "\(position):\(match.output.2)"
        }
        .sorted()
    }

    /// The URLs of Markdown links.
    private static func links(in text: String) -> [String] {
        text.matches(of: /\]\(([^)]+)\)/).map { String($0.output.1) }
    }
}
