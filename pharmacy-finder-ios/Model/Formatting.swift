import Foundation

/// Text for distances, dates and phone links, in the user's locale. Pure functions, so the views
/// stay free of formatting logic and the rules are unit tested. They follow the web app's
/// `src/lib/format.ts`, except that distances keep their decimal from 10 km up.
nonisolated enum Formatting {
    /// A distance: metres under 1 km, rounded to 10 m; kilometres above, with one decimal
    /// ("10,5 km": half a kilometre matters even far away) unless it's zero ("13 km"). Halves
    /// round up, as on the web, not to the even digit as `FormatStyle` does by default.
    /// `.abbreviated` gives the visible text ("350 m", "1,2 km"), `.wide` the text VoiceOver
    /// reads ("350 metres", "1,2 kilometriä").
    static func distance(
        meters: Double,
        width: Measurement<UnitLength>.FormatStyle.UnitWidth,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let roundedMeters = (meters / 10).rounded() * 10
        let measurement =
            roundedMeters < 1000
            ? Measurement(value: roundedMeters, unit: UnitLength.meters)
            : Measurement(value: meters / 1000, unit: UnitLength.kilometers)
        return measurement.formatted(
            .measurement(
                width: width,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0...1))
                    .rounded(rule: .toNearestOrAwayFromZero)
            )
            .locale(locale)
        )
    }

    /// The calendar date of the pharmacy list ("16 November 2026", "16. marraskuuta 2026"), in
    /// Finnish time so it doesn't depend on the device's time zone.
    static func listDate(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        var style = Date.FormatStyle(date: .long, time: .omitted).locale(locale)
        style.timeZone = helsinki
        return date.formatted(style)
    }

    /// A `tel:` URL for a Finnish phone number as the register writes it ("(09) 849 2370"):
    /// digits only, with the leading 0 replaced by the +358 country code.
    static func phoneURL(_ phone: String) -> URL? {
        let digits = String(phone.filter { $0.isASCII && ($0.isNumber || $0 == "+") })
        guard digits.contains(where: \.isNumber) else { return nil }
        let international = digits.hasPrefix("0") ? "+358" + digits.dropFirst() : digits
        return URL(string: "tel:" + international)
    }

    private static let helsinki = TimeZone(identifier: "Europe/Helsinki") ?? .current
}
