import XCTest

/// Smoke tests of the one screen, in English, with a fixed location instead of the real one
/// (`FixedLocationProvider`), so no permission prompt appears.
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

    // MARK: - Helpers

    private func launch(location: String, language: String = "en", region: String = "en_FI")
        -> XCUIApplication
    {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-fixedLocation", location,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", region,
        ]
        app.launch()
        return app
    }

    /// Xcode's accessibility audit, with each issue's element named in the failure, since the
    /// audit's own message ("Contrast failed") doesn't say which element it means.
    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            if Self.isAccepted(issue) { return true }
            let element = issue.element.map { "\"\($0.label)\" at \($0.frame)" } ?? "no element"
            XCTFail("\(issue.compactDescription): \(issue.detailedDescription) (\(element))")
            return true
        }
    }

    /// Texts in iOS's grey secondary colour: the distance and the footer.
    private static let secondaryTextPrefixes = [
        "Pharmacy data source:", "Pharmacy data updated ", "Pharmacy locations:",
        "Contains information from ",
    ]

    /// Audit issues accepted on purpose, each for a reason the audit can't know.
    private static func isAccepted(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        guard let element = issue.element else { return false }
        let label = element.label
        switch issue.auditType {
        case .contrast:
            // iOS's grey secondary text is about 3.3:1, kept on purpose: it's the platform's
            // standard look, and Increase Contrast darkens it for those who need more.
            return label.contains(" in a straight line")
                || secondaryTextPrefixes.contains { label.hasPrefix($0) }
        case .dynamicType:
            // A result's buttons do scale (checked in screenshots at the largest size). The audit
            // misreads them because `ViewThatFits` swaps side by side for stacked as it changes
            // the text size.
            return label == "Show in Maps" || label.wholeMatch(of: /[\d ()+-]+/) != nil
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
