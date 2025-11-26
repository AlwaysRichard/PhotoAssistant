//
//  CameraView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 10/18/25.
//
//  Updated for maximum stability using persistent AVCaptureVideoPreviewLayer pattern
//  FIXED: Main Thread Checker error by wrapping all UI layer access in DispatchQueue.main.async

import Combine
import AVFoundation
import SwiftUI
import CoreLocation
import ImageIO
import UniformTypeIdentifiers
import SwiftData

// MARK: - REMOVED: struct FilmFormat { ... }
// MARK: - REMOVED: struct ZoomLens { ... }
// Assuming ZoomRange, Lens, and MyGearModel are available from MyGearModel.swift

enum CornerPosition {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

// MARK: - SwiftUI View

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraManager()
    @State private var showCropMarks = false
    @State private var selectedFocalLength = 80
    @State private var showCropMarksControlPanel = false

    // NEW STATE: For managing loaded gear and the selected camera
    @State private var gearList: [MyGearModel] = MyGearModel.loadGearList()
    @State private var selectedGear: MyGearModel?
    
    // CALIBRATION MODE: Parameters passed from calibration flow
    var isCalibrationMode: Bool = false
    var calibrationCapturePlane: String = ""
    var calibrationWidth: Double = 0
    var calibrationHeight: Double = 0
    var calibrationDiagonal: Double = 0
    var calibrationFocalLength: Int = 0
    var calibrationZoom: CGFloat = 1.0
    
    // NEW: Computed property for the currently selected gear's data
    private var currentGearData: MyGearModel {
        // Fallback logic for when selectedGear is nil (e.g., initial load or empty list)
        if let gear = selectedGear {
            return gear
        }
        
        // Define a default/fallback camera if MyGearModel.loadGearList() returns empty or selectedGear is nil
        return MyGearModel(
            cameraName: "Hasselblad 500c (Default)",
            capturePlane: "6x6 cm (Default)",
            capturePlaneWidth: 60,
            capturePlaneHeight: 60,
            capturePlaneDiagonal: 84.85,
            lenses: [
                Lens(name: "80mm", type: .prime, primeFocalLength: 80)
            ]
        )
    }

    // Lenses array for isZoomLens check (must be accessible from here)
    // MODIFIED: Use the lenses from the selected gear
    private var availableZoomLensesForCheck: [Lens] {
        currentGearData.lenses.filter { $0.type == .zoom && $0.zoomRange != nil }
    }


    var body: some View {
        ZStack {
            if camera.hasPermission && camera.isCameraReady {
                
                // Use the new CameraPreviewView which wraps the persistent layer
                CameraPreviewView(container: camera.getPreviewViewContainer(), showCropMarks: showCropMarks)
                    .ignoresSafeArea()
                    // MODIFIED: Only hides the control panel; leaves the crop marks visible if a lens is selected.
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCropMarksControlPanel = false
                        }
                    }
                
                // Calculate the effective focal length, correctly unwrapping the Binding
                let effectiveFocalLength = Int(round(camera.physicalFocalLength * camera.baseZoomFactor))
                
                // Determine if the selected focal length is within a zoom range for visualization
                let isZoomLensActive: Bool = availableZoomLensesForCheck.first(where: {
                    selectedFocalLength >= $0.zoomRange?.min ?? Int.min && selectedFocalLength <= $0.zoomRange?.max ?? Int.max
                }) != nil

                // Crop marks overlay
                CropMarksOverlay(
                    // MODIFIED: Pass dimensions instead of filmFormat struct
                    capturePlane: currentGearData.capturePlane,
                    capturePlaneWidth: currentGearData.capturePlaneWidth,
                    capturePlaneHeight: currentGearData.capturePlaneHeight,
                    capturePlaneDiagonal: currentGearData.capturePlaneDiagonal,
                    selectedFocalLength: selectedFocalLength,
                    currentCameraFocalLength: effectiveFocalLength,
                    isVisible: showCropMarks,
                    isZoomLens: isZoomLensActive,
                    actualDiagonalFOV: camera.actualDiagonalFOV,  // Pass actual FOV
                    currentZoomFactor: camera.currentZoom  // FIXED: Use currentZoom (user-facing 0.5x, 1x, 2x) not baseZoomFactor
                )
                .allowsHitTesting(false)

                VStack {
                    // Crop marks control panel at the top, visible only when toggled by the toolbar button.
                    if showCropMarksControlPanel {
                        HStack {
                            Spacer()
                            CropMarksControlPanel(
                                // NEW: Pass the gear list and selection binding
                                gearList: gearList,
                                selectedGear: $selectedGear,
                                selectedFocalLength: $selectedFocalLength,
                                currentCameraFocalLength: effectiveFocalLength,
                                showCropMarks: $showCropMarks
                            )
                            // MODIFIED: Increased padding to place it reliably below the navigation bar
                            .padding(.top, 125)
                            .padding(.trailing, 20)
                        }
                    }
                    
                    Spacer()
                    
                    // Camera name and current lens selection
                    VStack(spacing: 4) {
                        if showCropMarks {
                            // MODIFIED: Replace "Hasselblad 500c" with the selected camera's name
                            Text("\(currentGearData.cameraName) / \(selectedFocalLength)mm")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // Zoom lens buttons - HIDE in calibration mode
                    if !isCalibrationMode {
                        HStack(spacing: 15) {
                            ForEach(camera.availableZoomLevels, id: \.self) { zoom in
                                Button(action: {
                                    // Correct call syntax for the @StateObject's object
                                    camera.switchInternalCamera(zoom)
                                }) {
                                    Text(zoom < 1 ? ".5x" : "\(Int(zoom))x")
                                        .font(.system(size: 16, weight: camera.getClosestZoomLevel() == zoom ? .bold : .regular))
                                        .foregroundColor(camera.getClosestZoomLevel() == zoom ? .yellow : .white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(camera.getClosestZoomLevel() == zoom ? Color.white.opacity(0.3) : Color.clear)
                                        .cornerRadius(15)
                                }
                                .disabled(camera.isCapturing)
                            }
                        }
                        .padding(.bottom, 12)
                    }

                    // ----------------------------------------------------------------------------------
                    // MODIFICATION: Centering Shutter and Positioning Switch Button
                    // HIDE in calibration mode - calibration workflow provides its own shutter
                    // ----------------------------------------------------------------------------------
                    if !isCalibrationMode {
                        HStack(spacing: 0) {
                            Spacer() // Pushes controls to the center

                            // 1. Switch Camera Button (just to the left of the Shutter)
                            Button(action: {
                                camera.switchCamera()
                            }) {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                            }
                            .padding(.trailing, 25) // Reduced padding for closer placement
                            .disabled(camera.isCapturing)

                            // 2. Capture Photo Button (Shutter - Centered)
                            Button(action: {
                                camera.capturePhoto()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(camera.isCapturing ? 0.5 : 1.0))
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                                .frame(width: 80, height: 80)
                                        )
                                    if camera.isCapturing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                            .scaleEffect(1.2)
                                    }
                                }
                            }
                            .disabled(camera.isCapturing)
                            
                            // 3. Placeholder (Invisible View) to balance the width of the Switch button and its padding (50+25=75)
                            Color.clear.frame(width: 50 + 25, height: 1)
                            
                            Spacer()
                        }
                        .padding(.bottom, 50)
                    }
                }
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)

                    if !camera.hasPermission {
                        Text("Camera Access Required")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Please allow camera access in Settings to use this feature")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 10)

                    } else if camera.isSimulator {
                        Text("Camera Not Available")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Camera functionality is not available in the iOS Simulator. Please test on a physical device.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                    } else if camera.isCameraLocked {
                        Text("Camera Temporarily Unavailable")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("The camera may be in use by another application. Please close the other application or exit its camera view, then return to GeoLog.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                    } else {
                        Text("Setting Up Camera...")
                            .font(.title2)
                            .foregroundColor(.white)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding(.top, 10)
                    }
                }
            }
        }
        // MODIFIED: Toolbar button only toggles the control panel visibility.
        // HIDE in calibration mode
        .toolbar {
            if !isCalibrationMode {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCropMarksControlPanel.toggle()
                            
                            // REMOVED: Logic to turn off crop marks when panel closes.
                            // Now, crop marks only hide when the user taps the active lens button inside the panel.
                        }
                    }) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(1.0))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .onAppear {
            camera.setModelContext(modelContext)
            
            // CALIBRATION MODE: Setup if in calibration mode
            if isCalibrationMode {
                // Create a temporary gear model with calibration parameters
                let calibrationGear = MyGearModel(
                    cameraName: calibrationCapturePlane,
                    capturePlane: calibrationCapturePlane,
                    capturePlaneWidth: calibrationWidth,
                    capturePlaneHeight: calibrationHeight,
                    capturePlaneDiagonal: calibrationDiagonal,
                    lenses: [Lens(name: "\(calibrationFocalLength)mm", type: .prime, primeFocalLength: calibrationFocalLength)]
                )
                selectedGear = calibrationGear
                selectedFocalLength = calibrationFocalLength
                showCropMarks = true // Always show crop marks in calibration mode
                
                // Switch to the correct iPhone lens
                camera.switchInternalCamera(calibrationZoom)
                
                print("📸 CameraView entered calibration mode:")
                print("   Capture plane: \(calibrationCapturePlane)")
                print("   Focal length: \(calibrationFocalLength)mm")
                print("   iPhone zoom: \(calibrationZoom)x")
            } else {
                // Normal mode: Set the initial selected gear if it exists
                if selectedGear == nil, let firstGear = gearList.first {
                    selectedGear = firstGear
                    // Also set the initial focal length from the first available prime lens, or 80mm default
                    selectedFocalLength = firstGear.lenses.first(where: { $0.type == .prime })?.primeFocalLength ?? 80
                }
            }

            if camera.hasPermission {
                if !camera.isSimulator {
                    camera.reloadCamera()
                }
            } else {
                camera.checkInitialPermissions()
            }
        }
        .onDisappear {
            camera.pauseSession()
        }
        .onReceive(camera.objectWillChange) {
            if camera.isCameraReady && camera.hasPermission && !camera.isSimulator {
                // Trigger view redraw when manager state changes
            }
        }
    }
}

