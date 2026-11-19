import Foundation
import Testing

@testable import pharmacy_finder_ios

@MainActor
struct NearestPharmaciesModelTests {
    /// Helsinki railway station, with pharmacies at growing distances to the north.
    private static let here = Coordinate(latitude: 60.171, longitude: 24.941)
    /// About 50 km north, nearest to "far".
    private static let elsewhere = Coordinate(latitude: 60.62, longitude: 24.941)
    private static let generatedAt = Date(timeIntervalSince1970: 1_763_329_713)

    private static let kamppi = PlaceSuggestion(title: "Kamppi", subtitle: "Helsinki")
    private static let kampinkuja = PlaceSuggestion(title: "Kampinkuja 2", subtitle: "Helsinki")
    private static let keskustori = PlaceSuggestion(title: "Keskustori", subtitle: "Tampere")

    private let location = FakeLocationProvider()
    private let places = FakePlaceSearch()
    private let loader: FakePharmacyListLoader
    private let model: NearestPharmaciesModel

    init() {
        let pharmacies = [("a", 0.001), ("b", 0.002), ("c", 0.003), ("d", 0.004), ("far", 0.45)]
            .map { id, offset in
                Pharmacy(
                    id: id, name: id, address: "Katu 1", postcode: "00100", city: "Helsinki",
                    phone: nil, isBranch: false,
                    coordinate: Coordinate(
                        latitude: Self.here.latitude + offset, longitude: Self.here.longitude))
            }
        loader = FakePharmacyListLoader(
            list: PharmacyList(generatedAt: Self.generatedAt, pharmacies: pharmacies))
        model = NearestPharmaciesModel(
            listLoader: loader, locationProvider: location, placeSearch: places)
        places.suggestionsByText = ["ka": [Self.kamppi, Self.kampinkuja], "ke": [Self.keskustori]]
        places.places = [
            Self.kamppi: Place(name: "Kamppi", coordinate: Self.elsewhere),
            Self.keskustori: Place(name: "Keskustori", coordinate: Self.here),
        ]
    }

    private static func fix(_ coordinate: Coordinate, approximate: Bool = false) -> Result<
        LocationFix, LocationError
    > {
        .success(LocationFix(coordinate: coordinate, isApproximate: approximate))
    }

    /// The ids of the results, or nil if the state isn't `results`. Distances aren't compared:
    /// CoreLocation's aren't exactly repeatable (see `Coordinate.distance(to:)`).
    private var resultIDs: [String]? {
        guard case .results(let pharmacies, _) = model.state else { return nil }
        return pharmacies.map(\.id)
    }

    private var resultsAreApproximate: Bool? {
        guard case .results(_, .myLocation(let isApproximate)) = model.state else { return nil }
        return isApproximate
    }

    private var resultsOrigin: NearestPharmaciesModel.Origin? {
        guard case .results(_, let origin) = model.state else { return nil }
        return origin
    }

    // MARK: - Starting

    @Test func startsIdleWithoutAskingForTheLocation() {
        #expect(model.state == .idle)
        #expect(location.locationRequests == 0)
    }

    @Test func loadingTheListGivesTheFooterDate() async {
        #expect(model.listGeneratedAt == nil)
        await model.loadList()
        #expect(model.listGeneratedAt == Self.generatedAt)
        #expect(location.locationRequests == 0)
    }

    // MARK: - Use my location

    @Test func showsTheThreeNearest() async {
        location.queuedAnswers = [Self.fix(Self.here)]
        await model.useMyLocation().value
        #expect(resultIDs == ["a", "b", "c"])
        #expect(resultsAreApproximate == false)
    }

    @Test func showsLocatingUntilTheLocationArrives() async {
        let search = model.useMyLocation()
        #expect(model.state == .locating)
        await location.answer(Self.fix(Self.here))
        await search.value
        #expect(resultIDs == ["a", "b", "c"])
    }

    @Test func showsDeniedWhenPermissionIsRefused() async {
        location.queuedAnswers = [.failure(.denied)]
        await model.useMyLocation().value
        #expect(model.state == .denied)
    }

    @Test func showsALocationErrorWhenThereIsNoFix() async {
        location.queuedAnswers = [.failure(.unavailable)]
        await model.useMyLocation().value
        #expect(model.state == .locationError)
    }

