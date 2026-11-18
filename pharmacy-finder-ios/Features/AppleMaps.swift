import Contacts
import MapKit

/// Opens a pharmacy in Apple Maps (ADR 0102). Maps gets our name, address and coordinates, so the
/// pin is where our list says even when Maps finds no place card for it. Nothing about the user is
/// passed, and nothing is sent until the user taps.
enum AppleMaps {
    static func open(_ pharmacy: Pharmacy) {
        _ = mapItem(for: pharmacy).openInMaps()
    }

    private static func mapItem(for pharmacy: Pharmacy) -> MKMapItem {
        let location = CLLocation(
            latitude: pharmacy.coordinate.latitude, longitude: pharmacy.coordinate.longitude)
        let item: MKMapItem
        if #available(iOS 26, *) {
            item = MKMapItem(
                location: location,
                address: MKAddress(
                    fullAddress: pharmacy.postalAddress, shortAddress: pharmacy.address))
        } else {
            // `MKPlacemark` is deprecated from iOS 26, and the only way to give an address before it.
            let address = CNMutablePostalAddress()
            address.street = pharmacy.address
            address.postalCode = pharmacy.postcode
            address.city = pharmacy.city
            address.isoCountryCode = "FI"
            item = MKMapItem(
                placemark: MKPlacemark(coordinate: location.coordinate, postalAddress: address))
        }
        item.name = pharmacy.name
        return item
    }
}