// MARK: - AVCaptureSession Management (CameraManager)
// ... (CameraManager remains the same)

class CameraManager: NSObject, ObservableObject, CLLocationManagerDelegate, AVCapturePhotoCaptureDelegate {
    @Published var isCameraReady = false
    @Published var hasPermission = false
    @Published var isCameraLocked = false
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var currentZoom: CGFloat = 1.0
    @Published var availableZoomLevels: [CGFloat] = []
    @Published var isCapturing = false
    @Published var errorMessage = ""
    
    // ----------------------------------------------------------------------------------
    // MODIFICATION: Renamed back to physicalFocalLength as it now holds the actual mm value.
    // ----------------------------------------------------------------------------------
    @Published var physicalFocalLength: CGFloat = 0.0
    @Published var actualDiagonalFOV: CGFloat = 0.0  // Actual diagonal FOV in radians
    @Published var calibrationData: AVCameraCalibrationData?  // NEW: Calibration data from camera
    
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private let sessionQueue = DispatchQueue(label: "com.photoAssistant.camerasession")
    
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()  // NEW: For calibration data
    private var videoDataOutputQueue = DispatchQueue(label: "com.photoAssistant.videoDataOutput")  // NEW
    private var currentInput: AVCaptureDeviceInput?
    private var currentDevice: AVCaptureDevice?
    public var baseZoomFactor: CGFloat = 1.0
    private var locationManager: CLLocationManager?
    private var currentLocation: CLLocation?
    private var currentHeading: CLHeading?
    private var modelContext: ModelContext?
    private var geocodeManager = GeocodeManager()
    private var deviceOrientation: UIDeviceOrientation = .portrait
    
    private var restartAttemptCount: Int = 0
    private let maxRestartAttempts: Int = 40
    
    private let previewLayerContainer = PreviewViewContainer()
    
    override init() {
        super.init()
        setupLocationManager()
        setupOrientationMonitoring()
        setupSessionObservers()
        setupAppLifecycleObservers()
    }
    
