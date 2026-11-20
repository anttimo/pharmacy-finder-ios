import XCTest

/// Smoke tests of the one screen, in English, with a fixed location instead of the real one
/// (`FixedLocationProvider`), so no permission prompt appears, and a few fixed places instead of
/// Apple's place search (`FixedPlaceSearch`).
@MainActor
final class NearestPharmaciesUITests: XCTestCase {
    /// Helsinki railway station.
    private static let helsinki = "60.171,24.941"

    func testUseMyLocationShowsThreeNearestPharmacies() throws {
        let app = launch(location: Self.helsinki)

        app.buttons["Use my location"].tap()

        XCTAssertTrue(
            app.staticTexts["Showing the 3 nearest pharmacies."].waitForExistence(timeout: 5))
        XCTAssertEqual(resultRows(in: app).count, 3)
        // Ordinary buttons, not only VoiceOver actions, so Voice Control and Full Keyboard Access
        // reach them too.
        XCTAssertEqual(app.buttons.matching(identifier: "Show in Maps").count, 3)
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Call '")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Check opening hours with the pharmacy."].exists)
        XCTAssertTrue(footerText(in: app, startingWith: "Pharmacy data source:").exists)
        try audit(app)
    }

    func testApproximateLocationShowsTheNote() {
        let app = launch(location: Self.helsinki + ",approximate")

        app.buttons["Use my location"].tap()

        XCTAssertTrue(
            app.staticTexts["Showing the 3 nearest pharmacies."].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH 'Your location is approximate'")
            ).firstMatch.exists)
        XCTAssertTrue(app.buttons["Open Settings"].exists)
    }

    func testDeniedLocationOffersSettings() throws {
        let app = launch(location: "denied")

        app.buttons["Use my location"].tap()

        XCTAssertTrue(
            app.staticTexts["Location access is turned off."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Settings"].exists)
        try audit(app)
    }

    func testLocationErrorOffersRetry() {
        let app = launch(location: "unavailable")

        app.buttons["Use my location"].tap()

        XCTAssertTrue(
            app.staticTexts["We couldn't get your location."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try again"].exists)
    }

    /// The app has no Swedish, so on a Swedish device it falls back to English, and the footer's
    /// date must be in English too ("16 November 2026", not "16 november 2026").
    func testSwedishDeviceShowsEnglishDates() {
        let app = launch(location: Self.helsinki, language: "sv", region: "sv_FI")

        let updated = footerText(in: app, startingWith: "Pharmacy data updated ")
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        XCTAssertNotNil(
            updated.label.range(
                of: #"^Pharmacy data updated \d{1,2}\.? [A-Z][a-z]+ \d{4}\.$"#,
                options: .regularExpression),
            updated.label)
    }

    // MARK: - Place search

    func testChoosingASuggestionShowsPharmaciesNearIt() throws {
        let app = launch(location: Self.helsinki)

        let field = app.textFields["Address or place"]
        field.tap()
        field.typeText("kamp")
        let kamppi = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Kamppi'"))
            .firstMatch
        XCTAssertTrue(kamppi.waitForExistence(timeout: 5))
        kamppi.tap()

        XCTAssertTrue(app.staticTexts["Pharmacies near Kamppi"].waitForExistence(timeout: 5))
        XCTAssertEqual(resultRows(in: app).count, 3)
        XCTAssertEqual(field.value as? String, "Kamppi")
        try audit(app)
    }

    func testReturnChoosesTheTopSuggestion() {
        let app = launch(location: Self.helsinki)

        let field = app.textFields["Address or place"]
        field.tap()
        field.typeText("keskus\n")

        XCTAssertTrue(app.staticTexts["Pharmacies near Keskustori"].waitForExistence(timeout: 5))
    }

    func testUseMyLocationEmptiesTheField() {
        let app = launch(location: Self.helsinki)
        let field = app.textFields["Address or place"]
        field.tap()
        field.typeText("keskus\n")
        XCTAssertTrue(app.staticTexts["Pharmacies near Keskustori"].waitForExistence(timeout: 5))

        app.buttons["Use my location"].tap()

        XCTAssertTrue(app.staticTexts["Pharmacies near you"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(field.value as? String, "Keskustori")
    }

    func testTextWithNoMatchesSaysSoUnderTheField() throws {
        let app = launch(location: Self.helsinki)
        let field = app.textFields["Address or place"]
        field.tap()
        field.typeText("zzz")

        let message = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'No places found in Finland.'")
        ).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        try audit(app)
    }

    func testAFailedPlaceSearchSaysSoUnderTheField() throws {
        let app = launch(location: Self.helsinki, places: "failing")
        let field = app.textFields["Address or place"]
        field.tap()
        field.typeText("kamp")

        let message = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Address search isn'")
        ).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        try audit(app)
    }

    func testReturnWithNoMatchesSaysNoPlaceWasFound() throws {
        let app = launch(location: Self.helsinki)
        let field = app.textFields["Address or place"]
        field.tap()
        field.typeText("zzz\n")

        XCTAssertTrue(app.staticTexts["No place found in Finland."].waitForExistence(timeout: 5))
        try audit(app)
    }

    func testAFailedPlaceSearchOffersRetry() throws {
        let app = launch(location: Self.helsinki, places: "failing")
        let field = app.textFields["Address or place"]
        field.tap()
        field.typeText("kamp\n")

        XCTAssertTrue(
            app.staticTexts["We couldn't search for the place."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Try again"].exists)
        try audit(app)

        // Retries the place, not the location: that would empty the field and show results for
        // the fixed location. This search always fails, so the error comes back.
        app.buttons["Try again"].tap()
        XCTAssertFalse(
            app.staticTexts["Showing the 3 nearest pharmacies."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["We couldn't search for the place."].exists)
        XCTAssertEqual(field.value as? String, "kamp")
    }

    // MARK: - Helpers

    private func launch(
        location: String, places: String = "YES", language: String = "en", region: String = "en_FI"
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-fixedLocation", location,
            "-fixedPlaces", places,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", region,
        ]
        app.launch()
        return app
    }

    /// Xcode's accessibility audit, with each issue's element named in the failure, since the
    /// audit's own message doesn't say which element it means.
    ///
    /// Contrast is left out: the audit misjudges elements cut off by the screen's edge or on a
    /// scrolled screen, so whether it passed depended on the scroll position. The colours are
    /// semantic or checked by hand (the `a11y-check` skill), and Increase Contrast strengthens them.
    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: .all.subtracting(.contrast)) { issue in
            if Self.isAccepted(issue) { return true }
            let element = issue.element.map { "\"\($0.label)\" at \($0.frame)" } ?? "no element"
            XCTFail("\(issue.compactDescription): \(issue.detailedDescription) (\(element))")
            return true
        }
    }

    /// Audit issues accepted on purpose, each for a reason the audit can't know.
    private static func isAccepted(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard let element = issue.element else { return false }
        let label = element.label
        switch issue.auditType {
        case .dynamicType:
            // A result's buttons do scale (checked in screenshots at the largest size). The audit
            // misreads them because `ViewThatFits` swaps side by side for stacked as it changes
            // the text size.
            return label == "Show in Maps" || label.wholeMatch(of: /[\d ()+-]+/) != nil
        case .textClipped:
            // The search field is one line, so long text scrolls sideways instead of wrapping,
            // as in iOS's own search fields; its text does scale. A wrapping field would type a
            // new line on Return instead of searching.
            return element.elementType == .textField
        default:
            return false
        }
    }

    /// The result rows' details, each one element whose label has the distance and the address
    /// ("Name, 70 metres in a straight line, Address").
    private func resultRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS ' in a straight line, '"))
    }

    /// Footer texts contain links, so they're matched by their start.
    private func footerText(in app: XCUIApplication, startingWith start: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", start)).firstMatch
    }
}