    @Test func retryingAfterAnErrorShowsResults() async {
        location.queuedAnswers = [.failure(.unavailable), Self.fix(Self.here)]
        await model.useMyLocation().value
        await model.useMyLocation().value
        #expect(resultIDs == ["a", "b", "c"])
    }

    // MARK: - The pharmacy list

    @Test func showsLoadingUntilTheListIsReady() async {
        loader.waitsForRelease = true
        location.queuedAnswers = [Self.fix(Self.here)]
        let search = model.useMyLocation()
        await waitUntil { model.state == .loading }
        await loader.release()
        await search.value
        #expect(resultIDs == ["a", "b", "c"])
    }

    @Test func skipsLoadingWhenTheListIsAlreadyLoaded() async {
        await model.loadList()
        let search = model.useMyLocation()
        await location.answer(Self.fix(Self.here))
        await search.value
        #expect(resultIDs == ["a", "b", "c"])
        // `loading` would have been set between the answer and the results; with the list
        // already there, nothing waits in between, so the load count is the evidence.
        #expect(loader.loadCount == 1)
    }

    @Test func aSearchDuringTheLaunchLoadSharesIt() async {
        loader.waitsForRelease = true
        location.queuedAnswers = [Self.fix(Self.here), Self.fix(Self.here)]
        let launchLoad = Task { await model.loadList() }
        let search = model.useMyLocation()
        await waitUntil { model.state == .loading }
        await loader.release()
        await launchLoad.value
        await search.value
        await model.useMyLocation().value
        #expect(resultIDs == ["a", "b", "c"])
        #expect(loader.loadCount == 1)
    }

    // MARK: - A new search cancels the running one

    @Test func anOlderSearchAnsweringLateDoesNotReplaceNewerResults() async {
        let older = model.useMyLocation()
        let newer = model.useMyLocation()
        // Both wait for a location. The older request is answered last, from elsewhere.
        await location.answer(Self.fix(Self.elsewhere))  // the older request
        await location.answer(Self.fix(Self.here))  // the newer one
        await older.value
        await newer.value
        #expect(resultIDs == ["a", "b", "c"])
    }

    @Test func anOlderSearchFailingLateDoesNotReplaceNewerResults() async {
        let older = model.useMyLocation()
        let newer = model.useMyLocation()
        await location.answer(.failure(.denied))
        await location.answer(Self.fix(Self.here))
        await older.value
        await newer.value
        #expect(resultIDs == ["a", "b", "c"])
    }

    // MARK: - Approximate location (ADR 0103)

    @Test func asksForAPreciseLocationAndUsesIt() async {
        location.allowsPreciseLocation = true
        location.queuedAnswers = [
            Self.fix(Self.elsewhere, approximate: true), Self.fix(Self.here),
        ]
        await model.useMyLocation().value
        #expect(location.preciseLocationRequests == 1)
        #expect(resultIDs == ["a", "b", "c"])
        #expect(resultsAreApproximate == false)
    }

    @Test func usesTheApproximateLocationWhenPreciseIsDeclined() async {
        location.queuedAnswers = [Self.fix(Self.here, approximate: true)]
        await model.useMyLocation().value
        #expect(location.preciseLocationRequests == 1)
        #expect(location.locationRequests == 1)
        #expect(resultIDs == ["a", "b", "c"])
        #expect(resultsAreApproximate == true)
    }

    @Test func keepsTheApproximateLocationWhenThePreciseFixFails() async {
        location.allowsPreciseLocation = true
        location.queuedAnswers = [Self.fix(Self.here, approximate: true), .failure(.unavailable)]
        await model.useMyLocation().value
        #expect(resultIDs == ["a", "b", "c"])
        #expect(resultsAreApproximate == true)
    }

    @Test func asksForAPreciseLocationOnlyOncePerLaunch() async {
        location.queuedAnswers = [
            Self.fix(Self.here, approximate: true), Self.fix(Self.here, approximate: true),
        ]
        await model.useMyLocation().value
        await model.useMyLocation().value
        #expect(location.preciseLocationRequests == 1)
        #expect(resultsAreApproximate == true)
    }

