import SwiftUI

/// The app's one screen: "Use my location", the state of the search, the nearest pharmacies and
/// the footer. The layout follows the web app's `App.tsx`.
struct NearestPharmaciesView: View {
    let model: NearestPharmaciesModel

    /// Where VoiceOver focus is moved to, as on the web.
    enum Focus: Hashable {
        case locateButton
        case resultsHeading
    }

    @AccessibilityFocusState private var focus: Focus?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    // In the content, not a navigation title: large navigation titles don't
                    // wrap, and this one is cut off even at the default text size.
                    Text("app.title", comment: "The screen's title.")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("app.intro", comment: "Intro under the title.")
                    locateButton
                }
                StatusSection(state: model.state, retry: retry)
                if case .results(let pharmacies, let isApproximate) = model.state {
                    ResultsSection(
                        pharmacies: pharmacies, isApproximate: isApproximate, focus: $focus)
                }
                Divider()
                FooterView(listGeneratedAt: model.listGeneratedAt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        // Loaded at launch, not on the first tap, so the footer shows the list's date from the
        // start and the first search doesn't wait for it.
        .task { await model.loadList() }
        .onChange(of: model.state) { _, state in
            if case .results = state {
                // New results are hard to miss: VoiceOver moves to their heading and reads it.
                // The status line isn't announced too, as the two would talk over each other;
                // it's just above the heading.
                focus = .resultsHeading
            } else if let text = state.statusText {
                AccessibilityNotification.Announcement(String(localized: text)).post()
            }
        }
    }

    /// "Try again" disappears once the search restarts, so VoiceOver focus moves to where the
    /// search started, as on the web.
    private func retry() {
        model.useMyLocation()
        focus = .locateButton
    }

    // Stays tappable during a search: tapping again starts over, as on the web.
    private var locateButton: some View {
        Button {
            model.useMyLocation()
        } label: {
            Label {
                Text("locate.button", comment: "The button that finds pharmacies near the user.")
            } icon: {
                Image(systemName: "location.fill")
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            // White on the light dark-mode accent would be unreadable, so the text is black there.
            .foregroundStyle(Color(.onAccent))
        }
        .buttonStyle(.borderedProminent)
        .accessibilityFocused($focus, equals: .locateButton)
    }
}

/// The status line and, for denied and error, what the user can do about it.
private struct StatusSection: View {
    let state: NearestPharmaciesModel.State
    let retry: () -> Void

    var body: some View {
        if let text = state.statusText {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if state.isBusy { ProgressView() }
                    Text(text).fontWeight(.medium)
                }
                switch state {
                case .denied:
                    Text(
                        "denied.body",
                        comment:
                            "Under \"Location access is turned off.\": how to allow location, also when Location Services are off for the whole device."
                    )
                    OpenSettingsButton()
                case .locationError:
                    Text(
                        "error.locationBody",
                        comment: "Under \"We couldn't get your location.\": what to check.")
                    Button(action: retry) {
                        Text("error.retry", comment: "Button that tries to get the location again.")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                case .idle, .locating, .loading, .results:
                    EmptyView()
                }
            }
        }
    }
}

/// Opens this app's page in the Settings app. iOS doesn't let apps open the Location Services
/// page itself, so the texts beside this button say where to go from there.
struct OpenSettingsButton: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } label: {
            Text("settings.open", comment: "Button that opens this app's page in the Settings app.")
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
    }
}

#Preview("Idle") {
    PreviewScreen(answer: nil, searches: false)
}

#Preview("Locating") {
    PreviewScreen(answer: nil)
}

#Preview("Results") {
    PreviewScreen(answer: .success(.preview))
}

#Preview("Results, Finnish") {
    PreviewScreen(answer: .success(.preview))
        .environment(\.locale, Locale(identifier: "fi"))
}

#Preview("Approximate") {
    PreviewScreen(
        answer: .success(
            LocationFix(coordinate: LocationFix.preview.coordinate, isApproximate: true)))
}

#Preview("Denied") {
    PreviewScreen(answer: .failure(.denied))
}

#Preview("Location error") {
    PreviewScreen(answer: .failure(.unavailable))
}
