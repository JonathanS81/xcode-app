import Foundation
import CoreLocation

/// Placeholder for future geolocation logic.
struct LocationHelper {
    static func currentCountryCode() -> String? {
        return Locale.current.region?.identifier
    }
}
