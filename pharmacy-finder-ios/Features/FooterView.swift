import SwiftUI

/// The data source, the list's date and the credits the licences require (ADR 0001, ADR 0003).
/// The links are Markdown in the String Catalog, so each language links its own words.
struct FooterView: View {
    /// Nil until the list has loaded, which is almost at once.
    let listGeneratedAt: Date?

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("footer.source", comment: "Footer: where the pharmacy data comes from.")
            if let listGeneratedAt {
                Text(
                    "footer.updated \(Formatting.listDate(listGeneratedAt, locale: locale))",
                    comment:
                        "Footer: when the pharmacy list was generated. The placeholder is a date, such as \"16 November 2026\"."
                )
            }
            Text(
                "footer.locations \(currentYear)",
                comment:
                    "Footer: credit required by Digitransit's terms (CC BY), which geocoded the pharmacies. The placeholder is the current year."
            )
            Text(
                "footer.osm",
                comment: "Footer: notice required by ODbL section 4.3, following its example text.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    /// As a string, so it isn't formatted as a number ("2 026" in Finnish).
    private var currentYear: String {
        String(Calendar(identifier: .gregorian).component(.year, from: .now))
    }
}
