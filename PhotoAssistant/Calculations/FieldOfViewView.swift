//
//  FieldOfViewView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/30/25.
//

import SwiftUI

// MARK: - Depth of Field View

struct FieldOfViewView: View {
    // MARK: - Base Settings
    @State private var selectedAperture: FStop
    @State private var selectedShutterSpeed: ShutterSpeed
    @State private var selectedISO: ISOSetting
    @State private var selectedCamera: MyGearModel?
    @State private var selectedLens: Lens?
    @State private var selectedZoom: Int = 50 // For zoom lenses
    
    // MARK: - Focus Distance
    @State private var focusDistanceFeet: Int = 10
    @State private var focusDistanceInches: Int = 0
    @State private var isInfinity: Bool = false
    
    // MARK: - Sheet Presentation
    @State private var showLensPicker = false
    @State private var showDistancePicker = false
    
    // MARK: - Results Page State
    @State private var currentResultPage = 0
    
    // MARK: - EV Compensation (not used for DoF but required by CameraDisplayView)
    @State private var evCompensation: Double = 0.0
    
    // MARK: - Data
    private let fStops = FStop.scale(stepMode: .third)
    private let shutterSpeeds = ShutterSpeed.scale(stepMode: .third)
    private let isos = ISOSetting.thirdStopScale
    private let cameras: [MyGearModel]
    private let capturePlanes: [CapturePlane]
    private let defaultFullFrame: CapturePlane?
    
    // MARK: - Computed EV (required by CameraDisplayView)
    private var exposureValue: Double {
        selectedAperture.evOffset + selectedShutterSpeed.evOffset + selectedISO.evOffset
    }
    
    // MARK: - Computed FoV Values
    private var fovCalculations: FoVResult {
        calculateFieldOfView()
    }
    
    // MARK: - UserDefaults Keys (using centralized keys)
    // Note: FoV-specific keys like aperture and focus distance use their own keys
    private let kSelectedAperture = MyGearSelectionKeys.fovAperture
    private let kFocusDistanceFeet = MyGearSelectionKeys.fovFeet
    private let kFocusDistanceInches = MyGearSelectionKeys.fovInches
    private let kIsInfinity = MyGearSelectionKeys.fovInfinity
    
