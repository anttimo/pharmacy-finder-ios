import SwiftUI

/// The app's one screen: "Use my location", the place search, the state of the search, the
/// nearest pharmacies and the footer. The layout follows the web app's `App.tsx`.
struct NearestPharmaciesView: View {
    let model: NearestPharmaciesModel

    /// Where VoiceOver focus is moved to, as on the web.
    enum Focus: Hashable {
        case locateButton
        case resultsHeading
    }

    @AccessibilityFocusState private var focus: Focus?
    @FocusState private var searchFieldIsFocused: Bool

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
                    OrDivider()
                    PlaceSearchField(model: model, isFocused: $searchFieldIsFocused)
                }
                StatusSection(state: model.state, retry: retry)
                if case .results(let pharmacies, let origin) = model.state {
                    ResultsSection(pharmacies: pharmacies, origin: origin, focus: $focus)
                }
                Divider()
                FooterView(listGeneratedAt: model.listGeneratedAt)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        // With no navigation bar, nothing covers the status bar, so scrolled content showed
        // through behind the clock. The bar material does what a navigation bar's would, and turns
        // solid with Reduce Transparency.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(.bar)
        }
        .background(Color(.systemGroupedBackground))
        // Loaded at launch, not on the first tap, so the footer shows the list's date from the
        // start and the first search doesn't wait for it.
        .task { await model.loadList() }
        .onChange(of: model.state) { _, state in
            if case .results = state {
                Task { await showResults() }
            } else if let text = state.statusText {
                announce(text)
            }
        }
        .onChange(of: model.suggestionStatus) { _, status in
            if let message = status.message { announce(message) }
        }
    }

    /// VoiceOver moves to the new results' heading, then announces the status. The heading is
    /// added in the same update that sets the state, and SwiftUI ignores focus aimed at an
    /// element that isn't on screen yet, so the move waits for it.
    private func showResults() async {
        try? await Task.sleep(for: .milliseconds(500))
        // A new search may have started meanwhile.
        guard case .results = model.state, let text = model.state.statusText else { return }
        focus = .resultsHeading
        announce(text)
    }

    /// Low priority queues the status after what VoiceOver is reading, such as the element focus
    /// just moved to, instead of the two cutting each other off.
    private func announce(_ text: LocalizedStringResource) {
        var announcement = AttributedString(localized: text)
        announcement.accessibilitySpeechAnnouncementPriority = .low
        AccessibilityNotification.Announcement(announcement).post()
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
            searchFieldIsFocused = false
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

#Preview("Results, largest text") {
    PreviewScreen(answer: .success(.preview))
        .dynamicTypeSize(.accessibility5)
}

#Preview("Results, dark") {
    PreviewScreen(answer: .success(.preview))
        .preferredColorScheme(.dark)
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
