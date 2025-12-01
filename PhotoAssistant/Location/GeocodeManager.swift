//
//  GeocodeManager.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 10/18/25.
//

import Foundation
import CoreLocation
import Contacts
import Observation
import ImageIO

struct PlacemarkInfo {
    let location: CLLocation?
    let name: String?
    let thoroughfare: String?
    let subThoroughfare: String?
    let locality: String?
    let subLocality: String?
    let administrativeArea: String?
    let subAdministrativeArea: String?
    let postalCode: String?
    let country: String?
    let isoCountryCode: String?
    let timeZone: TimeZone?
    let areasOfInterest: [String]?
    let inlandWater: String?
    let ocean: String?
    let postalAddress: CNPostalAddress?
    let addressRepresentations: [String]?
    
    // Full initializer
    init(location: CLLocation?, name: String?, thoroughfare: String?, subThoroughfare: String?, locality: String?, subLocality: String?, administrativeArea: String?, subAdministrativeArea: String?, postalCode: String?, country: String?, isoCountryCode: String?, timeZone: TimeZone?, areasOfInterest: [String]?, inlandWater: String?, ocean: String?, postalAddress: CNPostalAddress?, addressRepresentations: [String]?) {
        self.location = location
        self.name = name
        self.thoroughfare = thoroughfare
        self.subThoroughfare = subThoroughfare
        self.locality = locality
        self.subLocality = subLocality
        self.administrativeArea = administrativeArea
        self.subAdministrativeArea = subAdministrativeArea
        self.postalCode = postalCode
        self.country = country
        self.isoCountryCode = isoCountryCode
        self.timeZone = timeZone
        self.areasOfInterest = areasOfInterest
        self.inlandWater = inlandWater
        self.ocean = ocean
        self.postalAddress = postalAddress
        self.addressRepresentations = addressRepresentations
    }
    
    // Convenience initializer from CLPlacemark
    init(from placemark: CLPlacemark) {
        self.location = placemark.location
        self.name = placemark.name
        self.thoroughfare = placemark.thoroughfare
        self.subThoroughfare = placemark.subThoroughfare
        self.locality = placemark.locality
        self.subLocality = placemark.subLocality
        self.administrativeArea = placemark.administrativeArea
        self.subAdministrativeArea = placemark.subAdministrativeArea
        self.postalCode = placemark.postalCode
        self.country = placemark.country
        self.isoCountryCode = placemark.isoCountryCode
        self.timeZone = placemark.timeZone
        self.areasOfInterest = placemark.areasOfInterest
        self.inlandWater = placemark.inlandWater
        self.ocean = placemark.ocean
        self.postalAddress = placemark.postalAddress
        
        // Create address representations
        var representations: [String] = []
        
        // Full address
        if let postalAddress = placemark.postalAddress {
            let formatter = CNPostalAddressFormatter()
            representations.append(formatter.string(from: postalAddress))
        }
        
        // Compact address
        var compactComponents: [String] = []
        if let subThoroughfare = placemark.subThoroughfare { compactComponents.append(subThoroughfare) }
        if let thoroughfare = placemark.thoroughfare { compactComponents.append(thoroughfare) }
        if let locality = placemark.locality { compactComponents.append(locality) }
        if let administrativeArea = placemark.administrativeArea { compactComponents.append(administrativeArea) }
        if let postalCode = placemark.postalCode { compactComponents.append(postalCode) }
        
        if !compactComponents.isEmpty {
            representations.append(compactComponents.joined(separator: ", "))
        }
        
        self.addressRepresentations = representations.isEmpty ? nil : representations
    }
    
    // Formatted address string
    var formattedAddress: String? {
        addressRepresentations?.first
    }
    