    // MARK - Define Custom Control State for CameraDisplayView
    let customControlState = CameraDisplayControlState(
        aperturePicker: PickerControl(
            enabled: false,
            disabledTextLabel: "f/--",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        shutterPicker: PickerControl(
            enabled: false,
            disabledTextLabel: "---",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        ISOPicker: PickerControl(
            enabled: false,
            disabledTextLabel: "---",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        EVPicker: PickerControl(
            enabled: false,
            disabledTextLabel: "-.-",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        EVValuePicker: PickerControl(
            enabled: false,
            disabledTextLabel: "-.-",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        )
    )
    
    init() {
        // Initialize all non-optional State variables first with defaults
        let fStops = FStop.scale(stepMode: .third)
        let shutterSpeeds = ShutterSpeed.scale(stepMode: .third)
        let isos = ISOSetting.thirdStopScale
        
        // Load saved values from UserDefaults or use defaults
        let savedAperture = UserDefaults.standard.double(forKey: kSelectedAperture)
        let savedFeet = UserDefaults.standard.integer(forKey: kFocusDistanceFeet)
        let savedInches = UserDefaults.standard.integer(forKey: kFocusDistanceInches)
        let savedZoom = UserDefaults.standard.integer(forKey: MyGearSelectionKeys.selectedZoom)
        let savedInfinity = UserDefaults.standard.bool(forKey: kIsInfinity)
        
        // Initialize aperture
        if savedAperture > 0, let aperture = fStops.first(where: { abs($0.value - savedAperture) < 0.1 }) {
            _selectedAperture = State(initialValue: aperture)
        } else {
            _selectedAperture = State(initialValue: fStops.first(where: { abs($0.value - 5.6) < 0.1 }) ?? fStops[0])
        }
        
        // Initialize shutter speed (default value, not saved for DoF)
        _selectedShutterSpeed = State(initialValue: shutterSpeeds.first(where: { abs($0.seconds - 1.0/125.0) < 0.0001 }) ?? shutterSpeeds[0])
        
        // Initialize ISO (default value, not saved for DoF)
        _selectedISO = State(initialValue: isos.first(where: { $0.value == 100 }) ?? isos[0])
        
        // Initialize focus distance
        _focusDistanceFeet = State(initialValue: savedFeet > 0 ? savedFeet : 10)
        _focusDistanceInches = State(initialValue: savedInches)
        _isInfinity = State(initialValue: savedInfinity)
        
        // Initialize zoom
        _selectedZoom = State(initialValue: savedZoom > 0 ? savedZoom : 50)
        
        // Load cameras from MyGearModel
        let loadedCameras = MyGearModel.loadGearList()
        
        // If no cameras exist, create a default Full Frame camera
        if loadedCameras.isEmpty {
            // Create default 50mm lens
            let defaultLens = Lens(
                name: "50mm f/1.8",
                type: .prime,
                primeFocalLength: 50,
                zoomRange: nil
            )
            
            // Create default Full Frame camera
            let defaultCamera = MyGearModel(
                cameraName: "Full Frame (Default)",
                capturePlane: "Full Frame",
                capturePlaneWidth: 36.0,
                capturePlaneHeight: 24.0,
                capturePlaneDiagonal: 43.27,
                lenses: [defaultLens]
            )
            
            self.cameras = [defaultCamera]
            _selectedCamera = State(initialValue: defaultCamera)
            _selectedLens = State(initialValue: defaultLens)
        } else {
            self.cameras = loadedCameras
            
            // Try to load saved camera by name
            if let savedCameraName = UserDefaults.standard.string(forKey: MyGearSelectionKeys.selectedGearName),
               let savedCamera = loadedCameras.first(where: { $0.cameraName == savedCameraName }) {
                _selectedCamera = State(initialValue: savedCamera)
                
                // Load saved lens by name for this camera
                if let savedLensName = UserDefaults.standard.string(forKey: MyGearSelectionKeys.selectedLensName),
                   let savedLens = savedCamera.lenses.first(where: { $0.name == savedLensName }) {
                    _selectedLens = State(initialValue: savedLens)
                } else if let firstLens = savedCamera.lenses.first {
                    // If no saved lens, use first lens of saved camera
                    _selectedLens = State(initialValue: firstLens)
                }
            } else {
                // No saved camera, use first camera in list
                let firstCamera = loadedCameras[0]
                _selectedCamera = State(initialValue: firstCamera)
                
                // Use first lens of first camera
                if let firstLens = firstCamera.lenses.first {
                    _selectedLens = State(initialValue: firstLens)
                }
            }
        }
        
        // Load capture planes from JSON
        if let planeURL = Bundle.main.url(forResource: "CapturePlane", withExtension: "json"),
           let planeData = try? Data(contentsOf: planeURL) {
            let decoder = JSONDecoder()
            if let loadedPlanes = try? decoder.decode([CapturePlane].self, from: planeData) {
                self.capturePlanes = loadedPlanes
                self.defaultFullFrame = loadedPlanes.first { $0.name == "Full Frame" }
            } else {
                self.capturePlanes = []
                self.defaultFullFrame = nil
            }
        } else {
            self.capturePlanes = []
            self.defaultFullFrame = nil
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Camera Display View
            CameraDisplayView(
                selectedAperture: $selectedAperture,
                selectedShutterSpeed: $selectedShutterSpeed,
                selectedISO: $selectedISO,
                selectedFilm: .constant(nil),
                selectedCamera: $selectedCamera,
                evCompensation: $evCompensation,
                allowFilmSelection: false,
                allowCameraSelection: true,
                controlState: customControlState,
                exposureValue: exposureValue,
                fStops: fStops,
                shutterSpeeds: shutterSpeeds,
                isos: isos,
                films: [],
                cameras: cameras
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // MARK: - Lens Button
            lensButtonSection
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            // MARK: - Focus Distance Button
            focusDistanceButtonSection
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            Spacer()
            
            // MARK: - Results Section
            resultSection
        }
        .navigationTitle("FoV - Field Of View")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedCamera) { oldValue, newValue in
            saveCamera(newValue)
            // Reset lens when camera changes
            //selectedLens = nil
            if let camera = newValue, let firstLens = camera.lenses.first {
                selectedLens = firstLens
            } else {
                selectedLens = nil
            }
        }
        .onChange(of: selectedLens) { oldValue, newValue in
            saveLens(newValue)
            // Set default zoom if zoom lens
            if let lens = newValue, lens.type == .zoom, let range = lens.zoomRange {
                selectedZoom = (range.min + range.max) / 2
            }
        }
        .onChange(of: selectedZoom) { oldValue, newValue in
            saveZoom(newValue)
        }
        .onChange(of: selectedAperture) { oldValue, newValue in
            saveAperture(newValue)
        }
        .onChange(of: focusDistanceFeet) { oldValue, newValue in
            saveFocusDistance()
        }
        .onChange(of: focusDistanceInches) { oldValue, newValue in
            saveFocusDistance()
        }
        .onChange(of: isInfinity) { oldValue, newValue in
            saveIsInfinity(newValue)
        }
        .sheet(isPresented: $showLensPicker) {
            lensPickerSheet
        }
        .sheet(isPresented: $showDistancePicker) {
            distancePickerSheet
        }
    }
    
    // MARK: - Lens Button Section
    
    private var lensButtonSection: some View {
        Button(action: { showLensPicker = true }) {
            HStack(spacing: 12) {
                // Lens icon
                Image("CameraLensIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.primary)
                
                // "Lens" label
                Text("Lens")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Zoom slider for zoom lenses (in the middle)
                if let lens = selectedLens, lens.type == .zoom, let range = lens.zoomRange {
                    Slider(
                        value: Binding(
                            get: { Double(selectedZoom) },
                            set: { selectedZoom = Int($0) }
                        ),
                        in: Double(range.min)...Double(range.max),
                        step: 1
                    )
                    .frame(maxWidth: .infinity)
                    .accentColor(.blue)
                } else {
                    Spacer()
                }
                
                // Focal length display on the right
                if let lens = selectedLens {
                    Text(lensDisplayText(lens))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func lensDisplayText(_ lens: Lens) -> String {
        switch lens.type {
        case .prime:
            return "\(lens.primeFocalLength ?? 50)mm"
        case .zoom:
            return "\(selectedZoom)mm"
        }
    }
    
    // MARK: - Focus Distance Button Section
    
    private var focusDistanceButtonSection: some View {
        Button(action: { showDistancePicker = true }) {
            HStack {
                Image(systemName: "ruler")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                
                Text("Focus Distance:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(focusDistanceDisplay)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var focusDistanceDisplay: String {
        if isInfinity {
            return "∞"
        } else {
            return String(format: "%d'%d\"", focusDistanceFeet, focusDistanceInches)
        }
    }
    
    // MARK: - Result Section
    
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title Header
            HStack {
                Image(systemName: "scope")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                Spacer()
                Text("Measurements")
                    .font(.custom("American Typewriter", size: 20))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
            
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(height: 1)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            
            // Paged Content
            TabView(selection: $currentResultPage) {
                // Page 1: Calculated Results
                VStack(spacing: 2) {
                    ResultRow(label: "Camera Settings", value: "\(fovCalculations.focalLengthDisplay), \(fovCalculations.apertureDisplay), \(fovCalculations.focusDistanceDisplay)")
                    
                    ResultRow(label: "Horizontal Angle", value: fovCalculations.horizontalAngleDisplay)
                    ResultRow(label: "Vertical Angle", value: fovCalculations.verticalAngleDisplay)
                    ResultRow(label: "Diagonal Angle", value: fovCalculations.diagonalAngleDisplay)
                    
                    ResultRow(label: "Horizontal FoV", value: fovCalculations.horizontalFoVDisplay)
                    ResultRow(label: "Vertical FoV", value: fovCalculations.verticalFoVDisplay)
                    ResultRow(label: "Diagonal FoV", value: fovCalculations.diagonalFoVDisplay)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .tag(0)
                
                // Page 2: Visual Representation
                VStack(alignment: .center, spacing: 0) {
                    Text("Field of View at Focus Distance")
                        .font(.custom("American Typewriter", size: 14))
                        .foregroundColor(.white)
                        .padding(.top, 0)
                    
                    Spacer()
                    
                    if fovCalculations.diagonalFoVMM == 0.0 {
                        Text("Insufficient Data")
                            .font(.custom("American Typewriter", size: 16))
                            .foregroundColor(.white)
                            .padding(.top, 6)
                        Text("Please Select Camera and Lens")
                            .font(.custom("American Typewriter", size: 16))
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        GeometryReader { geometry in
                            let maxWidth = geometry.size.width - 40 // Leave padding
                            let maxHeight = geometry.size.height - 40 // Leave padding
                            let aspectRatio = fovCalculations.aspectRatio
                            
                            // Calculate base dimensions
                            let baseWidth = aspectRatio > 1
                            ? min(maxWidth, maxHeight * aspectRatio)
                            : min(maxWidth, maxHeight / aspectRatio) * aspectRatio
                            let baseHeight = aspectRatio > 1
                            ? baseWidth / aspectRatio
                            : min(maxHeight, maxWidth / aspectRatio)
                            
                            // Scale down by 20%
                            let boxWidth = baseWidth //* 0.75
                            let boxHeight = baseHeight //* 0.75
                            
                            VStack(spacing: 0) {
                                // Top label (horizontal dimension)
                                Text(fovCalculations.horizontalFoVDisplay)
                                    .font(.custom("American Typewriter", size: 12))
                                    .foregroundColor(.white)
                                    .padding(.bottom, 4)
                                    .lineLimit(1)
                                
                                HStack(spacing: 0) {
                                    // Left label (vertical dimension)
                                    Text(fovCalculations.verticalFoVDisplay)
                                        .font(.custom("American Typewriter", size: 12))
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(-90))
                                    //.frame(width: 20)
                                        .padding(.trailing, 4)
                                        .lineLimit(1)
                                    
                                    // The box representing the capture plane
                                    Rectangle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: boxWidth, height: boxHeight)
                                        .overlay(
                                            Rectangle()
                                                .stroke(Color.white, lineWidth: 2)
                                        )
                                    
                                    // Right label (vertical dimension)
                                    Text(fovCalculations.verticalFoVDisplay)
                                        .font(.custom("American Typewriter", size: 12))
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(90))
                                    //.frame(width: 20)
                                        .padding(.leading, 4)
                                        .lineLimit(1)
                                }
                                
                                // Bottom label (horizontal dimension)
                                Text(fovCalculations.horizontalFoVDisplay)
                                    .font(.custom("American Typewriter", size: 12))
                                    .foregroundColor(.white)
                                    .padding(.top, 4)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 200) // Force results height!!!!!
            
            // Page Indicator Dots
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(currentResultPage == index ? Color.white : Color.white.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
            
            Spacer()
                .frame(height: 8)
        }
        .background(Color(white: 0.25))
        .cornerRadius(8)
        .padding()
    }
    
    // MARK: - Lens Picker Sheet
    
    private var lensPickerSheet: some View {
        NavigationView {
            Group {
                if let camera = selectedCamera, !camera.lenses.isEmpty {
                    List {
                        ForEach(camera.lenses) { lens in
                            Button(action: {
                                selectedLens = lens
                                showLensPicker = false
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lens.name)
                                            .font(.headline)
                                        Text(lensTypeDescription(lens))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    if selectedLens?.id == lens.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.metering.unknown")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No Camera Selected")
                            .font(.headline)
                        Text("Please select a camera first to see available lenses.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Select Lens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showLensPicker = false
                    }
                }
            }
        }
    }
    
    private func lensTypeDescription(_ lens: Lens) -> String {
        switch lens.type {
        case .prime:
            if let focal = lens.primeFocalLength {
                return "\(focal)mm prime"
            }
            return "Prime lens"
        case .zoom:
            if let range = lens.zoomRange {
                return "\(range.min)-\(range.max)mm zoom"
            }
            return "Zoom lens"
        }
    }
    
    // MARK: - Distance Picker Sheet
    
    private var distancePickerSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Focus Distance")
                    .font(.headline)
                    .padding(.top)
                
                if isInfinity {
                    Text("∞")
                        .font(.system(size: 60, weight: .bold))
                        .monospacedDigit()
                } else {
                    Text(String(format: "%d'%d\"", focusDistanceFeet, focusDistanceInches))
                        .font(.system(size: 60, weight: .bold))
                        .monospacedDigit()
                }
                
                HStack(spacing: 20) {
                    // Feet Picker
                    VStack {
                        Text("Feet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Feet", selection: $focusDistanceFeet) {
                            ForEach(0..<50) { feet in
                                Text("\(feet)'").tag(feet)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .disabled(isInfinity)
                    }
                    
                    // Inches Picker
                    VStack {
                        Text("Inches")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Inches", selection: $focusDistanceInches) {
                            ForEach(0..<12) { inches in
                                Text("\(inches)\"").tag(inches)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .disabled(isInfinity)
                    }
                }
                
                Toggle(isOn: $isInfinity) {
                    HStack {
                        Image(systemName: "infinity")
                            .font(.title2)
                        Text("Infinity (≥50')")
                            .font(.headline)
                    }
                }
                .padding(.horizontal, 40)
                .onChange(of: isInfinity) { oldValue, newValue in
                    if newValue {
                        // Set to infinity equivalent
                        focusDistanceFeet = 50
                        focusDistanceInches = 0
                    }
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showDistancePicker = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        focusDistanceFeet = 10
                        focusDistanceInches = 0
                        isInfinity = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - FoV Calculations
    
    private func calculateFieldOfView() -> FoVResult {
        // Get focal length
        guard let focalLength = getFocalLength() else {
            return FoVResult.empty
        }
        
        // Get sensor dimensions from camera or default to Full Frame
        let sensorWidth: Double
        let sensorHeight: Double
        
        if let camera = selectedCamera {
            sensorWidth = camera.capturePlaneWidth
            sensorHeight = camera.capturePlaneHeight
        } else if let fullFrame = defaultFullFrame {
            sensorWidth = fullFrame.width
            sensorHeight = fullFrame.height
        } else {
            // Fallback to standard Full Frame dimensions
            sensorWidth = 36.0
            sensorHeight = 24.0
        }
        
        let sensorDiagonal = sqrt(sensorWidth * sensorWidth + sensorHeight * sensorHeight)
        let aperture = selectedAperture.value
        
        // Convert focus distance to millimeters
        let focusDistanceMM: Double
        if isInfinity {
            focusDistanceMM = Double.infinity
        } else {
            let totalInches = Double(focusDistanceFeet * 12 + focusDistanceInches)
            focusDistanceMM = totalInches * 25.4 // inches to mm
        }
        
        // Calculate Field of View angles
        // FoV angle = 2 * atan(sensor_dimension / (2 * focal_length))
        let horizontalAngleRad = 2.0 * atan(sensorWidth / (2.0 * focalLength))
        let verticalAngleRad = 2.0 * atan(sensorHeight / (2.0 * focalLength))
        let diagonalAngleRad = 2.0 * atan(sensorDiagonal / (2.0 * focalLength))
        
        // Convert radians to degrees
        let horizontalAngleDeg = horizontalAngleRad * 180.0 / .pi
        let verticalAngleDeg = verticalAngleRad * 180.0 / .pi
        let diagonalAngleDeg = diagonalAngleRad * 180.0 / .pi
        
        // Calculate Field of View dimensions at focus distance
        // FoV dimension = 2 * focus_distance * tan(angle / 2)
        let horizontalFoVMM: Double
        let verticalFoVMM: Double
        let diagonalFoVMM: Double
        
        if focusDistanceMM.isInfinite {
            horizontalFoVMM = Double.infinity
            verticalFoVMM = Double.infinity
            diagonalFoVMM = Double.infinity
        } else {
            horizontalFoVMM = 2.0 * focusDistanceMM * tan(horizontalAngleRad / 2.0)
            verticalFoVMM = 2.0 * focusDistanceMM * tan(verticalAngleRad / 2.0)
            diagonalFoVMM = 2.0 * focusDistanceMM * tan(diagonalAngleRad / 2.0)
        }
        
        return FoVResult(
            focalLength: focalLength,
            aperture: aperture,
            focusDistance: focusDistanceMM,
            sensorWidth: sensorWidth,
            sensorHeight: sensorHeight,
            horizontalAngleDeg: horizontalAngleDeg,
            verticalAngleDeg: verticalAngleDeg,
            diagonalAngleDeg: diagonalAngleDeg,
            horizontalFoVMM: horizontalFoVMM,
            verticalFoVMM: verticalFoVMM,
            diagonalFoVMM: diagonalFoVMM
        )
    }
    
    private func getFocalLength() -> Double? {
        guard let lens = selectedLens else { return nil }
        
        switch lens.type {
        case .prime:
            return Double(lens.primeFocalLength ?? 50)
        case .zoom:
            return Double(selectedZoom)
        }
    }
       
    private func getEffectiveSensorDiagonal() -> Double {
        if let camera = selectedCamera {
            return camera.capturePlaneDiagonal
        } else if let fullFrame = defaultFullFrame {
            return fullFrame.diagonal
        } else {
            // Fallback to standard Full Frame diagonal (43.27mm)
            return 43.27
        }
    }
    
    private func formatDistance(_ mm: Double) -> String {
        if mm.isInfinite {
            return "∞"
        }
        
        // Convert mm to feet and inches
        let inches = mm / 25.4
        let feet = Int(inches / 12.0)
        let remainingInches = Int(inches.truncatingRemainder(dividingBy: 12.0))
        
        if feet > 0 {
            return String(format: "%d'%d\"", feet, remainingInches)
        } else {
            return String(format: "%d\"", remainingInches)
        }
    }
    
    // MARK: - UserDefaults Save Methods
    
    private func saveCamera(_ camera: MyGearModel?) {
        if let camera = camera {
            UserDefaults.standard.set(camera.cameraName, forKey: MyGearSelectionKeys.selectedGearName)
        } else {
            UserDefaults.standard.removeObject(forKey: MyGearSelectionKeys.selectedGearName)
        }
    }
    
    private func saveLens(_ lens: Lens?) {
        if let lens = lens {
            UserDefaults.standard.set(lens.name, forKey: MyGearSelectionKeys.selectedLensName)
        } else {
            UserDefaults.standard.removeObject(forKey: MyGearSelectionKeys.selectedLensName)
        }
    }
    
    private func saveZoom(_ zoom: Int) {
        UserDefaults.standard.set(zoom, forKey: MyGearSelectionKeys.selectedZoom)
    }
    
    private func saveAperture(_ aperture: FStop) {
        UserDefaults.standard.set(aperture.value, forKey: kSelectedAperture)
    }
    
    private func saveFocusDistance() {
        UserDefaults.standard.set(focusDistanceFeet, forKey: kFocusDistanceFeet)
        UserDefaults.standard.set(focusDistanceInches, forKey: kFocusDistanceInches)
    }
    
    private func saveIsInfinity(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: kIsInfinity)
    }
}

// MARK: - FoV Result

struct FoVResult {
    let focalLength: Double
    let aperture: Double
    let focusDistance: Double
    let sensorWidth: Double
    let sensorHeight: Double
    let horizontalAngleDeg: Double
    let verticalAngleDeg: Double
    let diagonalAngleDeg: Double
    let horizontalFoVMM: Double
    let verticalFoVMM: Double
    let diagonalFoVMM: Double
    
    var focalLengthDisplay: String {
        String(format: "%.0f mm", focalLength)
    }
    
    var apertureDisplay: String {
        String(format: "f/%.1f", aperture)
    }
    
    var focusDistanceDisplay: String {
        formatDistance(focusDistance)
    }
    
    var horizontalAngleDisplay: String {
        String(format: "%.1f°", horizontalAngleDeg)
    }
    
    var verticalAngleDisplay: String {
        String(format: "%.1f°", verticalAngleDeg)
    }
    
    var diagonalAngleDisplay: String {
        String(format: "%.1f°", diagonalAngleDeg)
    }
    
    var horizontalFoVDisplay: String {
        formatDimension(horizontalFoVMM)
    }
    
    var verticalFoVDisplay: String {
        formatDimension(verticalFoVMM)
    }
    
    var diagonalFoVDisplay: String {
        formatDimension(diagonalFoVMM)
    }
    
    var aspectRatio: Double {
        sensorWidth / sensorHeight
    }
    
    private func formatDistance(_ mm: Double) -> String {
        if mm.isInfinite {
            return "∞"
        }
        
        // Convert mm to feet and inches
        let inches = mm / 25.4
        let feet = Int(inches / 12.0)
        let remainingInches = Int(inches.truncatingRemainder(dividingBy: 12.0))
        
        if feet > 0 {
            return String(format: "%d'%d\"", feet, remainingInches)
        } else {
            return String(format: "%d\"", remainingInches)
        }
    }
    
    private func formatDimension(_ mm: Double) -> String {
        if mm.isInfinite {
            return "∞"
        }
        
        // Convert mm to feet and inches for larger dimensions
        let inches = mm / 25.4
        
        if inches >= 12.0 {
            // Use feet and inches
            let feet = Int(inches / 12.0)
            let remainingInches = inches.truncatingRemainder(dividingBy: 12.0)
            
            if remainingInches >= 0.5 {
                return String(format: "%d'%.1f\"", feet, remainingInches)
            } else {
                return String(format: "%d'", feet)
            }
        } else if inches >= 1.0 {
            // Use just inches
            return String(format: "%.1f\"", inches)
        } else {
            // Use millimeters for small dimensions
            return String(format: "%.0f mm", mm)
        }
    }
    
    static var empty: FoVResult {
        FoVResult(
            focalLength: 0,
            aperture: 0,
            focusDistance: 0,
            sensorWidth: 0,
            sensorHeight: 0,
            horizontalAngleDeg: 0,
            verticalAngleDeg: 0,
            diagonalAngleDeg: 0,
            horizontalFoVMM: 0,
            verticalFoVMM: 0,
            diagonalFoVMM: 0
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        DepthOfFieldView()
    }
}
