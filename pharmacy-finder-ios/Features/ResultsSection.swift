import SwiftUI

/// The nearest pharmacies, with the notes that always go with them. Follows the web app's
/// `ResultsList.tsx`.
struct ResultsSection: View {
    let pharmacies: [NearbyPharmacy]
    let origin: NearestPharmaciesModel.Origin
    /// The screen moves VoiceOver focus to the heading when new results appear.
    var focus: AccessibilityFocusState<NearestPharmaciesView.Focus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused(focus, equals: .resultsHeading)
            // Always shown with results (CLAUDE.md), but quiet: it's a caveat, not the content.
            Text(
                "results.notes",
                comment:
                    "Under the results heading, small: opening hours aren't in the data, and how distances are measured."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            // The user shared only an approximate location (ADR 0103), so the order may be wrong.
            if origin == .myLocation(isApproximate: true) { approximateNote }

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

    private var heading: Text {
        switch origin {
        case .myLocation:
            Text("results.heading", comment: "Heading above the pharmacies nearest to the user.")
        case .place(let name):
            Text(
                "results.headingPlace \(name)",
                comment:
                    "Heading above the pharmacies nearest to a place the user chose. The placeholder is the place, such as \"Kamppi\" or \"Mannerheimintie 1\"."
            )
        }
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

/// One pharmacy. Its details are one VoiceOver element, so they're read together, and its
/// actions are ordinary buttons, so Voice Control, Full Keyboard Access and Switch Control can
/// reach them too.
private struct ResultRow: View {
    let nearby: NearbyPharmacy

    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL

    private var pharmacy: Pharmacy { nearby.pharmacy }
    private var phoneURL: URL? { pharmacy.phone.flatMap(Formatting.phoneURL) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            details
            // Side by side when they fit, stacked at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pharmacy.name)
                .font(.headline)
            Text("results.distance \(distance(.abbreviated))", comment: distanceComment)
                .foregroundStyle(.secondary)
            Text(pharmacy.postalAddress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                "results.rowLabel \(pharmacy.name) \(distance(.wide)) \(pharmacy.postalAddress)",
                comment:
                    "What VoiceOver reads for one pharmacy: its name, the spelled-out distance and the address."
            )
        )
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
                // The number alone doesn't say what the button does. The label keeps the number,
                // so Voice Control still matches what's on screen.
                .accessibilityLabel(Text("results.call \(phone)", comment: callComment))
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
        "VoiceOver label of the button that calls a pharmacy. The placeholder is its phone number."
    private let mapComment: StaticString = "Button that opens the pharmacy in Apple Maps."
}