    func getPreviewViewContainer() -> UIView {
        return previewLayerContainer
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    private func setupOrientationMonitoring() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func orientationDidChange() {
        let orientation = UIDevice.current.orientation
        if orientation != .faceUp && orientation != .faceDown && orientation != .unknown {
            deviceOrientation = orientation
        }
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
        locationManager?.startUpdatingHeading()
    }

    func checkInitialPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            hasPermission = true
            if !isSimulator {
                detectAvailableZoomLevels()
                configureCameraSession()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                    if granted && !self.isSimulator {
                        self.detectAvailableZoomLevels()
                        self.configureCameraSession()
                    } else if self.isSimulator {
                        self.errorMessage = "Camera is not available in the iOS Simulator"
                    } else {
                        self.errorMessage = "Camera access was denied"
                    }
                }
            }
        case .denied, .restricted:
            hasPermission = false
            errorMessage = "Camera access is required to take photos. Please enable camera access in Settings."
        @unknown default:
            hasPermission = false
            errorMessage = "Unknown camera permission status"
        }
    }
    
    private func detectAvailableZoomLevels() {
        var zoomLevels: [CGFloat] = []
        
        let position = currentPosition
        
        if position == .back {
            // Ultra-wide (0.5x)
            if AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil {
                zoomLevels.append(0.5)
            }
            
            // Wide (1x) - always present on back camera
            if let wideCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                zoomLevels.append(1.0)
                
                // Check for 48MP sensor (iPhone 14 Pro+) that supports 2x
                let format = wideCamera.activeFormat
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                if dimensions.width >= 4000 {
                    zoomLevels.append(2.0)
                }
            }
            
            // Telephoto (2x or 3x depending on model)
            if let teleCamera = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
                let focalLength = teleCamera.activeFormat.approx35mmFocalLength
                if focalLength > 70 {
                    zoomLevels.append(3.0)  // iPhone 14 Pro+ has 3x
                } else {
                    zoomLevels.append(2.0)  // Older models have 2x
                }
            }
        } else {
            // Front camera
            if AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil {
                zoomLevels.append(1.0)
            }
        }
        
        zoomLevels = Array(Set(zoomLevels)).sorted()
        
        if zoomLevels.isEmpty {
            zoomLevels.append(1.0)
        }
        
        DispatchQueue.main.async {
            self.availableZoomLevels = zoomLevels
            
            if self.currentZoom == 0 || !zoomLevels.contains(self.currentZoom) {
                if let firstZoom = zoomLevels.first {
                    self.currentZoom = firstZoom
                }
            }
        }
    }
    
    func configureCameraSession() {
        guard !session.isRunning || !isCameraReady else {
            print("Camera session already configured and running")
            return
        }
        
        DispatchQueue.main.async {
            self.isCameraReady = false
        }
        
        sessionQueue.async {
            self.configureCameraSessionLogic()
            
            DispatchQueue.main.async {
                if let firstZoom = self.availableZoomLevels.first {
                    self.switchInternalCamera(firstZoom)
                }
            }
        }
    }
    
    private func configureCameraSessionLogic() {
        session.beginConfiguration()
        
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }
        
        session.sessionPreset = .photo
        
        var camera: AVCaptureDevice?
        
        if currentPosition == .back {
            // Select the appropriate camera based on current zoom level
            if currentZoom == 0.5 {
                camera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                print("Configuring ultra-wide camera for zoom \(currentZoom)")
            } else if currentZoom == 1.0 {
                camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                print("Configuring wide-angle camera for zoom \(currentZoom)")
            } else if currentZoom >= 2.0 {
                camera = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
                print("Configuring telephoto camera for zoom \(currentZoom)")
            }
            
            // Fallback to wide-angle camera if target camera is not available
            if camera == nil {
                camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                print("Fallback to wide-angle camera")
            }
        } else {
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        
        guard let selectedCamera = camera else {
            print("Unable to access camera")
            session.commitConfiguration()
            return
        }
        
        currentDevice = selectedCamera
        
        do {
            let input = try AVCaptureDeviceInput(device: selectedCamera)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
            } else {
                print("Cannot add camera input to session")
                session.commitConfiguration()
                return
            }
        } catch {
            print("Error setting up camera input: \(error)")
            session.commitConfiguration()
            return
        }
        
        photoOutput.isHighResolutionCaptureEnabled = true
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            print("Cannot add photo output to session")
        }
        
        // NEW: Add video data output to capture calibration data
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Cannot add video data output to session")
        }
        
        session.commitConfiguration()
        
        self.session.startRunning()
        
        // ----------------------------------------------------------------------------------
        // FIX: Use currentDevice.activeFormat.lensFocalLength (Available iOS 7.0+)
        // ----------------------------------------------------------------------------------
        DispatchQueue.main.async {
            self.physicalFocalLength = selectedCamera.activeFormat.approx35mmFocalLength
            // NEW: Capture the actual diagonal FOV in radians
            let fovDegrees = CGFloat(selectedCamera.activeFormat.videoFieldOfView)
            self.actualDiagonalFOV = fovDegrees * .pi / 180.0
            
            #if DEBUG
            print("📸 Camera Configuration:")
            print("  Device: \(selectedCamera.localizedName)")
            print("  35mm equiv focal length: \(selectedCamera.activeFormat.approx35mmFocalLength)mm")
            print("  videoFieldOfView: \(selectedCamera.activeFormat.videoFieldOfView)°")
            print("  actualDiagonalFOV: \(self.actualDiagonalFOV * 180 / .pi)°")
            #endif
        }
    }
    
    private func setupSessionObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidStartRunning),
            name: .AVCaptureSessionDidStartRunning,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidStopRunning),
            name: .AVCaptureSessionDidStopRunning,
            object: session
        )
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        if hasPermission && !isSimulator && !session.isRunning {
            print("App is active, attempting final session reload.")
            self.reloadCamera()
        }
    }
    
    @objc private func appWillResignActive() {
        print("App will resign active, pausing camera session")
        self.pauseSession()
    }
    
    func attemptRestartSession() {
        sessionQueue.asyncAfter(deadline: .now() + 0.5) {
            self.performRestartAttempt()
        }
    }

    private func performRestartAttempt() {
        guard self.restartAttemptCount < self.maxRestartAttempts else {
            print("Failed to restart session after \(self.maxRestartAttempts) retries. Camera likely held by another app.")
            DispatchQueue.main.async { self.restartAttemptCount = 0 }
            return
        }
        
        if !self.session.isRunning {
            print("Attempt #\(self.restartAttemptCount + 1): Calling session.startRunning()...")
            
            self.session.startRunning()
            
            self.sessionQueue.asyncAfter(deadline: .now() + 0.5) {
                if !self.session.isRunning {
                    self.restartAttemptCount += 1
                    self.performRestartAttempt()
                } else {
                    print("Session successfully resumed after \(self.restartAttemptCount) retries.")
                    DispatchQueue.main.async { self.restartAttemptCount = 0 }
                }
            }
        } else {
            DispatchQueue.main.async { self.restartAttemptCount = 0 }
        }
    }
    
    @objc private func sessionWasInterrupted(notification: NSNotification) {
        print("AVCaptureSession was interrupted")
        DispatchQueue.main.async {
            self.isCameraReady = false
            self.isCameraLocked = true
        }
    }
    
    @objc private func sessionInterruptionEnded(notification: NSNotification) {
        print("AVCaptureSession interruption ended. Starting retry sequence...")
        DispatchQueue.main.async {
            self.restartAttemptCount = 0
        }
        self.attemptRestartSession()
    }

    @objc private func sessionDidStartRunning(notification: NSNotification) {
        print("AVCaptureSession started running.")
        
        // Ensure zoom levels are properly detected after session starts
        self.detectAvailableZoomLevels()
        
        // 🚨 FIX: Dispatch to main queue to set the session on the UI layer.
        DispatchQueue.main.async {
            self.previewLayerContainer.videoPreviewLayer.session = self.session
            
            self.isCameraReady = true
            self.isCameraLocked = false
            self.restartAttemptCount = 0
            self.objectWillChange.send()
        }
    }

    @objc private func sessionDidStopRunning(notification: NSNotification) {
        print("AVCaptureSession stopped running.")
        
        // 🚨 FIX: Dispatch to main queue to clear the session from the UI layer.
        DispatchQueue.main.async {
            self.previewLayerContainer.videoPreviewLayer.session = nil
            
            self.isCameraReady = false
        }
    }
    
    func switchInternalCamera(_ zoom: CGFloat) {
        sessionQueue.async {
            if self.currentPosition == .back {
                var targetCamera: AVCaptureDevice?
                var targetDeviceType: AVCaptureDevice.DeviceType?
                var targetZoomFactor: CGFloat = 1.0
                
                // Determine which camera and zoom factor to use
                if zoom <= 0.5 {
                    targetCamera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
                    targetDeviceType = .builtInUltraWideCamera
                    targetZoomFactor = 1.0
                } else if zoom <= 1.0 {
                    targetCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                    targetDeviceType = .builtInWideAngleCamera
                    targetZoomFactor = 1.0
                } else if zoom < 2.5 {
                    // For 2x: check if telephoto is 2x native, otherwise use wide with digital zoom
                    if let teleCamera = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
                        let focalLength = teleCamera.activeFormat.approx35mmFocalLength
                        if focalLength < 70 {
                            // 2x telephoto
                            targetCamera = teleCamera
                            targetDeviceType = .builtInTelephotoCamera
                            targetZoomFactor = 1.0
                        } else {
                            // Use wide with 2x digital
                            targetCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                            targetDeviceType = .builtInWideAngleCamera
                            targetZoomFactor = 2.0
                        }
                    } else {
                        targetCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                        targetDeviceType = .builtInWideAngleCamera
                        targetZoomFactor = 2.0
                    }
                } else {
                    // 3x telephoto
                    targetCamera = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
                    targetDeviceType = .builtInTelephotoCamera
                    targetZoomFactor = 1.0
                }
                
                guard let targetCamera = targetCamera, let targetType = targetDeviceType else {
                    return
                }
                
                // Switch camera if needed
                if self.currentDevice?.deviceType != targetType {
                    print("Switching to \(targetType) for zoom \(zoom)x")
                    self.switchToCameraLogic(targetCamera)
                }

                // Set zoom factor
                do {
                    try targetCamera.lockForConfiguration()
                    targetCamera.videoZoomFactor = targetZoomFactor
                    targetCamera.unlockForConfiguration()

                    DispatchQueue.main.async {
                        self.currentZoom = zoom
                        self.baseZoomFactor = targetZoomFactor
                        self.physicalFocalLength = targetCamera.activeFormat.approx35mmFocalLength
                        
                        // NEW: Update the actual diagonal FOV, accounting for digital zoom
                        let baseFovDegrees = CGFloat(targetCamera.activeFormat.videoFieldOfView)
                        
                        // When using digital zoom, the effective FOV is narrower
                        // FOV' = 2 * arctan(tan(FOV/2) / zoomFactor)
                        if targetZoomFactor > 1.0 {
                            let baseFovRadians = baseFovDegrees * .pi / 180.0
                            let effectiveFovRadians = 2.0 * atan(tan(baseFovRadians / 2.0) / targetZoomFactor)
                            self.actualDiagonalFOV = effectiveFovRadians
                        } else {
                            // No digital zoom, use the native FOV
                            self.actualDiagonalFOV = baseFovDegrees * .pi / 180.0
                        }
                        
                        #if DEBUG
                        print("📸 Switched to \(zoom)x camera:")
                        print("  Device: \(targetCamera.localizedName)")
                        print("  35mm equiv: \(targetCamera.activeFormat.approx35mmFocalLength)mm")
                        print("  videoFieldOfView (base): \(targetCamera.activeFormat.videoFieldOfView)°")
                        print("  Digital zoom factor: \(targetZoomFactor)x")
                        print("  Effective diagonal FOV: \(self.actualDiagonalFOV * 180 / .pi)°")
                        #endif
                    }
                } catch {
                    print("Error setting zoom: \(error)")
                }
            }
        }
    }
    
    func handlePinchZoom(scale: CGFloat) {
        sessionQueue.async {
            guard let device = self.currentDevice else { return }
            
            let newZoom = self.baseZoomFactor * scale
            let clampedZoom = min(max(newZoom, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    // Update currentZoom to reflect actual zoom for button highlighting
                    self.currentZoom = clampedZoom
                    self.physicalFocalLength = device.activeFormat.approx35mmFocalLength
                    // NEW: Update the actual diagonal FOV
                    let fovDegrees = CGFloat(device.activeFormat.videoFieldOfView)
                    self.actualDiagonalFOV = fovDegrees * .pi / 180.0
                }
            } catch {
                print("Error handling pinch zoom: \(error)")
            }
        }
    }
    
    func finalizePinchZoom() {
        sessionQueue.async {
            guard let device = self.currentDevice else { return }
            DispatchQueue.main.async {
                self.baseZoomFactor = device.videoZoomFactor
            }
        }
    }
    
    func getClosestZoomLevel() -> CGFloat {
        guard !availableZoomLevels.isEmpty else { return currentZoom }
        
        var closest = availableZoomLevels[0]
        var minDifference = abs(currentZoom - closest)
        
        for level in availableZoomLevels {
            let difference = abs(currentZoom - level)
            if difference < minDifference {
                minDifference = difference
                closest = level
            }
        }
        
        return closest
    }
    
    private func switchToCameraLogic(_ newCamera: AVCaptureDevice) {
        session.beginConfiguration()
        
        if let currentInput = currentInput {
            session.removeInput(currentInput)
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentInput = newInput
                currentDevice = newCamera
            }
        } catch {
            print("Error switching camera lens: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    func switchCamera() {
        currentPosition = currentPosition == .back ? .front : .back
        
        sessionQueue.async {
            self.session.beginConfiguration()
            
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            var newCamera: AVCaptureDevice?
            let position = self.currentPosition
            
            // Always start with wide-angle camera when switching positions
            if position == .back {
                newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            } else {
                newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            }
            
            guard let selectedCamera = newCamera else {
                print("Unable to access camera")
                self.session.commitConfiguration()
                return
            }
            
            self.currentDevice = selectedCamera
            
            do {
                let newInput = try AVCaptureDeviceInput(device: selectedCamera)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.currentInput = newInput
                }
            } catch {
                print("Error switching camera: \(error)")
            }
            
            self.session.commitConfiguration()
            
            DispatchQueue.main.async {
                // Update focal length for new camera
                if let selectedCamera = self.currentDevice {
                    self.physicalFocalLength = selectedCamera.activeFormat.approx35mmFocalLength
                    // NEW: Update the actual diagonal FOV
                    let fovDegrees = CGFloat(selectedCamera.activeFormat.videoFieldOfView)
                    self.actualDiagonalFOV = fovDegrees * .pi / 180.0
                }
                
                // Re-detect available zoom levels for the new camera position
                self.detectAvailableZoomLevels()
                
                // Reset to 1x zoom when switching cameras
                self.currentZoom = 1.0
                self.baseZoomFactor = 1.0
                self.switchInternalCamera(1.0)
            }
        }
    }
    
    func pauseSession() {
        print("Pausing camera session")
        sessionQueue.async {
            if self.session.isRunning {
                print("Pausing camera session on serial queue")
                self.session.stopRunning()
            }
        }
    }
    
    func reloadCamera() {
        print("Manual camera reload requested (or view re-entry)")
        
        DispatchQueue.main.async {
            self.isCameraReady = false
            self.isCameraLocked = false
        }
        
        sessionQueue.async {
            if self.session.isRunning {
                print("Stopping running session on serial queue...")
                self.session.stopRunning()
            }
            
            if self.hasPermission && !self.isSimulator {
                print("Reconfiguring camera session on serial queue...")
                self.configureCameraSessionLogic()
            }
        }
    }
    
    func capturePhoto() {
        guard !isCapturing else { return }
        
        DispatchQueue.main.async {
            self.isCapturing = true
        }
        
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    private func exifOrientationFromDeviceOrientation() -> Int {
        switch deviceOrientation {
        case .portrait:
            return 6  // Right, top
        case .portraitUpsideDown:
            return 8  // Left, bottom
        case .landscapeLeft:
            return 1  // Up, left
        case .landscapeRight:
            return 3  // Down, right
        default:
            return 6  // Default to portrait
        }
    }
    
    private func addEXIFMetadata(to imageData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        
        var metadata = imageProperties
        let now = Date()
        
        var tiffDict: [String: Any] = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiffDict[kCGImagePropertyTIFFMake as String] = "Apple"
        tiffDict[kCGImagePropertyTIFFModel as String] = UIDevice.current.model
        tiffDict[kCGImagePropertyTIFFSoftware as String] = "PhotoAssistant"
        
        tiffDict[kCGImagePropertyTIFFOrientation as String] = exifOrientationFromDeviceOrientation()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let dateString = dateFormatter.string(from: now)
        tiffDict[kCGImagePropertyTIFFDateTime as String] = dateString
        
        metadata[kCGImagePropertyTIFFDictionary as String] = tiffDict
        
        var exifDict: [String: Any] = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        exifDict[kCGImagePropertyExifDateTimeOriginal as String] = dateString
        exifDict[kCGImagePropertyExifDateTimeDigitized as String] = dateString
        
        if let device = currentDevice {
            if device.exposureDuration.seconds > 0 {
                exifDict[kCGImagePropertyExifExposureTime as String] = device.exposureDuration.seconds
            }
            exifDict[kCGImagePropertyExifISOSpeedRatings as String] = [Int(device.iso)]
            exifDict[kCGImagePropertyExifFNumber as String] = device.lensAperture
            exifDict[kCGImagePropertyExifLensModel as String] = device.localizedName
        }
        
        exifDict[kCGImagePropertyExifSceneType as String] = 1
        exifDict[kCGImagePropertyExifWhiteBalance as String] = 0
        
        metadata[kCGImagePropertyExifDictionary as String] = exifDict
        
        if let location = currentLocation {
            var gpsDict: [String: Any] = [:]
            
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            
            gpsDict[kCGImagePropertyGPSLatitude as String] = abs(latitude)
            gpsDict[kCGImagePropertyGPSLatitudeRef as String] = latitude >= 0 ? "N" : "S"
            gpsDict[kCGImagePropertyGPSLongitude as String] = abs(longitude)
            gpsDict[kCGImagePropertyGPSLongitudeRef as String] = longitude >= 0 ? "E" : "W"
            
            let altitude = location.altitude
            gpsDict[kCGImagePropertyGPSAltitude as String] = abs(altitude)
            gpsDict[kCGImagePropertyGPSAltitudeRef as String] = altitude >= 0 ? 0 : 1
            
            if let heading = currentHeading {
                if heading.trueHeading >= 0 {
                    gpsDict[kCGImagePropertyGPSImgDirection as String] = heading.trueHeading
                    gpsDict[kCGImagePropertyGPSImgDirectionRef as String] = "T"
                } else if heading.magneticHeading >= 0 {
                    gpsDict[kCGImagePropertyGPSImgDirection as String] = heading.magneticHeading
                    gpsDict[kCGImagePropertyGPSImgDirectionRef as String] = "M"
                }
            }
            
            let gpsDateFormatter = DateFormatter()
            gpsDateFormatter.dateFormat = "yyyy:MM:dd"
            gpsDateFormatter.timeZone = TimeZone(identifier: "UTC")
            gpsDict[kCGImagePropertyGPSDateStamp as String] = gpsDateFormatter.string(from: location.timestamp)
            
            gpsDateFormatter.dateFormat = "HH:mm:ss"
            gpsDict[kCGImagePropertyGPSTimeStamp as String] = gpsDateFormatter.string(from: location.timestamp)
            
            gpsDict[kCGImagePropertyGPSProcessingMethod as String] = "GPS"
            
            if location.speed >= 0 {
                gpsDict[kCGImagePropertyGPSSpeed as String] = location.speed
                gpsDict[kCGImagePropertyGPSSpeedRef as String] = "K"
            }
            
            metadata[kCGImagePropertyGPSDictionary as String] = gpsDict
        }
        
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return mutableData as Data
    }
    
    deinit {
        if session.isRunning {
            sessionQueue.sync {
                self.session.stopRunning()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        // Extract calibration data from the sample buffer
        // This is available in the attachments of the sample buffer
        guard let attachments = CMCopyDictionaryOfAttachments(
            allocator: kCFAllocatorDefault,
            target: sampleBuffer,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        ) as? [String: Any] else {
            return
        }
        
        // Look for the camera intrinsic matrix attachment
        // Note: The key is "CameraIntrinsicMatrix" in the attachments
        if let intrinsicMatrixData = attachments["CameraIntrinsicMatrix"] as? Data {
            // Parse the intrinsic matrix (it's a 3x3 matrix as CFData)
            intrinsicMatrixData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                if let baseAddress = ptr.baseAddress, ptr.count >= MemoryLayout<Float>.size * 9 {
                    let matrixPtr = baseAddress.assumingMemoryBound(to: Float.self)
                    
                    // The matrix is stored in column-major order
                    // [ fx  0  cx ]
                    // [ 0  fy  cy ]
                    // [ 0   0   1 ]
                    let fx = CGFloat(matrixPtr[0])
                    let fy = CGFloat(matrixPtr[4])
                    let cx = CGFloat(matrixPtr[2])
                    let cy = CGFloat(matrixPtr[5])
                    
                    // Get the reference dimensions from the format description
                    if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
                        let width = CGFloat(dimensions.width)
                        let height = CGFloat(dimensions.height)
                        
                        // Sanity check: fx and fy should be positive and reasonable
                        guard fx > 0, fy > 0, fx < width * 2, fy < height * 2 else {
                            return  // Invalid calibration data
                        }
                        
                        // Calculate the diagonal FOV from intrinsics
                        let diagonalPixels = sqrt(width * width + height * height)
                        let diagonalFocalLength = sqrt(fx * fx + fy * fy)
                        let diagonalFOV = 2 * atan(diagonalPixels / (2 * diagonalFocalLength))
                        
                        // Sanity check: FOV should be between 10° and 180°
                        let fovDegrees = diagonalFOV * 180 / .pi
                        guard fovDegrees > 10, fovDegrees < 180 else {
                            return  // Invalid FOV
                        }
                        
                        // DEBUG: Print calibration data (throttled to avoid spam)
                        #if DEBUG
                        struct ThrottleState {
                            static var lastPrintTime: TimeInterval = 0
                        }
                        let now = Date().timeIntervalSince1970
                        if now - ThrottleState.lastPrintTime > 2.0 {  // Print every 2 seconds
                            print("📐 Calibration Data from Intrinsic Matrix:")
                            print("  fx=\(String(format: "%.1f", fx)), fy=\(String(format: "%.1f", fy)), cx=\(String(format: "%.1f", cx)), cy=\(String(format: "%.1f", cy))")
                            print("  Dimensions: \(Int(width))×\(Int(height))")
                            print("  Diagonal FOV: \(String(format: "%.2f", fovDegrees))°")
                            ThrottleState.lastPrintTime = now
                        }
                        #endif
                        
                        DispatchQueue.main.async {
                            self.actualDiagonalFOV = diagonalFOV
                        }
                    }
                }
            }
        } else {
            // If intrinsic matrix not available, we rely on the videoFieldOfView fallback
            // which was already set during camera configuration
            #if DEBUG
            struct NoCalibThrottle {
                static var lastPrintTime: TimeInterval = 0
            }
            let now = Date().timeIntervalSince1970
            if now - NoCalibThrottle.lastPrintTime > 5.0 {  // Print every 5 seconds
                print("⚠️ No intrinsic matrix found, using videoFieldOfView fallback: \(String(format: "%.2f", self.actualDiagonalFOV * 180 / .pi))°")
                NoCalibThrottle.lastPrintTime = now
            }
            #endif
        }
    }
}