    // Short address (street and city)
    var shortAddress: String? {
        var components: [String] = []
        
        if let subThoroughfare = subThoroughfare, let thoroughfare = thoroughfare {
            components.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = thoroughfare {
            components.append(thoroughfare)
        }
        
        if let locality = locality {
            components.append(locality)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    // City, State format
    var cityState: String? {
        var components: [String] = []
        if let locality = locality { components.append(locality) }
        if let administrativeArea = administrativeArea { components.append(administrativeArea) }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    // City, State, Zip - for US addresses
    var cityStateZip: String? {
        var components: [String] = []
        if let locality = locality { components.append(locality) }
        if let administrativeArea = administrativeArea { components.append(administrativeArea) }
        if let postalCode = postalCode { components.append(postalCode) }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    // International format: City, State/Region, Country
    var cityRegionCountry: String? {
        var components: [String] = []
        if let locality = locality { components.append(locality) }
        if let administrativeArea = administrativeArea { components.append(administrativeArea) }
        if let country = country { components.append(country) }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    // Full location: City, State/Region, Postal Code, Country
    var fullLocation: String? {
        var components: [String] = []
        if let locality = locality { components.append(locality) }
        if let administrativeArea = administrativeArea { components.append(administrativeArea) }
        if let postalCode = postalCode { components.append(postalCode) }
        if let country = country { components.append(country) }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

@Observable
class GeocodeManager {
    private let geocoder = CLGeocoder()
    
    var isGeocoding: Bool = false
    var lastError: Error?
    
    /// Extract location data from image EXIF data
    /// - Parameter imageData: The image data to extract GPS information from
    /// - Returns: CLLocation if GPS data exists, nil otherwise
    func extractLocationFromImageData(_ imageData: Data) -> CLLocation? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        // Extract GPS data
        guard let gpsData = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }
        
        // Get latitude
        guard let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
              let latitudeRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String else {
            return nil
        }
        
        // Get longitude
        guard let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double,
              let longitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            return nil
        }
        
        // Adjust for hemisphere
        let finalLatitude = latitudeRef == "S" ? -latitude : latitude
        let finalLongitude = longitudeRef == "W" ? -longitude : longitude
        
        // Get optional altitude
        var altitude: Double? = nil
        if let altitudeValue = gpsData[kCGImagePropertyGPSAltitude as String] as? Double,
           let altitudeRef = gpsData[kCGImagePropertyGPSAltitudeRef as String] as? Int {
            altitude = altitudeRef == 1 ? -altitudeValue : altitudeValue
        }
        
        // Get optional heading/direction
        var course: Double? = nil
        if let imgDirection = gpsData[kCGImagePropertyGPSImgDirection as String] as? Double {
            course = imgDirection
        } else if let trackDirection = gpsData[kCGImagePropertyGPSTrack as String] as? Double {
            course = trackDirection
        }
        
        // Get optional timestamp
        var timestamp: Date? = nil
        if let dateString = gpsData[kCGImagePropertyGPSDateStamp as String] as? String,
           let timeString = gpsData[kCGImagePropertyGPSTimeStamp as String] as? String {
            let dateTimeString = "\(dateString) \(timeString)"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            dateFormatter.timeZone = TimeZone(identifier: "UTC")
            timestamp = dateFormatter.date(from: dateTimeString)
        }
        
        // Get optional speed
        var speed: Double? = nil
        if let speedValue = gpsData[kCGImagePropertyGPSSpeed as String] as? Double {
            // Convert from km/h to m/s if needed
            if let speedRef = gpsData[kCGImagePropertyGPSSpeedRef as String] as? String {
                speed = speedRef == "K" ? speedValue / 3.6 : speedValue
            }
        }
        
        // Create CLLocation with all available data
        let coordinate = CLLocationCoordinate2D(latitude: finalLatitude, longitude: finalLongitude)
        
        if let altitude = altitude, let timestamp = timestamp {
            return CLLocation(
                coordinate: coordinate,
                altitude: altitude,
                horizontalAccuracy: 0,
                verticalAccuracy: 0,
                course: course ?? -1,
                speed: speed ?? -1,
                timestamp: timestamp
            )
        } else {
            return CLLocation(latitude: finalLatitude, longitude: finalLongitude)
        }
    }
    
    /// Process image data: extract location and reverse geocode
    /// - Parameter imageData: The image data to process
    /// - Returns: Tuple of (location, placemarkInfo) if successful
    func processImageLocation(_ imageData: Data) async -> (location: CLLocation?, placemark: PlacemarkInfo?) {
        guard let location = extractLocationFromImageData(imageData) else {
            return (nil, nil)
        }
        
        let placemark = await reverseGeocode(location: location)
        return (location, placemark)
    }
    
    /// Reverse geocode a location to get placemark information
    /// - Parameter location: The CLLocation to reverse geocode
    /// - Returns: PlacemarkInfo if successful, nil if failed
    func reverseGeocode(location: CLLocation) async -> PlacemarkInfo? {
        isGeocoding = true
        lastError = nil
        
        defer {
            isGeocoding = false
        }
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                return nil
            }
            
            return PlacemarkInfo(from: placemark)
            
        } catch {
            lastError = error
            print("Reverse geocoding failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Reverse geocode coordinates to get placemark information
    /// - Parameters:
    ///   - latitude: Latitude coordinate
    ///   - longitude: Longitude coordinate
    /// - Returns: PlacemarkInfo if successful, nil if failed
    func reverseGeocode(latitude: Double, longitude: Double) async -> PlacemarkInfo? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return await reverseGeocode(location: location)
    }
    
    /// Forward geocode an address string to get location information
    /// - Parameter addressString: The address to geocode
    /// - Returns: Array of PlacemarkInfo objects for potential matches
    func geocode(addressString: String) async -> [PlacemarkInfo] {
        isGeocoding = true
        lastError = nil
        
        defer {
            isGeocoding = false
        }
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(addressString)
            return placemarks.compactMap { PlacemarkInfo(from: $0) }
            
        } catch {
            lastError = error
            print("Geocoding failed: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Cancel any ongoing geocoding operations
    func cancelGeocoding() {
        geocoder.cancelGeocode()
        isGeocoding = false
    }
}

// MARK: - Convenience Extensions
extension PlacemarkInfo: CustomStringConvertible {
    var description: String {
        return formattedAddress ?? "Unknown Location"
    }
}

extension PlacemarkInfo: Identifiable {
    var id: String {
        return "\(location?.coordinate.latitude ?? 0),\(location?.coordinate.longitude ?? 0)"
    }
}

