//
//  CameraView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 10/13/25.
//

import SwiftUI
import AVFoundation
import CoreLocation
import CoreMotion
import Photos
import UIKit
import Combine
import ImageIO
import UniformTypeIdentifiers
import MapKit

// MARK: - Camera Lens Types
enum CameraLens: String, CaseIterable {
    case ultraWide = "0.5x"
    case wide = "1x"
    case telephoto = "2x"
    case telephoto3x = "3x"
    
    var displayLabel: String {
        switch self {
        case .ultraWide: return ".5"
        case .wide: return "1x"
        case .telephoto: return "2"
        case .telephoto3x: return "3"
        }
    }
    
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .telephoto: return .builtInTelephotoCamera
        case .telephoto3x: return .builtInTelephotoCamera
        }
    }
}

struct CameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showingLocationPermissionAlert = false
    @State private var showingInitialLocationRequest = false
    @State private var cameraStarted = false
    @State private var currentOrientation: UIDeviceOrientation = .portrait
    var onBack: (() -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fallback background to ensure something is visible
                Color.red.opacity(0.3)
                    .ignoresSafeArea()
                
                // Camera preview with dynamic sizing based on orientation
                CameraPreviewView(cameraManager: cameraManager, size: geometry.size)
                    .ignoresSafeArea()
                
                // Back button - positioned based on orientation
                VStack {
                    HStack {
                        if let onBack = onBack {
                            Button(action: onBack) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Home")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, geometry.safeAreaInsets.top + 60)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                
                // Camera controls - positioned based on orientation
                if currentOrientation.isLandscape {
                    // Landscape: right-aligned layout without rotation
                    HStack {
                        Spacer()
                        VStack {
                            Spacer()
                            
                            VStack(spacing: 20) {
                                // Top row: lens control (right-aligned)
                                HStack {
                                    Spacer()
                                    HStack(spacing: 4) {
                                        ForEach(cameraManager.availableLenses, id: \.rawValue) { lens in
                                            Button(action: {
                                                cameraManager.switchToLens(lens)
                                            }) {
                                                Text(lens.displayLabel)
                                                    .font(.system(size: 8, weight: .medium, design: .default))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30, height: 30)
                                                    .background(
                                                        Circle()
                                                            .fill(cameraManager.selectedLens == lens ? Color.black.opacity(0.8) : Color.gray.opacity(0.6))
                                                    )
                                            }
                                        }
                                    }
                                }
                                
                                // Second row: vertical angle (left) and horizontal angle (right)
                                HStack(spacing: 20) {
                                    Spacer()
                                    Text(formatVerticalAngle(cameraManager.currentTilt))
                                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(8)
                                    
                                    Text(formatHorizontalAngle(cameraManager.currentRoll))
                                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(8)
                                }
                                
                                Spacer().frame(height: 20)
                                
                                // Third row: shutter button (right-aligned)
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        cameraManager.capturePhoto()
                                    }) {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 70, height: 70)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.black, lineWidth: 2)
                                                    .frame(width: 60, height: 60)
                                            )
                                    }
                                }
                                
                                Spacer().frame(height: 20)
                                
                                // Bottom row: heading (right-aligned)
                                HStack {
                                    Spacer()
                                    Text(formatHeading(cameraManager.headingString))
                                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.trailing, geometry.safeAreaInsets.bottom + 20)
                    }
                } else {
                    // Portrait: controls at bottom
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            // Shutter button with lens selector at upper right
                            ZStack {
                                // Shutter button (centered)
                                Button(action: {
                                    cameraManager.capturePhoto()
                                }) {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.black, lineWidth: 2)
                                                .frame(width: 60, height: 60)
                                        )
                                }
                                
                                // Lens selector positioned at upper right of shutter button
                                HStack(spacing: 4) {
                                    ForEach(cameraManager.availableLenses, id: \.rawValue) { lens in
                                        Button(action: {
                                            cameraManager.switchToLens(lens)
                                        }) {
                                            Text(lens.displayLabel)
                                                .font(.system(size: 8, weight: .medium, design: .default))
                                                .foregroundColor(.white)
                                                .frame(width: 30, height: 30)
                                                .background(
                                                    Circle()
                                                        .fill(cameraManager.selectedLens == lens ? Color.black.opacity(0.8) : Color.gray.opacity(0.6))
                                                )
                                        }
                                    }
                                }
                                .offset(x: 120, y: -25) // Position further to the right to avoid obscuring shutter
                            }
                            
                            // Angle displays below shutter
                            HStack(spacing: 20) {
                                // Horizontal angle (horizon-relative roll)
                                Text(formatHorizontalAngle(cameraManager.currentRoll))
                                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                
                                // Heading
                                Text(formatHeading(cameraManager.headingString))
                                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                
                                // Vertical angle (horizon-relative)
                                Text(formatVerticalAngle(cameraManager.currentTilt))
                                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                    }
                }
            }
        }
        .onAppear {
            print("CameraView appeared")
            requestLocationPermissionIfNeeded()
        }
        .onDisappear {
            cameraManager.stopCamera()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            currentOrientation = orientation
            cameraManager.updateOrientation(orientation)
        }
        .alert("Location Services Required", isPresented: $showingLocationPermissionAlert) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Continue Without Location", role: .destructive) {
                startCameraIfNotStarted()
            }
        } message: {
            Text("PhotoAssistant needs location access to add GPS coordinates, addresses, and heading information to your photos. Please enable location services in Settings > Privacy & Security > Location Services > PhotoAssistant.")
        }
        .alert("Enable Location Services", isPresented: $showingInitialLocationRequest) {
            Button("Allow Location") {
                cameraManager.requestLocationPermission()
                startCameraIfNotStarted()
            }
            Button("Skip") {
                startCameraIfNotStarted()
            }
        } message: {
            Text("PhotoAssistant can add GPS coordinates, address, altitude, and compass heading to your photos. This helps with organizing and geotagging your images. Location data is only used for photo metadata and is not shared.")
        }
        .onChange(of: cameraManager.locationAuthorizationStatus) { _, newStatus in
            // React to location permission changes
            if newStatus == .denied || newStatus == .restricted {
                showingLocationPermissionAlert = true
            }
        }
    }
    
    private func requestLocationPermissionIfNeeded() {
        let locationStatus = cameraManager.locationAuthorizationStatus
        print("Current location status on startup: \(locationStatus.rawValue)")
        
        switch locationStatus {
        case .notDetermined:
            // Show explanation and request permission
            print("Location permission not determined, showing explanation alert")
            showingInitialLocationRequest = true
        case .denied, .restricted:
            // Permission was previously denied, show settings alert
            print("Location access denied/restricted, showing settings alert")
            showingLocationPermissionAlert = true
            // Start camera anyway for users who want to use without location
            startCameraIfNotStarted()
        case .authorizedWhenInUse, .authorizedAlways:
            // Permission already granted, start everything normally
            print("Location permission already granted, starting camera")
            startCameraIfNotStarted()
        @unknown default:
            // Unknown status, treat as not determined
            print("Unknown location permission status, showing explanation")
            showingInitialLocationRequest = true
        }
    }
    
    private func startCameraIfNotStarted() {
        guard !cameraStarted else { return }
        cameraStarted = true
        cameraManager.requestCameraPermissions()
        cameraManager.startCamera()
    }
    
    // Format vertical angle relative to horizon (0° = level)
    private func formatVerticalAngle(_ pitch: Double) -> String {
        // Pitch is already in degrees from motion update
        // Convert to camera reference frame where 0° = horizon level
        // Pointing down = positive, pointing up = negative
        
        // Normalize pitch to -180° to +180° range to handle full rotation
        var normalizedPitch = pitch
        while normalizedPitch > 180.0 {
            normalizedPitch -= 360.0
        }
        while normalizedPitch < -180.0 {
            normalizedPitch += 360.0
        }
        
        // Convert to camera angle where 0° = horizon level
        // When pitch is 90° (device upright, camera forward) = 0° camera angle
        let cameraAngle = normalizedPitch - 90.0
        
        // Normalize camera angle to -90° to +90° range for display
        var displayAngle = cameraAngle
        if displayAngle > 90.0 {
            displayAngle = 180.0 - displayAngle
        } else if displayAngle < -90.0 {
            displayAngle = -180.0 - displayAngle
        }
        
        // Invert the sign so pointing down = positive, pointing up = negative
        displayAngle = -displayAngle
        
        let sign = displayAngle >= 0 ? "+" : "-"
        
        // Debug logging
        //print("formatVerticalAngle - pitch: \(pitch), normalizedPitch: \(normalizedPitch), cameraAngle: \(cameraAngle), displayAngle: \(displayAngle), sign: \(sign)")
        
        return String(format: "%@%04.1f°", sign, abs(displayAngle))
    }
    
    // Format horizontal angle relative to horizon (0° = level)
    private func formatHorizontalAngle(_ roll: Double) -> String {
        // Roll is already in degrees, 0° = level, negative = counterclockwise, positive = clockwise
        let horizonAngle = roll
        let sign = horizonAngle >= 0 ? "+" : ""
        return String(format: "%@%04.1f°", sign, horizonAngle)
    }
    
    // Format heading with zero padding and fixed-width compass direction
    private func formatHeading(_ headingString: String) -> String {
        // Extract numeric heading from string like "31° NNW"
        let components = headingString.components(separatedBy: "°")
        if let headingStr = components.first,
           let heading = Double(headingStr) {
            let direction = components.count > 1 ? components[1].trimmingCharacters(in: .whitespaces) : "N"
            // Pad direction to 3 characters to prevent jiggling using Swift's native padding
            let paddedDirection = direction.padding(toLength: 3, withPad: " ", startingAt: 0)
            return String(format: "%03.0f° %@", heading, paddedDirection)
        }
        return "000° N  "
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    let size: CGSize
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        // Create preview layer to show 100% of camera output
        let previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        // Use resizeAspectFill to show the complete camera field of view
        // This ensures you see 100% of what the camera captures
        previewLayer.videoGravity = .resizeAspectFill
        
        view.layer.addSublayer(previewLayer)
        cameraManager.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = cameraManager.previewLayer {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject, CLLocationManagerDelegate, AVCapturePhotoCaptureDelegate {
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput = AVCapturePhotoOutput()
    
    // Location and motion managers
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()
    
    // Published properties for UI updates
    @Published var locationString = "Getting location..."
    @Published var headingString = "Getting heading..."
    @Published var altitudeString = "Getting altitude..."
    @Published var tiltString = "Getting tilt..."
    @Published var cameraStatus = "Initializing..."
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentTilt: Double = 0.0
    @Published var currentRoll: Double = 0.0
    @Published var availableLenses: [CameraLens] = []
    @Published var selectedLens: CameraLens = .wide
    
    // Current sensor data
    private var currentLocation: CLLocation?
    private var currentHeading: CLHeading?
    private var currentOrientation: UIDeviceOrientation = .portrait
    
    // Reverse geocoding - Updated for iOS 26.0
    @Published var currentAddress = "Getting address..."
    private var lastGeocodedLocation: CLLocation?
    
    override init() {
        super.init()
        locationAuthorizationStatus = CLLocationManager().authorizationStatus
        setupLocationManager()
        setupMotionManager()
    }
    
    func requestCameraPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Camera permission granted")
                } else {
                    print("Camera permission denied")
                }
            }
        }
    }
    
    func requestLocationPermission() {
        print("Explicitly requesting location permission...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1.0
        
        let authStatus = locationManager.authorizationStatus
        print("Current location authorization status: \(authStatus.rawValue)")
        
        switch authStatus {
        case .notDetermined:
            print("Location permission not determined, requesting authorization...")
            DispatchQueue.main.async {
                self.locationString = "Requesting location permission..."
                self.currentAddress = "Requesting permission..."
            }
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.locationString = "Location access denied"
                self.altitudeString = "N/A"
                self.headingString = "N/A"
                self.currentAddress = "Location access denied"
            }
            print("Location access denied or restricted")
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location permission already granted, starting updates immediately")
            startLocationUpdates()
        @unknown default:
            print("Unknown location authorization status, requesting permission")
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func startLocationUpdates() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            print("Location not authorized")
            return
        }
        
        print("Starting location updates...")
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func setupMotionManager() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion else { return }
                
                let pitch = motion.attitude.pitch
                let roll = motion.attitude.roll
                
                let tiltDegrees = pitch * 180.0 / .pi
                let rollDegrees = roll * 180.0 / .pi
                
                self?.currentTilt = tiltDegrees
                self?.currentRoll = rollDegrees
                self?.tiltString = String(format: "%.1f°", tiltDegrees)
            }
        }
    }
    
    func startCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard self.captureSession.inputs.isEmpty else { return }
            
            // Detect available camera lenses
            self.detectAvailableLenses()
            
            self.captureSession.beginConfiguration()
            
            // Set to highest resolution photo preset for full quality
            if self.captureSession.canSetSessionPreset(.hd4K3840x2160) {
                self.captureSession.sessionPreset = .hd4K3840x2160
            } else if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            }
            
            // Start with the default lens (wide if available, otherwise first available)
            let startingLens = self.availableLenses.contains(.wide) ? .wide : (self.availableLenses.first ?? .wide)
            self.setupCameraForLens(startingLens)
            
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.selectedLens = startingLens
                self.cameraStatus = "Camera Ready (\(startingLens.displayLabel))"
            }
            
            print("Camera session started successfully with \(startingLens.rawValue) lens")
        }
    }
    
    private func detectAvailableLenses() {
        var lenses: [CameraLens] = []
        
        // Check each lens type for availability
        for lens in CameraLens.allCases {
            if AVCaptureDevice.default(lens.deviceType, for: .video, position: .back) != nil {
                lenses.append(lens)
            }
        }
        
        DispatchQueue.main.async {
            self.availableLenses = lenses
        }
        
        print("Available lenses: \(lenses.map { $0.rawValue }.joined(separator: ", "))")
    }
    
    private func setupCameraForLens(_ lens: CameraLens) {
        // Remove existing inputs
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        
        guard let camera = AVCaptureDevice.default(lens.deviceType, for: .video, position: .back) else {
            print("Unable to access \(lens.rawValue) camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // Configure photo output for maximum quality and full resolution
            if !captureSession.outputs.contains(photoOutput) && captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                
                // Set to highest quality and full resolution
                if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    // Use HEVC for better compression while maintaining quality
                    if #available(iOS 16.0, *) {
                        // Get the maximum supported photo dimensions from the device's active format
                        if let activeFormat = camera.activeFormat.supportedMaxPhotoDimensions.max(by: {
                            $0.width * $0.height < $1.width * $1.height
                        }) {
                            photoOutput.maxPhotoDimensions = activeFormat
                            print("Set maxPhotoDimensions to: \(activeFormat.width)x\(activeFormat.height)")
                        }
                    } else {
                        photoOutput.isHighResolutionCaptureEnabled = true
                    }
                }
            }
            
            print("Successfully configured camera for \(lens.rawValue)")
            
        } catch {
            print("Error setting up camera for \(lens.rawValue): \(error)")
        }
    }
    
    func switchToLens(_ lens: CameraLens) {
        guard availableLenses.contains(lens), lens != selectedLens else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.setupCameraForLens(lens)
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                self.selectedLens = lens
                self.cameraStatus = "Camera Ready (\(lens.displayLabel))"
            }
            
            print("Switched to \(lens.rawValue) lens")
        }
    }
    
    func stopCamera() {
        captureSession.stopRunning()
        DispatchQueue.main.async {
            self.cameraStatus = "Camera Stopped"
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func compassDirection(from heading: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((heading + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    private func reverseGeocode(location: CLLocation) {
        // Only geocode if location has changed significantly (more than 50 meters)
        if let lastLocation = lastGeocodedLocation,
           location.distance(from: lastLocation) < 50 {
            return
        }
        
        print("Starting reverse geocoding for: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Use MapKit for iOS 26.0+, fallback to CLGeocoder for older versions
        if #available(iOS 26.0, *) {
            // Use MapKit for iOS 26.0+ (CLGeocoder is deprecated)
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            request.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, error in
                if let error = error {
                    print("MapKit geocoding error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.currentAddress = "Address lookup failed"
                    }
                    return
                }
                
                guard let mapItem = response?.mapItems.first else {
                    print("No address found with MapKit")
                    DispatchQueue.main.async {
                        self?.currentAddress = "No address found"
                    }
                    return
                }
                
                // Enhanced address formatting with landmark detection and city/state
                let placemark = mapItem.placemark
                var addressComponents: [String] = []
                var hasLandmark = false
                
                // Check if mapItem name contains recognizable landmarks
                if let name = mapItem.name, !name.isEmpty {
                    let lowercaseName = name.lowercased()
                    let landmarks = ["grand canyon", "yellowstone", "yosemite", "mount", "lake", "beach", "park", "monument", "national", "state park", "bridge", "tower", "museum", "cathedral", "church", "stadium", "airport", "university", "college", "hospital", "plaza", "square", "center", "garden", "zoo", "aquarium", "observatory", "lighthouse", "falls", "river", "valley", "forest", "desert", "glacier", "volcano", "trail", "overlook", "viewpoint", "rim", "point", "peak", "summit"]
                    
                    // Check if name contains landmark keywords or is likely a point of interest
                    hasLandmark = landmarks.contains { lowercaseName.contains($0) } ||
                                 name.count > 20 || // Long descriptive names are often landmarks
                                 !lowercaseName.contains("st ") && !lowercaseName.contains("ave ") && !lowercaseName.contains("rd ") // Not a street address
                    
                    if hasLandmark {
                        addressComponents.append(name)
                    }
                }
                
                // Add street address if no landmark or if landmark doesn't seem complete
                if !hasLandmark {
                    if let subThoroughfare = placemark.subThoroughfare,
                       let thoroughfare = placemark.thoroughfare {
                        addressComponents.append("\(subThoroughfare) \(thoroughfare)")
                    } else if let thoroughfare = placemark.thoroughfare {
                        addressComponents.append(thoroughfare)
                    }
                }
                
                // Always add city and state when available for context
                if let locality = placemark.locality,
                   let administrativeArea = placemark.administrativeArea {
                    addressComponents.append("\(locality), \(administrativeArea)")
                } else if let locality = placemark.locality {
                    addressComponents.append(locality)
                } else if let administrativeArea = placemark.administrativeArea {
                    addressComponents.append(administrativeArea)
                }
                
                let formattedAddress = addressComponents.joined(separator: " | ")
                
                print("Successfully geocoded address with MapKit: \(formattedAddress)")
                DispatchQueue.main.async {
                    self?.currentAddress = formattedAddress.isEmpty ? "Address unavailable" : formattedAddress
                    self?.lastGeocodedLocation = location
                }
            }
        } else {
            // Use CLGeocoder for iOS versions before 26.0
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.currentAddress = "Address lookup failed"
                }
                return
            }
            
            guard let placemark = placemarks?.first else {
                print("No placemark found for location")
                DispatchQueue.main.async {
                    self?.currentAddress = "No address found"
                }
                return
            }
            
            // Enhanced address formatting with landmark detection and city/state
            var addressComponents: [String] = []
            var hasLandmark = false
            
            // Check for recognizable landmarks in placemark name or areas of interest
            if let name = placemark.name, !name.isEmpty {
                let lowercaseName = name.lowercased()
                let landmarks = ["grand canyon", "yellowstone", "yosemite", "mount", "lake", "beach", "park", "monument", "national", "state park", "bridge", "tower", "museum", "cathedral", "church", "stadium", "airport", "university", "college", "hospital", "plaza", "square", "center", "garden", "zoo", "aquarium", "observatory", "lighthouse", "falls", "river", "valley", "forest", "desert", "glacier", "volcano", "trail", "overlook", "viewpoint", "rim", "point", "peak", "summit"]
                
                // Check if name contains landmark keywords or is likely a point of interest
                hasLandmark = landmarks.contains { lowercaseName.contains($0) } ||
                             name.count > 20 || // Long descriptive names are often landmarks
                             !lowercaseName.contains("st ") && !lowercaseName.contains("ave ") && !lowercaseName.contains("rd ") // Not a street address
                
                if hasLandmark {
                    addressComponents.append(name)
                }
            }
            
            // Also check areasOfInterest for landmarks
            if !hasLandmark, let areasOfInterest = placemark.areasOfInterest, !areasOfInterest.isEmpty {
                for area in areasOfInterest {
                    let lowercaseArea = area.lowercased()
                    let landmarks = ["grand canyon", "yellowstone", "yosemite", "mount", "lake", "beach", "park", "monument", "national", "state park", "bridge", "tower", "museum", "cathedral", "church", "stadium", "airport", "university", "college", "hospital", "plaza", "square", "center", "garden", "zoo", "aquarium", "observatory", "lighthouse", "falls", "river", "valley", "forest", "desert", "glacier", "volcano", "trail", "overlook", "viewpoint", "rim", "point", "peak", "summit"]
                    
                    if landmarks.contains(where: { lowercaseArea.contains($0) }) {
                        addressComponents.append(area)
                        hasLandmark = true
                        break
                    }
                }
            }
            
            // Add street address if no landmark found
            if !hasLandmark {
                if let subThoroughfare = placemark.subThoroughfare,
                   let thoroughfare = placemark.thoroughfare {
                    addressComponents.append("\(subThoroughfare) \(thoroughfare)")
                } else if let thoroughfare = placemark.thoroughfare {
                    addressComponents.append(thoroughfare)
                }
            }
            
            // Always add city and state when available for context
            if let locality = placemark.locality,
               let administrativeArea = placemark.administrativeArea {
                addressComponents.append("\(locality), \(administrativeArea)")
            } else if let locality = placemark.locality {
                addressComponents.append(locality)
            } else if let administrativeArea = placemark.administrativeArea {
                addressComponents.append(administrativeArea)
            }
            
            let formattedAddress = addressComponents.joined(separator: " | ")
            
            print("Successfully geocoded address: \(formattedAddress)")
            DispatchQueue.main.async {
                self?.currentAddress = formattedAddress.isEmpty ? "Address unavailable" : formattedAddress
                self?.lastGeocodedLocation = location
            }
            }
        }
    }
    
    func updateOrientation(_ orientation: UIDeviceOrientation) {
        currentOrientation = orientation
        
        guard let connection = previewLayer?.connection else { return }
        
        switch orientation {
        case .portrait:
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 0
            } else {
                connection.videoOrientation = .portrait
            }
        case .landscapeLeft:
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                connection.videoOrientation = .landscapeRight
            }
        case .landscapeRight:
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 270
            } else {
                connection.videoOrientation = .landscapeLeft
            }
        case .portraitUpsideDown:
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 180
            } else {
                connection.videoOrientation = .portraitUpsideDown
            }
        default:
            break
        }
        
        print("Device orientation updated to: \(orientation.rawValue)")
    }
}