// MARK: - AVCaptureVideoPreviewLayer Integration

class PreviewViewContainer: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        // Start with .resizeAspectFill as default
        self.videoPreviewLayer.videoGravity = .resizeAspectFill
        self.backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let container: UIView
    let showCropMarks: Bool
    
    func makeUIView(context: Context) -> UIView {
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            let bounds = uiView.bounds
            if bounds.width > 0 && bounds.height > 0 {
                uiView.layer.frame = bounds
            }
            
            // Update video gravity based on crop marks visibility
            if let previewContainer = uiView as? PreviewViewContainer {
                previewContainer.videoPreviewLayer.videoGravity = showCropMarks ? .resizeAspect : .resizeAspectFill
            }
        }
    }
}

// MARK: - Delegate Extensions

extension CameraManager {
    // AVCapturePhotoCaptureDelegate implementation
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            DispatchQueue.main.async {
                self.isCapturing = false
            }
        }
        
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Unable to get image data")
            return
        }
        
        guard let dataWithMetadata = addEXIFMetadata(to: imageData) else {
            print("Failed to add EXIF metadata")
            return
        }
        
        Task { @MainActor in
            guard let modelContext = self.modelContext else {
                print("Model context not available")
                return
            }
            
            let photoAssistant = PhotoAssistant(imageData: dataWithMetadata)
            
            let (location, placemarkInfo) = await self.geocodeManager.processImageLocation(dataWithMetadata)
            
            if let location = location {
                photoAssistant.location = location
            }
            
            if let placemarkInfo = placemarkInfo {
                photoAssistant.placemarkInfo = placemarkInfo
            }
            
            modelContext.insert(photoAssistant)
            
            try? modelContext.save()
            
            print("Photo saved with location: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")
        }
    }
}

