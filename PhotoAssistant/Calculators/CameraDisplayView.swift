//
//  CameraDisplayView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/29/25.
//
//  This view displays the main exposure settings and handles the presentation
//  of the picker sheets for changing those settings. State is managed by the
//  parent view via Bindings.

import SwiftUI

// Assume these types are defined in other accessible files (Exposure directory)
// struct FStop: Identifiable, Equatable, Comparable { ... }
// struct ShutterSpeed: Identifiable, Equatable { ... }
// struct ISOSetting: Identifiable, Equatable { ... }
// struct FilmReciprocity: Identifiable, Equatable { ... }

// MARK: - Control State Definitions
struct PickerControl {
    let enabled: Bool
    let disabledTextLabel: String
    let disabledColor: Color
}

// Holds the complete control state configuration for all pickers in CameraDisplayView.
struct CameraDisplayControlState {
    let aperturePicker: PickerControl
    let shutterPicker: PickerControl
    let ISOPicker: PickerControl
    let EVPicker: PickerControl
    let EVValuePicker: PickerControl
    let displayCameraSettings: Bool
    // Add other controls here (e.g., filmPicker, cameraPicker) as needed
    
    // Static helper for a fully enabled state, useful for default initializers
    static var fullyEnabled: CameraDisplayControlState {
        CameraDisplayControlState(
            aperturePicker: PickerControl(enabled: true, disabledTextLabel: "f/--", disabledColor: Color(.systemGray)),
            shutterPicker: PickerControl(enabled: true, disabledTextLabel: "--", disabledColor: Color(.systemGray)),
            ISOPicker: PickerControl(enabled: true, disabledTextLabel: "---", disabledColor: Color(.systemGray)),
            EVPicker: PickerControl(enabled: true, disabledTextLabel: "0.0", disabledColor: Color(.systemGray)),
            EVValuePicker: PickerControl(enabled: true, disabledTextLabel: "-.-", disabledColor: Color(.systemGray)),
            displayCameraSettings: true
        )
    }
}

struct CameraDisplayView: View {
    // MARK: - External Bindings (State Lifted Up)
    @Binding var selectedAperture: FStop
    @Binding var selectedShutterSpeed: ShutterSpeed
    @Binding var selectedISO: ISOSetting
    @Binding var selectedFilm: FilmReciprocity?
    @Binding var selectedCamera: MyGearModel?
    @Binding var evCompensation: Double

    // MARK: - Configuration Flags
    let allowFilmSelection: Bool
    let allowCameraSelection: Bool
    
    // MARK: - New Control State Configuration (Added here)
    let controlState: CameraDisplayControlState

    // MARK: - External Data and Computed Values
    let exposureValue: Double
    let fStops: [FStop]
    let shutterSpeeds: [ShutterSpeed]
    let isos: [ISOSetting]
    let films: [FilmReciprocity]
    let cameras: [MyGearModel]

