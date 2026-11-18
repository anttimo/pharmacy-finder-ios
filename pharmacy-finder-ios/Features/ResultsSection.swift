import SwiftUI

/// The nearest pharmacies, with the notes that always go with them. Follows the web app's
/// `ResultsList.tsx`.
struct ResultsSection: View {
    let pharmacies: [NearbyPharmacy]
    /// The user shared only an approximate location (ADR 0103), so the order may be wrong.
    let isApproximate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("results.heading", comment: "Heading above the nearest pharmacies.")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Text(
                "results.checkHours",
                comment: "Under the results heading. Opening hours aren't in the data.")
            Text(
                "results.distanceNote",
                comment: "Under the results heading: how distances are measured.")
            if isApproximate { approximateNote }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(pharmacies) { nearby in
                    if nearby.id != pharmacies.first?.id { Divider() }
                    ResultRow(nearby: nearby)
                }
            }
            .background(
                Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .font(.subheadline)
    }

    private var approximateNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(
                    "results.approximate",
                    comment:
                        "Above the results when the user shared only an approximate location and didn't allow a precise one."
                )
            } icon: {
                Image(systemName: "location.slash")
            }
            OpenSettingsButton()
        }
    }
}

/// One pharmacy. VoiceOver reads it as one element, with Maps and calling as its actions, so the
/// list isn't three elements per pharmacy.
private struct ResultRow: View {
    let nearby: NearbyPharmacy

    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    private var pharmacy: Pharmacy { nearby.pharmacy }
    private var phoneURL: URL? { pharmacy.phone.flatMap(Formatting.phoneURL) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pharmacy.name)
                .font(.headline)
            Text("results.distance \(distance(.abbreviated))", comment: distanceComment)
                .foregroundStyle(.secondary)
            Text(pharmacy.postalAddress)
            // Side by side when they fit, stacked at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "results.rowLabel \(pharmacy.name) \(distance(.wide)) \(pharmacy.postalAddress)",
                comment:
                    "What VoiceOver reads for one pharmacy: its name, the spelled-out distance and the address."
            )
        )
        .accessibilityActions {
            Button {
                AppleMaps.open(pharmacy)
            } label: {
                Text("results.map", comment: mapComment)
            }
            if let phone = pharmacy.phone, let phoneURL {
                Button {
                    openURL(phoneURL)
                } label: {
                    Text("results.call \(phone)", comment: callComment)
                }
            }
        }
    }

    /// Maps first: most people go to the pharmacy, and fewer call it.
    @ViewBuilder private var buttons: some View {
        Button {
            AppleMaps.open(pharmacy)
        } label: {
            Label {
                Text("results.map", comment: mapComment)
            } icon: {
                Image(systemName: "map")
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        if let phone = pharmacy.phone {
            if let phoneURL {
                // iOS asks before it calls, so a stray tap doesn't start a call.
                Button {
                    openURL(phoneURL)
                } label: {
                    Label {
                        Text(phone)
                    } icon: {
                        Image(systemName: "phone")
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            } else {
                Text(phone)
            }
        }
    }

    private func distance(_ width: Measurement<UnitLength>.FormatStyle.UnitWidth) -> String {
        Formatting.distance(meters: nearby.distanceMeters, width: width, locale: locale)
    }

    private let distanceComment: StaticString =
        "A pharmacy's distance, such as \"1,2 km\", measured in a straight line."
    private let callComment: StaticString =
        "VoiceOver action on a pharmacy that calls it. The placeholder is its phone number."
    private let mapComment: StaticString = "Button that opens the pharmacy in Apple Maps."
}