extension CameraManager {
    // CLLocationManagerDelegate implementations
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        currentHeading = newHeading
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}

extension AVCaptureDevice.Format {
    /// Approximate 35mm equivalent focal length from field of view (using 36mm horizontal width).
    var approx35mmFocalLength: CGFloat {
        // Use 35mm horizontal width (36.0mm) for the standard reference
        let thirtyFiveMmFilmWidth: CGFloat = 36.0 // 60.0
        
        // Ensure the Float value from AVFoundation is cast to CGFloat
        let fovDegrees: CGFloat = CGFloat(self.videoFieldOfView)

        if fovDegrees > 0 {
            let fovRadians = fovDegrees * .pi / 180.0
            // Formula: F = W / (2 * tan(HFOV/2))
            return thirtyFiveMmFilmWidth / (2 * tan(fovRadians / 2))
        }
        return 0
    }
}

// MARK: - Crop Marks Support Types

// Helper struct for zoom lens UI (distinct from MyGearModel's Lens struct)
struct ZoomLens: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var minFocal: Int
    var maxFocal: Int
}

struct CropMarksOverlay: View {
    // MODIFIED: Accepts individual capture plane dimensions instead of a FilmFormat struct
    let capturePlane: String
    let capturePlaneWidth: Double
    let capturePlaneHeight: Double
    let capturePlaneDiagonal: Double
    
    let selectedFocalLength: Int
    let currentCameraFocalLength: Int
    let isVisible: Bool
    let isZoomLens: Bool
    let actualDiagonalFOV: CGFloat  // NEW: Actual diagonal FOV in radians from the iPhone camera
    let currentZoomFactor: CGFloat  // NEW: Current iPhone zoom factor for calibration lookup
    // MODIFIED: Use a property to hold the default range for visualization
    let defaultZoomRange: (min: Int, max: Int) = (35, 75)
    