    @Test func aCancelledSearchDoesNotUseUpThePreciseLocationAsk() async {
        location.allowsPreciseLocation = true
        let older = model.useMyLocation()
        let newer = model.useMyLocation()
        await location.answer(Self.fix(Self.elsewhere, approximate: true))  // the older request
        await location.answer(Self.fix(Self.here, approximate: true))  // the newer one
        await location.answer(Self.fix(Self.here))  // the newer one's precise fix
        await older.value
        await newer.value
        #expect(location.preciseLocationRequests == 1)
        #expect(resultIDs == ["a", "b", "c"])
        #expect(resultsAreApproximate == false)
    }

    @Test func doesNotAskForAPreciseLocationWhenItIsAlreadyPrecise() async {
        location.queuedAnswers = [Self.fix(Self.here)]
        await model.useMyLocation().value
        #expect(location.preciseLocationRequests == 0)
    }

    // MARK: - Place search

    @Test func suggestsPlacesFromTwoLetters() async {
        model.searchText = "k"
        model.searchText = "ka"
        await waitUntil { !model.suggestions.isEmpty }
        #expect(model.suggestions == [Self.kamppi, Self.kampinkuja])
        #expect(places.suggestionRequests == ["ka"])
    }

    @Test func textThatTrimsToTheSameQueryDoesNotAskAgain() async {
        model.searchText = "ka"
        await waitUntil { !model.suggestions.isEmpty }
        model.searchText = "ka "
        model.searchText = "kam"
        await waitUntil { places.suggestionRequests.count == 2 }
        #expect(places.suggestionRequests == ["ka", "kam"])
    }

    @Test func emptyingTheFieldRemovesTheSuggestions() async {
        model.searchText = "ka"
        await waitUntil { !model.suggestions.isEmpty }
        model.searchText = ""
        #expect(model.suggestions.isEmpty)
    }

    @Test func anOlderAnswerArrivingLateDoesNotReplaceNewerSuggestions() async {
        places.waitsForRelease = true
        model.searchText = "ka"
        await waitUntil { places.suggestionRequests.count == 1 }
        model.searchText = "ke"
        await places.release()  // "ka"
        await places.release()  // "ke"
        await waitUntil { !model.suggestions.isEmpty }
        #expect(model.suggestions == [Self.keskustori])
    }

    @Test func choosingAPlaceShowsTheNearestToIt() async {
        await model.choose(Self.kamppi).value
        #expect(resultIDs?.first == "far")
        #expect(resultsOrigin == .place("Kamppi"))
    }

    @Test func choosingAPlacePutsItsNameInTheFieldWithoutSuggestingIt() async {
        model.searchText = "ka"
        await waitUntil { !model.suggestions.isEmpty }
        await model.choose(Self.kamppi).value
        #expect(model.searchText == "Kamppi")
        #expect(model.suggestions.isEmpty)
        #expect(places.suggestionRequests == ["ka"])
    }

    @Test func returnChoosesTheTopSuggestion() async {
        model.searchText = "ka"
        await waitUntil { !model.suggestions.isEmpty }
        await model.chooseTopSuggestion().value
        #expect(resultsOrigin == .place("Kamppi"))
    }

    @Test func returnBeforeTheSuggestionsArriveWaitsForThem() async {
        places.waitsForRelease = true
        model.searchText = "ka"
        let submit = model.chooseTopSuggestion()
        await places.release()
        await submit.value
        #expect(resultsOrigin == .place("Kamppi"))
    }

    @Test func returnWaitingForSuggestionsIsDroppedByUseMyLocation() async {
        places.waitsForRelease = true
        location.queuedAnswers = [Self.fix(Self.here)]
        model.searchText = "ka"
        let submit = model.chooseTopSuggestion()
        await model.useMyLocation().value
        await places.release()
        await submit.value
        #expect(resultsOrigin == .myLocation(isApproximate: false))
    }

    @Test func useMyLocationEmptiesTheField() async {
        await model.choose(Self.kamppi).value
        location.queuedAnswers = [Self.fix(Self.here)]
        await model.useMyLocation().value
        #expect(model.searchText == "")
        #expect(resultsOrigin == .myLocation(isApproximate: false))
    }

    @Test func choosingAPlaceCancelsALocationSearch() async {
        let older = model.useMyLocation()
        let newer = model.choose(Self.keskustori)
        await location.answer(Self.fix(Self.elsewhere))
        await older.value
        await newer.value
        #expect(resultIDs == ["a", "b", "c"])
        #expect(resultsOrigin == .place("Keskustori"))
    }
}