// MARK: - Location Manager Delegate
extension CameraManager {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.locationAuthorizationStatus = manager.authorizationStatus
        }
        
        print("Location authorization changed to: \(manager.authorizationStatus.rawValue)")
        
        switch manager.authorizationStatus {
        case .notDetermined:
            print("Location permission not determined - will request when needed")
            DispatchQueue.main.async {
                self.locationString = "Location permission pending..."
                self.currentAddress = "Permission pending..."
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.locationString = "Enable location in Settings"
                self.altitudeString = "N/A"
                self.headingString = "N/A"
                self.currentAddress = "Enable location in Settings"
            }
            print("Location access denied or restricted - user needs to enable in Settings")
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location permission granted, starting location updates...")
            DispatchQueue.main.async {
                self.locationString = "Getting GPS fix..."
                self.currentAddress = "Getting location..."
            }
            startLocationUpdates()
        @unknown default:
            print("Unknown location authorization status")
            DispatchQueue.main.async {
                self.locationString = "Unknown permission status"
                self.currentAddress = "Permission error"
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        print("Location updated: \(location)")
        print("Location accuracy: \(location.horizontalAccuracy) meters")
        print("Altitude accuracy: \(location.verticalAccuracy) meters")
        
        currentLocation = location
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        if lat != 0.0 && lon != 0.0 && location.horizontalAccuracy < 100 {
            // Trigger reverse geocoding for good location data
            reverseGeocode(location: location)
            
            DispatchQueue.main.async {
                self.locationString = String(format: "%.6f, %.6f", lat, lon)
                
                if location.verticalAccuracy < 0 {
                    self.altitudeString = "Unknown"
                } else {
                    let altitudeFeet = location.altitude * 3.28084
                    self.altitudeString = String(format: "%.0f'", altitudeFeet)
                }
            }
        } else if location.horizontalAccuracy >= 100 {
            DispatchQueue.main.async {
                self.locationString = "GPS acquiring... (±\(Int(location.horizontalAccuracy))m)"
                self.altitudeString = "Acquiring..."
            }
        } else {
            DispatchQueue.main.async {
                self.locationString = "GPS searching..."
                self.altitudeString = "Searching..."
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else {
            headingString = "Compass calibrating..."
            return
        }
        
        currentHeading = newHeading
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        let direction = compassDirection(from: heading)
        headingString = String(format: "%.0f° %@", heading, direction)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let clError = error as? CLError
        let errorCode = clError?.code.rawValue ?? -1
        
        print("Location manager failed with error: \(error.localizedDescription)")
        print("Error code: \(errorCode)")
        
        if let clError = clError {
            switch clError.code {
            case .denied:
                print("Location access denied - user needs to enable location in Settings")
                DispatchQueue.main.async {
                    self.locationString = "Location denied in Settings"
                    self.currentAddress = "Enable location in Settings"
                }
            case .locationUnknown:
                print("Location unknown - GPS signal may be weak")
                DispatchQueue.main.async {
                    self.locationString = "GPS signal weak"
                    self.currentAddress = "Searching for GPS signal..."
                }
            case .network:
                print("Network error - check internet connection")
                DispatchQueue.main.async {
                    self.locationString = "Network error"
                    self.currentAddress = "Check internet connection"
                }
            default:
                print("Other location error: \(clError.localizedDescription)")
                DispatchQueue.main.async {
                    self.locationString = "Location error (\(errorCode))"
                    self.currentAddress = "Location service error"
                }
            }
        }
        
        DispatchQueue.main.async {
            self.altitudeString = "Error"
            self.headingString = "Error"
        }
    }
}

// MARK: - Photo Capture Delegate
extension CameraManager {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error: could not get image data")
            return
        }
        
        // Create image with EXIF metadata embedded including proper orientation
        let imageWithMetadata = addEXIFMetadata(to: imageData)
        
        // Create UIImage with proper orientation handling
        guard let image = UIImage(data: imageWithMetadata) else {
            print("Error: could not create UIImage from data")
            return
        }
        
        // Apply proper orientation to the image before adding banner
        let orientedImage = applyProperOrientation(to: image)
        let imageWithBanner = addLocationBanner(to: orientedImage)
        
        // Convert the final image back to data to preserve metadata
        guard let finalImageData = imageWithBanner.jpegData(compressionQuality: 0.95) else {
            print("Error: could not convert final image to JPEG data")
            return
        }
        
        // Re-add metadata to the final image data (since adding banner removes it)
        let finalImageWithMetadata = addEXIFMetadata(to: finalImageData)
        
        // Save the photo with metadata to photo library
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if status == .authorized {
                do {
                    try await PHPhotoLibrary.shared().performChanges {
                        // Create the asset creation request
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        
                        // Add the image data with metadata
                        creationRequest.addResource(with: .photo, data: finalImageWithMetadata, options: nil)
                        
                        // Set location data directly on the asset if available
                        if let location = self.currentLocation {
                            creationRequest.location = location
                            print("Set location directly on PHAsset: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                        }
                        
                        // Set creation date
                        creationRequest.creationDate = Date()
                    }
                    DispatchQueue.main.async {
                        print("Photo saved successfully with GPS metadata and banner")
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Error saving photo: \(error.localizedDescription)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    print("Photo library access denied")
                }
            }
        }
    }
    
    // MARK: - Missing Helper Functions
    
    private func addEXIFMetadata(to imageData: Data) -> Data {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return imageData
        }
        
        let mutableData = NSMutableData(data: imageData)
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return imageData
        }
        
        var mutableMetadata = metadata
        
        // Add GPS metadata if location is available
        if let location = currentLocation {
            mutableMetadata[kCGImagePropertyGPSDictionary as String] = createGPSMetadata(from: location)
        }
        
        // Add timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        var exifDict = mutableMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        exifDict[kCGImagePropertyExifDateTimeOriginal as String] = timestamp
        exifDict[kCGImagePropertyExifDateTimeDigitized as String] = timestamp
        mutableMetadata[kCGImagePropertyExifDictionary as String] = exifDict
        
        CGImageDestinationAddImageFromSource(destination, source, 0, mutableMetadata as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        return mutableData as Data
    }
    
    private func createGPSMetadata(from location: CLLocation) -> [String: Any] {
        let coordinate = location.coordinate
        let altitude = location.altitude
        let timestamp = location.timestamp
        
        var gpsMetadata: [String: Any] = [:]
        
        // Latitude
        gpsMetadata[kCGImagePropertyGPSLatitude as String] = abs(coordinate.latitude)
        gpsMetadata[kCGImagePropertyGPSLatitudeRef as String] = coordinate.latitude >= 0 ? "N" : "S"
        
        // Longitude
        gpsMetadata[kCGImagePropertyGPSLongitude as String] = abs(coordinate.longitude)
        gpsMetadata[kCGImagePropertyGPSLongitudeRef as String] = coordinate.longitude >= 0 ? "E" : "W"
        
        // Altitude
        gpsMetadata[kCGImagePropertyGPSAltitude as String] = abs(altitude)
        gpsMetadata[kCGImagePropertyGPSAltitudeRef as String] = altitude >= 0 ? 0 : 1
        
        // Timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        gpsMetadata[kCGImagePropertyGPSTimeStamp as String] = dateFormatter.string(from: timestamp)
        
        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy:MM:dd"
        dateOnlyFormatter.timeZone = TimeZone(identifier: "UTC")
        gpsMetadata[kCGImagePropertyGPSDateStamp as String] = dateOnlyFormatter.string(from: timestamp)
        
        return gpsMetadata
    }
    
    private func applyProperOrientation(to image: UIImage) -> UIImage {
        switch currentOrientation {
        case .landscapeLeft:
            return rotateImage(image, by: .left)
        case .landscapeRight:
            return rotateImage(image, by: .right)
        case .portraitUpsideDown:
            return rotateImage(image, by: .down)
        default:
            return image
        }
    }
    
    private func rotateImage(_ image: UIImage, by direction: UIImage.Orientation) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let orientation: UIImage.Orientation
        switch direction {
        case .left:
            orientation = .left
        case .right:
            orientation = .right
        case .down:
            orientation = .down
        default:
            orientation = .up
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation)
    }
    
    private func addLocationBanner(to image: UIImage) -> UIImage {
        let bannerHeight: CGFloat = 120  // Height for two lines of text
        let fontSize: CGFloat = 32       // Optimal size for readability
        let lineSpacing: CGFloat = 8     // Space between lines
        
        // Format the timestamp in the requested format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MMM-dd h:mm:ss a zzz"
        let timestamp = dateFormatter.string(from: Date())
        
        // Format GPS coordinates with proper sign formatting
        let gpsText: String
        if let location = currentLocation {
            let lat = location.coordinate.latitude
            let lng = location.coordinate.longitude
            let latSign = lat >= 0 ? "+" : ""
            let lngSign = lng >= 0 ? "+" : ""
            gpsText = String(format: "%@%.8f, %@%.8f", latSign, lat, lngSign, lng)
        } else {
            gpsText = "GPS not available"
        }
        
        // Format heading with compass direction
        let headingText: String
        if let heading = currentHeading {
            let trueHeading = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
            let direction = compassDirection(from: trueHeading)
            headingText = String(format: "%.0f° %@", trueHeading, direction)
        } else {
            headingText = "No heading"
        }
        
        // Create the two-line banner text
        let line1 = "Captured: \(timestamp) | \(currentAddress)"
        let line2 = "Gps: \(gpsText) | Heading: \(headingText) | Altitude: \(altitudeString) | Azimuth: \(tiltString)"
        
        // Get the actual rendered size of the image (accounting for orientation)
        let imageSize = image.size
        let actualWidth = imageSize.width
        let actualHeight = imageSize.height
        
        // Create new image size with banner at bottom
        let newSize = CGSize(width: actualWidth, height: actualHeight + bannerHeight)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }
        
        // Draw original image properly oriented at the top
        let imageRect = CGRect(x: 0, y: 0, width: actualWidth, height: actualHeight)
        image.draw(in: imageRect)
        
        // Banner at the bottom
        let bannerRect = CGRect(x: 0, y: actualHeight, width: actualWidth, height: bannerHeight)
        
        // Fill banner background with semi-transparent black
        context.setFillColor(UIColor.black.withAlphaComponent(0.85).cgColor)
        context.fill(bannerRect)
        
        // Configure text attributes with monospace font
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.clear
        ]
        
        // Calculate text sizes and positions
        let line1Size = line1.size(withAttributes: textAttributes)
        let line2Size = line2.size(withAttributes: textAttributes)
        
        // Position text lines vertically centered in banner
        let totalTextHeight = line1Size.height + lineSpacing + line2Size.height
        let startY = actualHeight + (bannerHeight - totalTextHeight) / 2
        
        // Draw first line (centered horizontally)
        let line1X = (actualWidth - line1Size.width) / 2
        let line1Rect = CGRect(x: line1X, y: startY, width: line1Size.width, height: line1Size.height)
        line1.draw(in: line1Rect, withAttributes: textAttributes)
        
        // Draw second line (centered horizontally)
        let line2X = (actualWidth - line2Size.width) / 2
        let line2Rect = CGRect(x: line2X, y: startY + line1Size.height + lineSpacing, width: line2Size.width, height: line2Size.height)
        line2.draw(in: line2Rect, withAttributes: textAttributes)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    // MARK: - GPS Metadata Creation
    private func createGPSMetadata(location: CLLocation, heading: CLHeading?) -> [String: Any] {
        var gpsDict: [String: Any] = [:]
        
        print("Creating GPS metadata for location: \(location)")
        
        // Latitude - ensure proper numeric format
        let latitude = location.coordinate.latitude
        gpsDict[kCGImagePropertyGPSLatitude as String] = NSNumber(value: abs(latitude))
        gpsDict[kCGImagePropertyGPSLatitudeRef as String] = (latitude < 0.0) ? "S" : "N"
        print("GPS Latitude: \(abs(latitude)) \(latitude < 0.0 ? "S" : "N")")
        
        // Longitude - ensure proper numeric format
        let longitude = location.coordinate.longitude
        gpsDict[kCGImagePropertyGPSLongitude as String] = NSNumber(value: abs(longitude))
        gpsDict[kCGImagePropertyGPSLongitudeRef as String] = (longitude < 0.0) ? "W" : "E"
        print("GPS Longitude: \(abs(longitude)) \(longitude < 0.0 ? "W" : "E")")
        
        // Elevation (Altitude) - ensure proper numeric format
        let altitude = location.altitude
        gpsDict[kCGImagePropertyGPSAltitude as String] = NSNumber(value: abs(altitude))
        gpsDict[kCGImagePropertyGPSAltitudeRef as String] = NSNumber(value: altitude < 0 ? 1 : 0) // 0 = above sea level, 1 = below sea level
        print("GPS Altitude: \(abs(altitude))m \(altitude < 0 ? "below" : "above") sea level")
        
        // Horizontal accuracy
        if location.horizontalAccuracy >= 0 {
            gpsDict[kCGImagePropertyGPSHPositioningError as String] = NSNumber(value: location.horizontalAccuracy)
            print("GPS Horizontal Accuracy: \(location.horizontalAccuracy)m")
        }
        
        // Vertical accuracy for altitude
        if location.verticalAccuracy >= 0 {
            // Store vertical accuracy in GPS processing method or user comment since there's no direct EXIF field
            print("GPS Vertical Accuracy: \(location.verticalAccuracy)m")
        }
        
        // True Heading (Image Direction) - only if heading is available and valid
        if let heading = heading {
            if heading.trueHeading >= 0 {
                gpsDict[kCGImagePropertyGPSImgDirection as String] = NSNumber(value: heading.trueHeading)
                gpsDict[kCGImagePropertyGPSImgDirectionRef as String] = "T" // 'T' for True North
                print("GPS True Heading: \(heading.trueHeading)°")
            } else if heading.magneticHeading >= 0 {
                // Fall back to magnetic heading if true heading not available
                gpsDict[kCGImagePropertyGPSImgDirection as String] = NSNumber(value: heading.magneticHeading)
                gpsDict[kCGImagePropertyGPSImgDirectionRef as String] = "M" // 'M' for Magnetic North
                print("GPS Magnetic Heading: \(heading.magneticHeading)°")
            }
            
            // Add heading accuracy if available
            if heading.headingAccuracy >= 0 {
                print("GPS Heading Accuracy: ±\(heading.headingAccuracy)°")
            }
        } else {
            print("No heading data available for GPS metadata")
        }
        
        // GPS Date and Time Stamps - use location timestamp for accuracy
        let locationTimestamp = location.timestamp
        gpsDict[kCGImagePropertyGPSTimeStamp as String] = DateFormatter.gpsTimeStampFormatter.string(from: locationTimestamp)
        gpsDict[kCGImagePropertyGPSDateStamp as String] = DateFormatter.gpsDateStampFormatter.string(from: locationTimestamp)
        print("GPS Timestamp: \(locationTimestamp)")
        
        // Additional standard GPS metadata
        gpsDict[kCGImagePropertyGPSProcessingMethod as String] = "GPS"
        gpsDict[kCGImagePropertyGPSMapDatum as String] = "WGS-84"
        
        // GPS Version - specify which GPS specification we're following
        gpsDict[kCGImagePropertyGPSVersion as String] = "2.2.0.0"
        
        print("GPS metadata dictionary created with \(gpsDict.count) entries")
        print("GPS dictionary keys: \(gpsDict.keys.sorted())")
        
        return gpsDict
    }
}

// MARK: - DateFormatter Extensions
extension DateFormatter {
    static let gpsDateStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        return formatter
    }()
    
    static let gpsTimeStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        return formatter
    }()
}

// MARK: - View Extension for Rotation Detection
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            action(UIDevice.current.orientation)
        }
    }
}

#Preview {
    CameraView()
}
