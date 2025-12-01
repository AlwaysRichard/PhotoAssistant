//
//  DepthOfFieldView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/29/25.
//

import SwiftUI

// MARK: - Depth of Field View

struct DepthOfFieldView: View {
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
    
    // MARK: - Computed DoF Values
    private var dofCalculations: DoFResult {
        calculateDepthOfField()
    }
    
    // MARK: - UserDefaults Keys (using centralized keys)
    // Note: DoF-specific keys like aperture and focus distance use their own keys
    private let kSelectedAperture = MyGearSelectionKeys.depthAperture
    private let kFocusDistanceFeet = MyGearSelectionKeys.depthFeet
    private let kFocusDistanceInches = MyGearSelectionKeys.depthInches
    private let kIsInfinity = MyGearSelectionKeys.depthInfinity
    
    // MARK - Define Custom Control State for CameraDisplayView
    let customControlState = CameraDisplayControlState(
        aperturePicker: PickerControl(
            enabled: true,
            disabledTextLabel: "f/--",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        shutterPicker: PickerControl(
            enabled: false,
            disabledTextLabel: "---",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        ISOPicker: PickerControl(
            enabled: false,
            disabledTextLabel: "---",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
        ),
        EVPicker: PickerControl(
            enabled: false,
            disabledTextLabel: "-.-",
            disabledColor: Color(red: 0.643, green: 0.122, blue: 0.133)
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
        .navigationTitle("DoF - Depth of Field")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedCamera) { oldValue, newValue in
            saveCamera(newValue)
            // Reset lens when camera changes
            // selectedLens = nil
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
                Image(systemName: "camera.aperture")
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
            
            // Results
            Group {
                ResultRow(label: "Camera Settings", value: "\(dofCalculations.focalLengthDisplay), \(dofCalculations.apertureDisplay), \(dofCalculations.focusDistanceDisplay)")
                //ResultRow(label: "Focal Length (f)", value: dofCalculations.focalLengthDisplay)
                //ResultRow(label: "Aperture (N)", value: dofCalculations.apertureDisplay)
                //ResultRow(label: "Focus Distance (u)", value: dofCalculations.focusDistanceDisplay)
                ResultRow(label: "CoC (c)", value: dofCalculations.cocDisplay)
                ResultRow(label: "Hyperfocal Distance (H)", value: dofCalculations.hyperfocalDisplay)
                ResultRow(label: "DoF Near Limit (D₁)", value: dofCalculations.nearLimitDisplay)
                ResultRow(label: "DoF Far Limit (D₂)", value: dofCalculations.farLimitDisplay)
                ResultRow(label: "Total Depth of Field", value: dofCalculations.totalDoFDisplay)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            
            Spacer()
                .frame(height: 12)
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
    
    // MARK: - DoF Calculations
    
    private func calculateDepthOfField() -> DoFResult {
        // Get focal length
        guard let focalLength = getFocalLength() else {
            return DoFResult.empty
        }
        
        // Get CoC from camera sensor or default to Full Frame
        let sensorDiagonal = getEffectiveSensorDiagonal()
        let coc = sensorDiagonal / 1500.0
        let aperture = selectedAperture.value
        
        // Convert focus distance to millimeters
        let focusDistanceMM: Double
        if isInfinity {
            focusDistanceMM = Double.infinity
        } else {
            let totalInches = Double(focusDistanceFeet * 12 + focusDistanceInches)
            focusDistanceMM = totalInches * 25.4 // inches to mm
        }
        
        // Calculate hyperfocal distance
        // H = (f² / (N × c)) + f
        let hyperfocalMM = (focalLength * focalLength) / (aperture * coc) + focalLength
        
        // Calculate near and far limits
        let nearLimitMM: Double
        let farLimitMM: Double
        
        if isInfinity || focusDistanceMM >= hyperfocalMM {
            // Focused at or beyond hyperfocal
            nearLimitMM = hyperfocalMM / 2.0
            farLimitMM = Double.infinity
        } else {
            // DoF = (H × u) / (H ± u)
            // Near: (H × u) / (H + u)
            // Far: (H × u) / (H - u)
            nearLimitMM = (hyperfocalMM * focusDistanceMM) / (hyperfocalMM + focusDistanceMM - 2 * focalLength)
            farLimitMM = (hyperfocalMM * focusDistanceMM) / (hyperfocalMM - focusDistanceMM + 2 * focalLength)
        }
        
        // Total DoF
        let totalDoFMM = farLimitMM.isInfinite ? Double.infinity : farLimitMM - nearLimitMM
        
        return DoFResult(
            focalLength: focalLength,
            aperture: aperture,
            focusDistance: focusDistanceMM,
            coc: coc,
            hyperfocal: hyperfocalMM,
            nearLimit: nearLimitMM,
            farLimit: farLimitMM,
            totalDoF: totalDoFMM,
            isInfinity: isInfinity
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
    
    private func calculateCoC(camera: MyGearModel) -> Double {
        // CoC is typically calculated as diagonal / 1500
        // This gives the acceptable circle of confusion
        return camera.capturePlaneDiagonal / 1500.0
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

// MARK: - DoF Result

struct DoFResult {
    let focalLength: Double
    let aperture: Double
    let focusDistance: Double
    let coc: Double
    let hyperfocal: Double
    let nearLimit: Double
    let farLimit: Double
    let totalDoF: Double
    let isInfinity: Bool
    
    var focalLengthDisplay: String {
        String(format: "%.0f mm", focalLength)
    }
    
    var apertureDisplay: String {
        String(format: "f/%.1f", aperture)
    }
    
    var focusDistanceDisplay: String {
        formatDistance(focusDistance)
    }
    
    var cocDisplay: String {
        String(format: "%.3f mm", coc)
    }
    
    var hyperfocalDisplay: String {
        formatDistance(hyperfocal)
    }
    
    var nearLimitDisplay: String {
        formatDistance(nearLimit)
    }
    
    var farLimitDisplay: String {
        formatDistance(farLimit)
    }
    
    var totalDoFDisplay: String {
        formatDistance(totalDoF)
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
    
    static var empty: DoFResult {
        DoFResult(
            focalLength: 0,
            aperture: 0,
            focusDistance: 0,
            coc: 0,
            hyperfocal: 0,
            nearLimit: 0,
            farLimit: 0,
            totalDoF: 0,
            isInfinity: false
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        DepthOfFieldView()
    }
}
