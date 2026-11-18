#if DEBUG
    import Foundation

    /// A location provider with a fixed answer, so UI tests get a known location without the
    /// system's permission prompt. Debug builds only: a release build always uses the real
    /// location.
    ///
    /// UI tests choose it with the launch argument `-fixedLocation <value>`, where the value is
    /// `<latitude>,<longitude>`, `<latitude>,<longitude>,approximate`, `denied` or `unavailable`.
    struct FixedLocationProvider: LocationProvider {
        /// The launch argument, read through `UserDefaults`, which turns `-key value` arguments
        /// into settings.
        static let argumentKey = "fixedLocation"

        let answer: Result<LocationFix, LocationError>

        /// The provider the launch arguments ask for, or nil if they don't ask for one.
        static func fromLaunchArguments() -> FixedLocationProvider? {
            UserDefaults.standard.string(forKey: argumentKey).flatMap(FixedLocationProvider.init)
        }

        init?(argument: String) {
            switch argument {
            case "denied":
                answer = .failure(.denied)
            case "unavailable":
                answer = .failure(.unavailable)
            default:
                let parts = argument.split(separator: ",")
                guard parts.count == 2 || (parts.count == 3 && parts[2] == "approximate"),
                    let latitude = Double(parts[0]), let longitude = Double(parts[1])
                else { return nil }
                answer = .success(
                    LocationFix(
                        coordinate: Coordinate(latitude: latitude, longitude: longitude),
                        isApproximate: parts.count == 3))
            }
        }

        func currentLocation() async throws(LocationError) -> LocationFix {
            try answer.get()
        }

        /// The user declines, so an approximate location stays approximate.
        func requestPreciseLocation() async -> Bool { false }
    }
#endif
