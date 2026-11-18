import Foundation
import Testing

@testable import pharmacy_finder_ios

/// A location provider the test controls. Queued answers are given right away. With none queued,
/// a request waits until the test calls `answer(_:)`, so the test can look at the state meanwhile.
@MainActor
final class FakeLocationProvider: LocationProvider {
    var queuedAnswers: [Result<LocationFix, LocationError>] = []
    /// Whether the user allows a precise location when asked.
    var allowsPreciseLocation = false
    private(set) var locationRequests = 0
    private(set) var preciseLocationRequests = 0
    private var waiting: [CheckedContinuation<Result<LocationFix, LocationError>, Never>] = []

    func currentLocation() async throws(LocationError) -> LocationFix {
        locationRequests += 1
        if !queuedAnswers.isEmpty { return try queuedAnswers.removeFirst().get() }
        return try await withCheckedContinuation { waiting.append($0) }.get()
    }

    func requestPreciseLocation() async -> Bool {
        preciseLocationRequests += 1
        return allowsPreciseLocation
    }

    /// Answers the oldest waiting request, after waiting for one to arrive.
    func answer(_ result: Result<LocationFix, LocationError>) async {
        await waitUntil { !waiting.isEmpty }
        waiting.removeFirst().resume(returning: result)
    }
}

/// A pharmacy list loader that counts its loads. With `waitsForRelease`, a load waits until the
/// test calls `release()`.
@MainActor
final class FakePharmacyListLoader: PharmacyListLoader {
    let list: PharmacyList
    var waitsForRelease = false
    private(set) var loadCount = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(list: PharmacyList) {
        self.list = list
    }

    /// `@MainActor` explicitly: the protocol is `nonisolated`, and a method declared with the
    /// conformance would otherwise take that isolation instead of the class's. The requirement is
    /// `async`, so a main-actor method can still satisfy it: the call hops to the main actor.
    @MainActor
    func load() async -> PharmacyList {
        loadCount += 1
        if waitsForRelease { await withCheckedContinuation { waiting.append($0) } }
        return list
    }

    func release() async {
        await waitUntil { !waiting.isEmpty }
        waiting.removeFirst().resume()
    }
}

/// Lets other main-actor tasks run until `condition` holds, and fails the test if it never does.
@MainActor
func waitUntil(
    _ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation
) async {
    for _ in 0..<10_000 {
        if condition() { return }
        await Task.yield()
    }
    Issue.record("The condition never became true", sourceLocation: sourceLocation)
}
