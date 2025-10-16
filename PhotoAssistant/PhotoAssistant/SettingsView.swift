//
//  SettingsView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 10/15/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var locationEnabled = true
    @State private var saveToPhotos = true
    @State private var includeMetadata = true
    @State private var flashMode = "Auto"
    @State private var photoQuality = "High"
    
    let flashModes = ["Auto", "On", "Off"]
    let qualityOptions = ["High", "Medium", "Low"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Camera Settings") {
                    Picker("Flash Mode", selection: $flashMode) {
                        ForEach(flashModes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                    
                    Picker("Photo Quality", selection: $photoQuality) {
                        ForEach(qualityOptions, id: \.self) { quality in
                            Text(quality).tag(quality)
                        }
                    }
                }
                
                Section("Location & Privacy") {
                    Toggle("Enable Location Services", isOn: $locationEnabled)
                    Toggle("Include Metadata in Photos", isOn: $includeMetadata)
                }
                
                Section("Photo Management") {
                    Toggle("Save to Photo Library", isOn: $saveToPhotos)
                    
                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text("2.3 GB")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Clear Cache") {
                        // Clear cache action
                    }
                    .foregroundColor(.red)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        // Open privacy policy
                    }
                    
                    Button("Terms of Service") {
                        // Open terms of service
                    }
                }
                
                Section {
                    Button("Reset All Settings") {
                        // Reset settings action
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}