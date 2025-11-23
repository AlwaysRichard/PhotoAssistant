//
//  PhotoAssistant.swift
//  PhotoAssistant
//
//  Created by Assistant on 11/19/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class PhotoAssistant {
    var id: UUID
    var imageData: Data
    var timestamp: Date
    
    // Location data stored as separate properties for SwiftData compatibility
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var course: Double?
    var speed: Double?
    var locationTimestamp: Date?
    var horizontalAccuracy: Double?
    var verticalAccuracy: Double?
    
    // Placemark info stored as separate properties
    var locationName: String?
    var thoroughfare: String?
    var subThoroughfare: String?
    var locality: String?
    var subLocality: String?
    var administrativeArea: String?
    var subAdministrativeArea: String?
    var postalCode: String?
    var country: String?
    var isoCountryCode: String?
    var formattedAddress: String?
    
    init(imageData: Data) {
        self.id = UUID()
        self.imageData = imageData
        self.timestamp = Date()
    }
    
    // Computed property to recreate CLLocation from stored components
    var location: CLLocation? {
        get {
            guard let latitude = latitude, let longitude = longitude else { return nil }
            
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            if let altitude = altitude, let locationTimestamp = locationTimestamp {
                return CLLocation(
                    coordinate: coordinate,
                    altitude: altitude,
                    horizontalAccuracy: horizontalAccuracy ?? 0,
                    verticalAccuracy: verticalAccuracy ?? 0,
                    course: course ?? -1,
                    speed: speed ?? -1,
                    timestamp: locationTimestamp
                )
            } else {
                return CLLocation(latitude: latitude, longitude: longitude)
            }
        }
        set {
            if let location = newValue {
                self.latitude = location.coordinate.latitude
                self.longitude = location.coordinate.longitude
                self.altitude = location.altitude
                self.course = location.course >= 0 ? location.course : nil
                self.speed = location.speed >= 0 ? location.speed : nil
                self.locationTimestamp = location.timestamp
                self.horizontalAccuracy = location.horizontalAccuracy
                self.verticalAccuracy = location.verticalAccuracy
            } else {
                self.latitude = nil
                self.longitude = nil
                self.altitude = nil
                self.course = nil
                self.speed = nil
                self.locationTimestamp = nil
                self.horizontalAccuracy = nil
                self.verticalAccuracy = nil
            }
        }
    }
    
    // Computed property to recreate PlacemarkInfo from stored components
    var placemarkInfo: PlacemarkInfo? {
        get {
            guard let location = location else { return nil }
            
            // Create a mock placemark-like structure with our stored data
            return PlacemarkInfo(
                location: location,
                name: locationName,
                thoroughfare: thoroughfare,
                subThoroughfare: subThoroughfare,
                locality: locality,
                subLocality: subLocality,
                administrativeArea: administrativeArea,
                subAdministrativeArea: subAdministrativeArea,
                postalCode: postalCode,
                country: country,
                isoCountryCode: isoCountryCode,
                timeZone: nil,
                areasOfInterest: nil,
                inlandWater: nil,
                ocean: nil,
                postalAddress: nil,
                addressRepresentations: formattedAddress != nil ? [formattedAddress!] : nil
            )
        }
        set {
            if let placemark = newValue {
                self.locationName = placemark.name
                self.thoroughfare = placemark.thoroughfare
                self.subThoroughfare = placemark.subThoroughfare
                self.locality = placemark.locality
                self.subLocality = placemark.subLocality
                self.administrativeArea = placemark.administrativeArea
                self.subAdministrativeArea = placemark.subAdministrativeArea
                self.postalCode = placemark.postalCode
                self.country = placemark.country
                self.isoCountryCode = placemark.isoCountryCode
                self.formattedAddress = placemark.formattedAddress
            } else {
                self.locationName = nil
                self.thoroughfare = nil
                self.subThoroughfare = nil
                self.locality = nil
                self.subLocality = nil
                self.administrativeArea = nil
                self.subAdministrativeArea = nil
                self.postalCode = nil
                self.country = nil
                self.isoCountryCode = nil
                self.formattedAddress = nil
            }
        }
    }
}