    // MARK: - Internal State for Picker Presentation
    @State private var showingCameraPicker = false
    @State private var showingFilmPicker = false
    @State private var showingAperturePicker = false
    @State private var showingShutterPicker = false
    @State private var showingISOPicker = false
    @State private var showEVPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Film/Sensor name with camera icon
            HStack(spacing: 12) {
                // Camera icon - tappable to change camera (only if allowed)
                if allowCameraSelection {
                    Button(action: { showingCameraPicker = true }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                }

                Spacer(minLength: 8)

                // Film/Sensor name - right aligned with better shrinking (only if allowed)
                if allowFilmSelection {
                    Button(action: { showingFilmPicker = true }) {
                        Text(selectedFilm?.name ?? "Digital")
                            .font(.custom("American Typewriter", size: 38))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else if allowCameraSelection {
                    // Make it clickable for camera selection
                    Button(action: { showingCameraPicker = true }) {
                        Text(displaySensorName)
                            .font(.custom("American Typewriter", size: 38))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    Text(displaySensorName)
                        .font(.custom("American Typewriter", size: 38))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if controlState.displayCameraSettings == true {
                // Horizontal line
                Rectangle()
                    .fill(.black)
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // F-Stop and Shutter Speed
                HStack(alignment: .center, spacing: 20) {
                    apertureControl
                    Spacer()
                    shutterSpeedControl
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 0)
                
                HStack {
                    Spacer()
                    isoControl
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 0)
                
                // EV and compensation
                HStack {
                    if controlState.EVValuePicker.enabled {
                        Text(String(format: "EV %.1f", exposureValue))
                            .font(.custom("American Typewriter", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    } else {
                        Text("EV \(controlState.EVValuePicker.disabledTextLabel)")
                            .font(.custom("American Typewriter", size: 18))
                            .fontWeight(.semibold)
                            .foregroundColor(controlState.EVValuePicker.disabledColor)
                    }
                    
                    
                    Spacer()
                    
                    evCompensationControl
                    /*
                     Button(action: { showEVPicker = true }) {
                     HStack(spacing: 4) {
                     evCompensationControl
                     PlusMinusDiagonalIcon(size: 18, backgroundColor: .black, textColor: .white)
                     }
                     }
                     */
                        .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Bottom horizontal line
                Rectangle()
                    .fill(.black)
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            } else {
                // Horizontal line
                Rectangle()
                    .fill(.black)
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
            
            // Instructional text
            Text("Tap any setting to adjust")
                .font(.system(size: 12))
                .foregroundColor(.black.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)
        }
        .background(Color(hex: "b8b8b8"))
        .cornerRadius(8)
        
        // MARK: - Picker Sheets
        .sheet(isPresented: $showingCameraPicker) {
            cameraPickerSheet
        }
        .sheet(isPresented: $showingFilmPicker) {
            filmPickerSheet
        }
        .sheet(isPresented: $showingAperturePicker) {
            aperturePickerSheet
        }
        .sheet(isPresented: $showingShutterPicker) {
            shutterPickerSheet
        }
        .sheet(isPresented: $showingISOPicker) {
            isoPickerSheet
        }
        .sheet(isPresented: $showEVPicker) {
            evPickerSheet
        }
    }
    
    // MARK: - Implementation of Controls using controlState
    
    @ViewBuilder
    private var shutterSpeedControl: some View {
        VStack {
            if controlState.shutterPicker.enabled {
                Button(action: { showingShutterPicker = true }) {
                    Text(selectedShutterSpeed.label)
                        .font(.custom("American Typewriter", size: 38))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
            } else {
                Text(controlState.shutterPicker.disabledTextLabel)
                    .font(.custom("American Typewriter", size: 38))
                    .fontWeight(.semibold)
                    .foregroundColor(controlState.shutterPicker.disabledColor)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var apertureControl: some View {
        VStack {
            if controlState.aperturePicker.enabled {
                Button(action: { showingAperturePicker = true }) {
                    Text(selectedAperture.label)
                        .font(.custom("American Typewriter", size: 38))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
            } else {
                Text(controlState.aperturePicker.disabledTextLabel)
                    .font(.custom("American Typewriter", size: 38))
                    .fontWeight(.semibold)
                    .foregroundColor(controlState.aperturePicker.disabledColor)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var isoControl: some View {
        // Check 1: Is the control enabled AND are we in "Digital" mode? (Tappable)
        if controlState.ISOPicker.enabled && selectedFilm == nil {
            Button(action: { showingISOPicker = true }) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("ISO ")
                        .font(.custom("American Typewriter", size: 24))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Text(selectedISO.label)
                        .font(.custom("American Typewriter", size: 38))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .lineLimit(1)
                }
            }
        }
        // Check 2: Control is enabled, but a film is selected (Passive Text)
        else if controlState.ISOPicker.enabled && selectedFilm != nil {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("ISO ")
                    .font(.custom("American Typewriter", size: 24))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Text(selectedISO.label)
                    .font(.custom("American Typewriter", size: 38))
                    .fontWeight(.semibold)
                    .foregroundColor(controlState.ISOPicker.disabledColor) // Muted color to show it's non-interactive
                    .lineLimit(1)
            }
        }
        // Check 3: Control is globally disabled (Disabled Text Label)
        else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("ISO ")
                    .font(.custom("American Typewriter", size: 24))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Text(controlState.ISOPicker.disabledTextLabel)
                    .font(.custom("American Typewriter", size: 38))
                    .fontWeight(.semibold)
                    .foregroundColor(controlState.ISOPicker.disabledColor)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    private var evCompensationControl: some View {
        if controlState.EVPicker.enabled {
            Button(action: { showEVPicker = true }) {
                Text(String(format: "%.1f", evCompensation))
                    .font(.custom("American Typewriter", size: 18))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                PlusMinusDiagonalIcon(size: 18, backgroundColor: .black, textColor: .white)
            }
        } else {
            Text(controlState.EVPicker.disabledTextLabel)
                .font(.custom("American Typewriter", size: 18))
                .fontWeight(.semibold)
                .foregroundColor(controlState.EVPicker.disabledColor)
            PlusMinusDiagonalIcon(size: 18, backgroundColor: .black, textColor: .white)
        }
    }

    // MARK: - Sub-View Components

    private var displaySensorName: String {
        if let camera = selectedCamera {
            return camera.cameraName
        } else if let film = selectedFilm {
            return film.name
        } else {
            return "Full Frame"
        }
    }

    // MARK: - Picker Sheets (Moved from Parent)

    private var cameraPickerSheet: some View {
        NavigationView {
            Group {
                if cameras.isEmpty {
                    // Show message when no cameras exist
                    VStack(spacing: 20) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Cameras Available")
                            .font(.headline)
                        Text("Use \"Manage My Gear\" to add cameras and lenses.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // List all saved cameras
                    List {
                        ForEach(cameras) { camera in
                            Button(action: {
                                selectedCamera = camera
                                showingCameraPicker = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(camera.cameraName)
                                            .font(.headline)
                                        Text(camera.capturePlane)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text(String(format: "%.1f × %.1f mm", camera.capturePlaneWidth, camera.capturePlaneHeight))
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if selectedCamera?.id == camera.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Camera/Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingCameraPicker = false
                    }
                }
            }
        }
    }

    private var filmPickerSheet: some View {
        NavigationView {
            List {
                Button(action: {
                    selectedFilm = nil
                    showingFilmPicker = false
                }) {
                    HStack {
                        Text("Digital")
                        Spacer()
                        if selectedFilm == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }

                ForEach(films) { film in
                    Button(action: {
                        selectedFilm = film
                        // NOTE: ISO update logic (if needed) must be handled by the parent's .onChange(of: selectedFilm)
                        showingFilmPicker = false
                    }) {
                        HStack {
                            Text(film.name)
                            Spacer()
                            if selectedFilm?.id == film.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sensor/Film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilmPicker = false
                    }
                }
            }
        }
    }

    private var aperturePickerSheet: some View {
        NavigationView {
            List {
                ForEach(fStops) { fStop in
                    Button(action: {
                        selectedAperture = fStop
                        showingAperturePicker = false
                    }) {
                        HStack {
                            Text(fStop.label)
                            Spacer()
                            if selectedAperture.value == fStop.value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Aperture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingAperturePicker = false
                    }
                }
            }
        }
    }

    private var shutterPickerSheet: some View {
        NavigationView {
            List {
                ForEach(shutterSpeeds) { speed in
                    Button(action: {
                        selectedShutterSpeed = speed
                        showingShutterPicker = false
                    }) {
                        HStack {
                            Text(speed.label)
                            Spacer()
                            if selectedShutterSpeed.seconds == speed.seconds {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shutter Speed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingShutterPicker = false
                    }
                }
            }
        }
    }

    private var isoPickerSheet: some View {
        NavigationView {
            List {
                ForEach(isos) { iso in
                    Button(action: {
                        selectedISO = iso
                        showingISOPicker = false
                    }) {
                        HStack {
                            Text(iso.label)
                            Spacer()
                            if selectedISO.value == iso.value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ISO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingISOPicker = false
                    }
                }
            }
        }
    }

    private var evPickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("EV Compensation")
                    .font(.headline)
                    .padding(.top)

                Text(String(format: "%+.1f", evCompensation))
                    .font(.system(size: 60, weight: .bold))
                    .monospacedDigit()

                Picker("EV", selection: $evCompensation) {
                    // Generates 1/3 stop increments from -10.0 to +10.0
                    ForEach(Array(stride(from: -10.0, through: 10.0, by: 1.0/3.0)), id: \.self) { ev in
                        let rounded = (ev * 10).rounded() / 10.0
                        Text(String(format: "%+.1f", rounded))
                            .tag(rounded)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showEVPicker = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        evCompensation = 0.0
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Supporting Views (Copied from original file structure)

// Assuming this extension was defined in the original file
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

