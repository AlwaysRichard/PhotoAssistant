//
//  PhotoAssistantApp.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 10/13/25.
//

import SwiftUI
import SwiftData

@main
struct PhotoAssistantApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            PhotoAssistant.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// Add this extension to handle app lifecycle and permissions
extension PhotoAssistantApp {
    static func configurePrivacyUsageDescriptions() {
        // Note: For Xcode projects, privacy usage descriptions should be added
        // through the project's Info.plist settings in Xcode's target settings.
        // The following are the required permissions for this app:
        //
        // NSCameraUsageDescription: "PhotoAssistant needs access to the camera to take photos with location and orientation data."
        // NSLocationWhenInUseUsageDescription: "PhotoAssistant needs location access to add GPS coordinates, altitude, and heading information to your photos."
        // NSPhotoLibraryAddUsageDescription: "PhotoAssistant needs access to save photos with enhanced location and orientation data to your photo library."
        // NSMotionUsageDescription: "PhotoAssistant needs motion sensor access to determine camera tilt angle for enhanced photo metadata."
    }
}