    var body: some View {
        if isVisible {
            GeometryReader { geometry in
                let cropFrame = calculateCropFrame(
                    capturePlane: capturePlane,
                    for: selectedFocalLength,
                    cameraFocalLength: currentCameraFocalLength,
                    currentZoomFactor: currentZoomFactor,  // NEW: Pass zoom factor for calibration
                    // MODIFIED: Pass dimensions
                    capturePlaneWidth: capturePlaneWidth,
                    capturePlaneHeight: capturePlaneHeight,
                    capturePlaneDiagonal: capturePlaneDiagonal,
                    in: geometry.size
                )
                
                ZStack {
                    // Semi-transparent overlay to dim the area outside the crop
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .mask(
                            Rectangle()
                                .fill(Color.white)
                                .overlay(
                                    Rectangle()
                                        .frame(width: cropFrame.width, height: cropFrame.height)
                                        .blendMode(.destinationOut)
                                )
                        )
                    
                    // Show zoom range visualization only when zoom lens is selected
                    if isZoomLens {
                        zoomRangeVisualization(geometry: geometry)
                    }
                    
                    // Current focal length crop frame outline - change color based on visibility
                    Rectangle()
                        .stroke(cropFrame.isVisible ? Color.white : Color.red, lineWidth: 2)
                        .frame(width: cropFrame.width, height: cropFrame.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    // Corner marks for current focal length - change color based on visibility
                    Group {
                        cornerMark(at: .topLeading, in: cropFrame, geometry: geometry, isVisible: cropFrame.isVisible)
                        cornerMark(at: .topTrailing, in: cropFrame, geometry: geometry, isVisible: cropFrame.isVisible)
                        cornerMark(at: .bottomLeading, in: cropFrame, geometry: geometry, isVisible: cropFrame.isVisible)
                        cornerMark(at: .bottomTrailing, in: cropFrame, geometry: geometry, isVisible: cropFrame.isVisible)
                    }
                    
                    // Center dot
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 6, height: 6)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    // Status message when crop marks are outside viewfinder
                    if !cropFrame.isVisible {
                        VStack {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Crop marks outside viewfinder")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                    Text(cropFrame.width > geometry.size.width ? "Zoom out or select shorter lens" : "Zoom in or select longer lens")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                                Spacer()
                            }
                            .padding(.top, 140)
                            .padding(.leading, 20)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    private func zoomRangeVisualization(geometry: GeometryProxy) -> some View {
        let minCropFrame = calculateCropFrame(
            capturePlane: capturePlane,
            for: defaultZoomRange.min, // MODIFIED: Use defaultZoomRange
            cameraFocalLength: currentCameraFocalLength,
            currentZoomFactor: currentZoomFactor,  // NEW: Pass zoom factor
            capturePlaneWidth: capturePlaneWidth, // NEW
            capturePlaneHeight: capturePlaneHeight, // NEW
            capturePlaneDiagonal: capturePlaneDiagonal, // NEW
            in: geometry.size
        )
        
        let maxCropFrame = calculateCropFrame(
            capturePlane: capturePlane,
            for: defaultZoomRange.max, // MODIFIED: Use defaultZoomRange
            cameraFocalLength: currentCameraFocalLength,
            currentZoomFactor: currentZoomFactor,  // NEW: Pass zoom factor
            capturePlaneWidth: capturePlaneWidth, // NEW
            capturePlaneHeight: capturePlaneHeight, // NEW
            capturePlaneDiagonal: capturePlaneDiagonal, // NEW
            in: geometry.size
        )
        
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        return ZStack {
            // Outer frame (wide end - 35mm)
            Rectangle()
                .stroke(Color.green.opacity(0.6), lineWidth: 1)
                .frame(width: minCropFrame.width, height: minCropFrame.height)
                .position(x: centerX, y: centerY)
            
            // Inner frame (tele end - 75mm)
            Rectangle()
                .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                .frame(width: maxCropFrame.width, height: maxCropFrame.height)
                .position(x: centerX, y: centerY)
            
            // Corner dots for extreme focal lengths
            Group {
                // Wide end corners (35mm)
                cornerDot(at: .topLeading, frameSize: minCropFrame, geometry: geometry, color: .green)
                cornerDot(at: .topTrailing, frameSize: minCropFrame, geometry: geometry, color: .green)
                cornerDot(at: .bottomLeading, frameSize: minCropFrame, geometry: geometry, color: .green)
                cornerDot(at: .bottomTrailing, frameSize: minCropFrame, geometry: geometry, color: .green)
                
                // Tele end corners (75mm)
                cornerDot(at: .topLeading, frameSize: maxCropFrame, geometry: geometry, color: .blue)
                cornerDot(at: .topTrailing, frameSize: maxCropFrame, geometry: geometry, color: .blue)
                cornerDot(at: .bottomLeading, frameSize: maxCropFrame, geometry: geometry, color: .blue)
                cornerDot(at: .bottomTrailing, frameSize: maxCropFrame, geometry: geometry, color: .blue)
            }
            
            // Focal length labels for extremes
            VStack {
                HStack {
                    Text("\(defaultZoomRange.min)mm") // MODIFIED: Use defaultZoomRange
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .position(x: centerX - minCropFrame.width/2 + 30, y: centerY - minCropFrame.height/2 + 15)
                    
                    Spacer()
                    
                    Text("\(defaultZoomRange.max)mm") // MODIFIED: Use defaultZoomRange
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .position(x: centerX + maxCropFrame.width/2 - 30, y: centerY - maxCropFrame.height/2 + 15)
                }
                
                Spacer()
            }
        }
    }
    
    private func cornerDot(at corner: CornerPosition, frameSize: (width: CGFloat, height: CGFloat, isVisible: Bool), geometry: GeometryProxy, color: Color) -> some View {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        let frameLeft = centerX - frameSize.width / 2
        let frameRight = centerX + frameSize.width / 2
        let frameTop = centerY - frameSize.height / 2
        let frameBottom = centerY + frameSize.height / 2
        
        var x: CGFloat
        var y: CGFloat
        
        switch corner {
        case .topLeading:
            x = frameLeft
            y = frameTop
        case .topTrailing:
            x = frameRight
            y = frameTop
        case .bottomLeading:
            x = frameLeft
            y = frameBottom
        case .bottomTrailing:
            x = frameRight
            y = frameBottom
        }
        
        return Circle()
            .fill(color.opacity(0.8))
            .frame(width: 4, height: 4)
            .position(x: x, y: y)
    }
    
    // MODIFIED: Function signature updated to use dynamic dimensions
    func calculateCropFrame(
        capturePlane: String,
        for focalLength: Int,
        cameraFocalLength: Int,
        currentZoomFactor: CGFloat,  // NEW: iPhone zoom factor for calibration lookup
        capturePlaneWidth: Double,
        capturePlaneHeight: Double,
        capturePlaneDiagonal: Double,
        in screenSize: CGSize
    ) -> (width: CGFloat, height: CGFloat, isVisible: Bool) {
        
        // Basic sanity checks
        guard focalLength > 0,
              cameraFocalLength > 0,
              capturePlaneWidth > 0,
              capturePlaneHeight > 0,
              screenSize.width > 0,
              screenSize.height > 0
        else {
            return (width: 0, height: 0, isVisible: false)
        }
        
        // 1. Physical / optical parameters
        let selectedFocalDouble = Double(focalLength)
        let cameraFocalDouble   = Double(cameraFocalLength)
        
        // Use the provided capturePlaneDiagonal if valid, otherwise compute it
        let captureDiagonal: Double
        if capturePlaneDiagonal > 0 {
            captureDiagonal = capturePlaneDiagonal
        } else {
            captureDiagonal = sqrt(capturePlaneWidth * capturePlaneWidth +
                                   capturePlaneHeight * capturePlaneHeight)
        }
        
        // 2. Determine which capture plane dimension to use based on screen orientation
        // In portrait: screen width is short, so use short capture dimension
        // In landscape: screen width is long, so use long capture dimension
        let isPortrait = screenSize.width < screenSize.height
        
        let captureHorizontalDimension: Double
        let captureVerticalDimension: Double
        
        if isPortrait {
            // Portrait: width is short dimension
            captureHorizontalDimension = min(capturePlaneWidth, capturePlaneHeight)
            captureVerticalDimension = max(capturePlaneWidth, capturePlaneHeight)
        } else {
            // Landscape: width is long dimension
            captureHorizontalDimension = max(capturePlaneWidth, capturePlaneHeight)
            captureVerticalDimension = min(capturePlaneWidth, capturePlaneHeight)
        }
        
        // Calculate FOV based on the horizontal dimension (what actually matters for framing)
        let simulatedHorizontalFovRadians = 2 * atan(captureHorizontalDimension / (2 * selectedFocalDouble))
        
        // Use the iPhone's diagonal FOV (this doesn't change with orientation)
        let iPhoneFovRadians = Double(actualDiagonalFOV)  // Already in radians from videoFieldOfView
        
        #if DEBUG
        // Log the actual FOV values being used for all cameras
        print("🔍 FOV Calculation for \(capturePlane) / \(focalLength)mm:")
        print("  Screen orientation: \(isPortrait ? "Portrait" : "Landscape")")
        print("  Capture horizontal dimension: \(captureHorizontalDimension)mm")
        print("  Capture vertical dimension: \(captureVerticalDimension)mm")
        print("  actualDiagonalFOV (iPhone, radians): \(actualDiagonalFOV)")
        print("  actualDiagonalFOV (iPhone, degrees): \(actualDiagonalFOV * 180 / .pi)")
        print("  simulatedHorizontalFov (radians): \(simulatedHorizontalFovRadians)")
        print("  simulatedHorizontalFov (degrees): \(simulatedHorizontalFovRadians * 180 / .pi)")
        print("  screenSize: \(screenSize)")
        print("  currentZoomFactor: \(currentZoomFactor)x")
        #endif
        
        let simTan   = tan(simulatedHorizontalFovRadians / 2)
        let iphoneTan = tan(iPhoneFovRadians / 2)
        
        guard simTan > 0, iphoneTan > 0 else {
            return (width: 0, height: 0, isVisible: false)
        }
        
        // 3. Geometric scale factor between FOVs
        // > 1  => simulated camera has wider FOV than iPhone (larger crop frame)
        // < 1  => simulated camera has narrower FOV (smaller crop frame)
        let baseScaleFactor = simTan / iphoneTan
        
        // 3.5. Apply calibration correction if available
        // NOTE: Calibration factor represents the systematic error for this iPhone lens + capture plane combo.
        // It should apply to ALL focal lengths used with this combination, since the iPhone's optical
        // characteristics don't change with the simulated focal length.
        let deviceModel = CameraCalibrationManager.shared.deviceModel
        let lensType = formatZoomLevel(currentZoomFactor)  // "0.5x", "1x", "2x", etc.
        
        let finalScaleFactor: Double
        if let calibrationData = CameraCalibrationManager.shared.getCorrectionFactorForCombo(
            deviceModel: deviceModel,
            lensType: lensType,
            capturePlane: capturePlane
        ) {
            let correctionFactor = calibrationData.correctionFactor
            let calibratedFocalLength = calibrationData.focalLength
            finalScaleFactor = baseScaleFactor * correctionFactor
            #if DEBUG
            print("📏 Calibration applied:")
            print("  Device: \(deviceModel)")
            print("  Lens: \(lensType)")
            print("  Capture plane: \(capturePlane)")
            print("  Current focal length: \(focalLength)mm")
            print("  Calibrated at focal length: \(calibratedFocalLength)mm")
            print("  Base scale factor: \(String(format: "%.4f", baseScaleFactor))")
            print("  Correction factor: \(String(format: "%.4f", correctionFactor))")
            print("  Final scale factor: \(String(format: "%.4f", finalScaleFactor))")
            print("  Accuracy adjustment: \(String(format: "%+.1f", (correctionFactor - 1.0) * 100))%")
            print("  ℹ️  This correction applies to all focal lengths for this iPhone/plane combo")
            #endif
        } else {
            finalScaleFactor = baseScaleFactor
            #if DEBUG
            print("ℹ️ No calibration found for: \(deviceModel) / \(lensType) / \(capturePlane)")
            print("  Using uncalibrated scale factor: \(String(format: "%.4f", baseScaleFactor))")
            #endif
        }
        
        // 4. Use the *short* side of the preview as the base dimension
        let previewShort = min(screenSize.width, screenSize.height)
        let previewLong  = max(screenSize.width, screenSize.height)
        
        // 5. Capture frame aspect ratio (long / short)
        let shortCapture = min(capturePlaneWidth, capturePlaneHeight)
        let longCapture  = max(capturePlaneWidth, capturePlaneHeight)
        let aspectRatio  = longCapture / shortCapture  // ≥ 1
        
        // Map diagonal FOV ratio onto the short dimension in screen space
        // Use finalScaleFactor (calibrated if available, otherwise baseScaleFactor)
        var cropShort = previewShort * CGFloat(finalScaleFactor)
        var cropLong  = cropShort * CGFloat(aspectRatio)
        
        // --- DEBUG: log effective capture plane for 6x6 + 80mm only ---
        
#if DEBUG
        let testingDistanceInInches: Double = 36  // 3 feet
        
        logEffectiveCapturePlaneWithDistance(
            cropShort: cropShort,
            previewShort: previewShort,
            focalLength: focalLength,
            distanceInInches: testingDistanceInInches,
            cameraFocalLength: cameraFocalLength,
            capturePlaneName: capturePlane,
            configuredWidth: capturePlaneWidth,
            configuredHeight: capturePlaneHeight,
            configuredDiagonal: capturePlaneDiagonal
        )
#endif
        // --- END DEBUG ---
        
        // 6. Visibility / clamping
        let minCropDisplaySize: CGFloat  = 50.0
        let maxCropDisplayRatio: CGFloat = 1.0   // don’t let crop exceed preview bounds
        
        let isVisibleRaw =
        cropShort >= minCropDisplaySize &&
        cropLong  >= minCropDisplaySize &&
        cropShort <= previewShort * maxCropDisplayRatio &&
        cropLong  <= previewLong  * maxCropDisplayRatio
        
        // Clamp to the actual preview bounds
        cropShort = min(cropShort, previewShort)
        cropLong  = min(cropLong,  previewLong)
        
        // 7. Orient width/height so short ↔ short
        let width: CGFloat
        let height: CGFloat
        if screenSize.width <= screenSize.height {
            // Portrait: width = short side, height = long side
            width  = cropShort
            height = cropLong
        } else {
            // Landscape: width = long side, height = short side
            width  = cropLong
            height = cropShort
        }
        
        return (width: width, height: height, isVisible: isVisibleRaw)
    }
    
    // Helper function to format zoom level consistently with calibration system
    private func formatZoomLevel(_ zoom: CGFloat) -> String {
        // Round to nearest 0.5
        let rounded = round(zoom * 2) / 2
        
        // Format without decimal if it's a whole number
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))x"
        } else {
            return String(format: "%.1fx", rounded)
        }
    }
    
    private func cornerMark(at corner: CornerPosition, in cropFrame: (width: CGFloat, height: CGFloat, isVisible: Bool), geometry: GeometryProxy, isVisible: Bool) -> some View {
        let markLength: CGFloat = 20
        let markThickness: CGFloat = 2
        let markColor = isVisible ? Color.white : Color.red
        
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        let frameLeft = centerX - cropFrame.width / 2
        let frameRight = centerX + cropFrame.width / 2
        let frameTop = centerY - cropFrame.height / 2
        let frameBottom = centerY + cropFrame.height / 2
        
        var x: CGFloat
        var y: CGFloat
        var horizontalAlignment: HorizontalAlignment
        var verticalAlignment: VerticalAlignment
        
        switch corner {
        case .topLeading:
            x = frameLeft
            y = frameTop
            horizontalAlignment = .leading
            verticalAlignment = .top
        case .topTrailing:
            x = frameRight
            y = frameTop
            horizontalAlignment = .trailing
            verticalAlignment = .top
        case .bottomLeading:
            x = frameLeft
            y = frameBottom
            horizontalAlignment = .leading
            verticalAlignment = .bottom
        case .bottomTrailing:
            x = frameRight
            y = frameBottom
            horizontalAlignment = .trailing
            verticalAlignment = .bottom
        }
        
        return VStack(alignment: horizontalAlignment, spacing: 0) {
            if verticalAlignment == .top {
                Rectangle()
                    .fill(markColor)
                    .frame(width: markLength, height: markThickness)
                Rectangle()
                    .fill(markColor)
                    .frame(width: markThickness, height: markLength)
                    .alignmentGuide(.leading) { _ in
                        horizontalAlignment == .leading ? 0 : markThickness - markLength
                    }
            } else {
                Rectangle()
                    .fill(markColor)
                    .frame(width: markThickness, height: markLength)
                    .alignmentGuide(.leading) { _ in
                        horizontalAlignment == .leading ? 0 : markThickness - markLength
                    }
                Rectangle()
                    .fill(markColor)
                    .frame(width: markLength, height: markThickness)
            }
        }
        .position(x: x, y: y)
    }
    
    private func logEffectiveCapturePlaneWithDistance(
        cropShort: CGFloat,
        previewShort: CGFloat,
        focalLength: Int,
        distanceInInches: Double,
        cameraFocalLength: Int,
        capturePlaneName: String,
        configuredWidth: Double,
        configuredHeight: Double,
        configuredDiagonal: Double
    ) {
        guard cropShort > 0,
              previewShort > 0,
              focalLength > 0,
              cameraFocalLength > 0,
              distanceInInches > 0 else {
            print("🔍 [\(capturePlaneName)] Debug: invalid inputs.")
            return
        }
        
        // Convert distance to mm
        let distanceMM = distanceInInches * 25.4
        
        // Ratio between overlay short side and preview short side
        let ratio = Double(cropShort / previewShort)
        
        // iPhone diagonal FOV - USE THE ACTUAL FOV from actualDiagonalFOV
        let iphoneFovDiag = Double(actualDiagonalFOV)  // Already in radians
        let iphoneTan = tan(iphoneFovDiag / 2.0)
        
        // Simulated FOV (diagonal) inferred from crop ratio
        let simTan = ratio * iphoneTan
        let simFovDiag = 2.0 * atan(simTan)
        
        // Effective diagonal from FOV + focal length
        let fSim = Double(focalLength)
        let effectiveDiagonal = 2.0 * fSim * tan(simFovDiag / 2.0)
        
        // Actual configured diagonal
        let cfgDiag = configuredDiagonal > 0
            ? configuredDiagonal
            : hypot(configuredWidth, configuredHeight)
        
        let scale = effectiveDiagonal / cfgDiag
        let effectiveWidthMM  = configuredWidth  * scale
        let effectiveHeightMM = configuredHeight * scale
        
        // Convert mm → inches
        let effWidthIn   = mmToInches(effectiveWidthMM)
        let effHeightIn  = mmToInches(effectiveHeightMM)
        let effDiagIn    = mmToInches(effectiveDiagonal)
        
        let cfgWidthIn   = mmToInches(configuredWidth)
        let cfgHeightIn  = mmToInches(configuredHeight)
        let cfgDiagIn    = mmToInches(cfgDiag)
        
        // Expected physical HORIZONTAL & VERTICAL field at this distance
        // For a square 6x6 format, width = height, so we calculate based on width
        //
        // HFOVw = 2 * atan( (sensorWidth / 2)  / f )
        let hfovWidth  = 2.0 * atan((configuredWidth  / 2.0) / fSim)
        let hfovHeight = 2.0 * atan((configuredHeight / 2.0) / fSim)
        
        let expectedWidthMM  = 2.0 * distanceMM * tan(hfovWidth  / 2.0)
        let expectedHeightMM = 2.0 * distanceMM * tan(hfovHeight / 2.0)
        
        let expectedWidthIn  = mmToInches(expectedWidthMM)
        let expectedHeightIn = mmToInches(expectedHeightMM)
        
        // Also calculate diagonal field for reference
        let diagonalFOV = 2.0 * atan(cfgDiag / (2.0 * fSim))
        let expectedDiagonalMM = 2.0 * distanceMM * tan(diagonalFOV / 2.0)
        let expectedDiagonalIn = mmToInches(expectedDiagonalMM)
        
        // Observed horizontal & vertical field (from effective size)
        let effHfovWidth  = 2.0 * atan((effectiveWidthMM  / 2.0) / fSim)
        let effHfovHeight = 2.0 * atan((effectiveHeightMM / 2.0) / fSim)
        
        let observedWidthMM  = 2.0 * distanceMM * tan(effHfovWidth  / 2.0)
        let observedHeightMM = 2.0 * distanceMM * tan(effHfovHeight / 2.0)
        
        let observedWidthIn  = mmToInches(observedWidthMM)
        let observedHeightIn = mmToInches(observedHeightMM)
        
        print("""
        
        📷 DEBUG: \(capturePlaneName) with \(focalLength)mm at \(distanceInInches) inches
        ------------------------------------------------------------
        
        CONFIGURED CAPTURE PLANE:
          width   = \(configuredWidth) mm  (\(formatInches(cfgWidthIn)))
          height  = \(configuredHeight) mm (\(formatInches(cfgHeightIn)))
          diagonal= \(cfgDiag) mm          (\(formatInches(cfgDiagIn)))
        
        EFFECTIVE (from overlay at this distance):
          eff width   = \(effectiveWidthMM) mm  (\(formatInches(effWidthIn)), \(formatFeetInches(effWidthIn)))
          eff height  = \(effectiveHeightMM) mm (\(formatInches(effHeightIn)), \(formatFeetInches(effHeightIn)))
          eff diagonal= \(effectiveDiagonal) mm (\(formatInches(effDiagIn)))
        
        FIELD AT DISTANCE \(distanceInInches) in (\(distanceMM) mm):
          Horizontal width  = \(formatInches(expectedWidthIn))  (\(formatFeetInches(expectedWidthIn)))
          Vertical height   = \(formatInches(expectedHeightIn)) (\(formatFeetInches(expectedHeightIn)))
          Diagonal distance = \(formatInches(expectedDiagonalIn)) (\(formatFeetInches(expectedDiagonalIn)))
        
        FOV ANGLES:
          Horizontal FOV = \((hfovWidth * 180.0 / .pi))°
          Vertical FOV   = \((hfovHeight * 180.0 / .pi))°
          Diagonal FOV   = \((diagonalFOV * 180.0 / .pi))°
        
        CROP MARKS:
          ratio cropShort/previewShort = \(ratio)
          iPhone FOV diag (deg)        = \((iphoneFovDiag * 180.0 / .pi))
          Film FOV diag (deg)          = \((diagonalFOV * 180.0 / .pi))
        
        ------------------------------------------------------------
        """)
    }

    
    private func mmToInches(_ mm: Double) -> Double {
        mm / 25.4
    }

    private func formatInches(_ inches: Double) -> String {
        String(format: "%.2f in", inches)
    }

    private func formatFeetInches(_ inches: Double) -> String {
        let feet = Int(inches / 12.0)
        let leftover = inches - Double(feet) * 12.0
        return String(format: "%d ft %.2f in", feet, leftover)
    }
}

struct CropMarksControlPanel: View {
    // NEW: Accept gear list and selected gear
    let gearList: [MyGearModel]
    @Binding var selectedGear: MyGearModel?
    
    @Binding var selectedFocalLength: Int
    let currentCameraFocalLength: Int
    @Binding var showCropMarks: Bool
    
    // MODIFIED: Compute available lenses from selected gear instead of hardcoding
    private var availableFixedLenses: [Int] {
        guard let gear = selectedGear else { return [] }
        return gear.lenses.filter { $0.type == .prime }.compactMap { $0.primeFocalLength }
    }
    
    // MODIFIED: Compute available zoom lenses from selected gear
    private var availableZoomLenses: [ZoomLens] {
        guard let gear = selectedGear else { return [] }
        return gear.lenses.filter { $0.type == .zoom && $0.zoomRange != nil }.map { lens in
            ZoomLens(
                name: lens.name,
                minFocal: lens.zoomRange!.min,
                maxFocal: lens.zoomRange!.max
            )
        }
    }
    
    // MODIFIED: Tracks the currently selected zoom lens object, if any
    @State private var selectedZoomLens: ZoomLens? = nil

    // MARK: - Extracted Sub-Views for Compiler Stability

    @ViewBuilder
    private var cameraPickerView: some View {
        VStack(spacing: 8) {
            /*
            HStack {
                Text("Camera:")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
            */
            
            Picker("Select Camera", selection: $selectedGear) {
                ForEach(gearList) { gear in
                    Text(gear.cameraName)
                        .tag(gear as MyGearModel?)
                }
            }
            .pickerStyle(.menu)
            .accentColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .onChange(of: selectedGear) { oldValue, newValue in
                // When camera changes, reset to first available prime lens or first lens
                if let gear = newValue {
                    if let firstPrime = gear.lenses.first(where: { $0.type == .prime })?.primeFocalLength {
                        selectedFocalLength = firstPrime
                    } else if let firstLens = gear.lenses.first {
                        // If no prime lens, try zoom lens
                        if firstLens.type == .zoom, let range = firstLens.zoomRange {
                            selectedFocalLength = Int(round(Double(range.min + range.max) / 2.0))
                        }
                    }
                    // Reset zoom lens selection
                    selectedZoomLens = nil
                    // Keep crop marks visible if they were visible
                    if showCropMarks {
                        withAnimation { showCropMarks = true }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var currentCameraInfoView: some View {
        HStack(spacing: 8) {
            Text("Phone:")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
            
            Text("\(currentCameraFocalLength)mm")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.yellow)
            
            Spacer()
            
            Text("FOV: \(Int(fieldOfView(for: currentCameraFocalLength)))°")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    @ViewBuilder
    private var lensButtonsView: some View {
        HStack(spacing: 8) {
            // Fixed focal length lenses
            ForEach(availableFixedLenses, id: \.self) { focalLength in
                fixedLensButton(focalLength: focalLength)
            }
            
            // Zoom lenses
            ForEach(availableZoomLenses) { zoom in
                zoomLensButton(zoom: zoom)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func fixedLensButton(focalLength: Int) -> some View {
        let isSelected = (selectedZoomLens == nil && selectedFocalLength == focalLength && showCropMarks)
        
        Button(action: {
            if isSelected {
                // Tapping the currently selected fixed lens: Turn OFF marks
                withAnimation { showCropMarks = false }
            } else {
                // Tapping a new fixed lens: Turn ON marks
                selectedFocalLength = focalLength
                selectedZoomLens = nil // Ensure no zoom lens is active
                withAnimation { showCropMarks = true }
            }
        }) {
            Text("\(focalLength)mm")
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(12)
        }
        .onTapGesture {
            // Prevent panel tap when selecting lens
        }
    }
    
    @ViewBuilder
    private func zoomLensButton(zoom: ZoomLens) -> some View {
        let isSelected = (selectedZoomLens == zoom && showCropMarks)
        
        Button(action: {
            if isSelected {
                // Tapping the currently selected zoom lens: Turn OFF marks
                withAnimation {
                    showCropMarks = false
                    selectedZoomLens = nil
                }
            } else {
                // Tapping to select zoom lens: Turn ON marks
                selectedZoomLens = zoom
                // Set to middle of zoom range
                selectedFocalLength = Int(round(Double(zoom.minFocal + zoom.maxFocal) / 2.0))
                withAnimation { showCropMarks = true }
            }
        }) {
            Text(zoom.name)
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(12)
        }
        .onTapGesture {
            // Prevent panel tap when selecting zoom lens
        }
    }

    @ViewBuilder
    private var zoomSliderView: some View {
        // Zoom slider (only show when a zoom lens is selected)
        if let activeZoomLens = selectedZoomLens {
            VStack(spacing: 4) {
                HStack {
                    Text("\(activeZoomLens.minFocal)mm")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("\(selectedFocalLength)mm")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("\(activeZoomLens.maxFocal)mm")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Slider(
                    value: Binding(
                        get: { Double(selectedFocalLength) },
                        set: {
                            selectedFocalLength = Int($0)
                            // Ensure marks are visible when the slider is dragged
                            if !showCropMarks {
                                withAnimation { showCropMarks = true }
                            }
                        }
                    ),
                    in: Double(activeZoomLens.minFocal)...Double(activeZoomLens.maxFocal),
                    step: 5
                )
                .accentColor(.white)
                .onTapGesture {
                    // Prevent panel tap when using slider
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .onTapGesture {
                // Prevent panel tap when interacting with zoom controls
            }
        }
    }
    
    @ViewBuilder
    private var formatInfoView: some View {
        HStack {
            Text(selectedGear?.capturePlane ?? "6x6 cm (120 Film)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text("Target FOV: \(Int(fieldOfView(for: selectedFocalLength)))°")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            cameraPickerView
            
            currentCameraInfoView
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(spacing: 8) {
                HStack {
                    Text("Lens Selection:")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                
                lensButtonsView
                
                zoomSliderView
            }
            
            formatInfoView

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        //.background(Color.black.opacity(0.7))
        //.background(Color(red: 0xa1/255, green: 0x03/255, blue: 0x03/255).opacity(0.9))
        .background(Color(red: 0x2e/255, green: 0x2e/255, blue: 0x2e/255).opacity(0.9))
        .cornerRadius(12)
        .onAppear {
            // Initialize selectedZoomLens state based on current selection
            if let initialZoomLens = availableZoomLenses.first(where: {
                selectedFocalLength >= $0.minFocal && selectedFocalLength <= $0.maxFocal
            }) {
                selectedZoomLens = initialZoomLens
            }
        }
    }
    
    private func fieldOfView(for focalLength: Int) -> Double {
        // Calculate field of view using the selected gear's diagonal
        guard let gear = selectedGear else {
            // Fallback to 6x6 format diagonal
            let filmDiagonal: Double = 84.85
            let fovRadians = 2 * atan(filmDiagonal / (2 * Double(focalLength)))
            return fovRadians * 180 / .pi
        }
        
        let filmDiagonal: Double = gear.capturePlaneDiagonal
        let fovRadians = 2 * atan(filmDiagonal / (2 * Double(focalLength)))
        return fovRadians * 180 / .pi // Convert to degrees
    }
}
