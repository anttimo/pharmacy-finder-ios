import SwiftUI

/// The address or place field, with its suggestions listed under it while it has focus. Choosing
/// a suggestion, or Return for the top one, starts the search. There's no separate search button,
/// as on the web (`PlaceSearch.tsx`).
struct PlaceSearchField: View {
    @Bindable var model: NearestPharmaciesModel
    /// The screen owns it, so "Use my location" can close the keyboard.
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("search.label", comment: label)
                .fontWeight(.semibold)
                // The field reads the same label to VoiceOver.
                .accessibilityHidden(true)
            TextField(
                text: $model.searchText,
                // One line, not `axis: .vertical`: a wrapping field types a new line on Return
                // instead of submitting.
                prompt: Text("search.prompt", comment: "Example text in the empty search field.")
            ) {
                Text("search.label", comment: label)
            }
            .focused(isFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .onSubmit { model.chooseTopSuggestion() }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary))
            // With a prompt, SwiftUI doesn't give VoiceOver the label above, so it's set here.
            .accessibilityLabel(Text("search.label", comment: label))
            .accessibilityHint(Text("search.privacy", comment: privacyComment))

            // Only while the field has focus, so a late answer can't open the list elsewhere.
            if isFocused.wrappedValue, !model.suggestions.isEmpty { suggestionList }
            // Also without focus: it's about the text, which stays in the field.
            if let message = model.suggestionStatus.message {
                if model.suggestionStatus == .failed {
                    // The icon, so the error doesn't read as just another note.
                    Label {
                        Text(message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").accessibilityHidden(true)
                    }
                } else {
                    Text(message)
                }
            }

            Text("search.privacy", comment: privacyComment)
                .font(.footnote)
                .foregroundStyle(.secondary)
                // VoiceOver reads it as the field's hint.
                .accessibilityHidden(true)
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.suggestions) { suggestion in
                if suggestion.id != model.suggestions.first?.id { Divider() }
                Button {
                    isFocused.wrappedValue = false
                    model.choose(suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private let label: StaticString = "Label of the address or place search field."
    private let privacyComment: StaticString =
        "Under the search field: what happens to the text the user types."
}

/// "or" between "Use my location" and the search field, with a line on each side.
struct OrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            line
            Text(
                "search.or", comment: "Between the \"Use my location\" button and the search field."
            )
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}
