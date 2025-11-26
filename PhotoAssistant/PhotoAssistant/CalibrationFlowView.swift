import SwiftUI
import AVFoundation
import Combine
import ARKit

struct CalibrationFlowView: View {
    @ObservedObject var session: CalibrationSession
    @Binding var isPresented: Bool
    @State private var showingCancelAlert = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                
                // Content based on step
                switch session.step {
                case .selectCamera:
                    SelectCameraStep(session: session)
                case .selectLens:
                    SelectiPhoneLensStep(session: session)
                case .measureObject:
                    MeasureObjectStep(session: session)
                case .frameObject:
                    FrameObjectStep(session: session)
                case .measureDistance:
                    MeasureDistanceStep(session: session)
                case .review:
                    ReviewStep(session: session)
                case .complete:
                    CompleteStep(session: session, isPresented: $isPresented)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    showingCancelAlert = true
                }
            }
        }
        .alert("Cancel Calibration?", isPresented: $showingCancelAlert) {
            Button("Continue Calibrating", role: .cancel) {}
            Button("Cancel", role: .destructive) {
                isPresented = false
            }
        }
    }
    
    var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * progressPercentage)
            }
        }
        .frame(height: 4)
    }
    
    var progressPercentage: CGFloat {
        switch session.step {
        case .selectCamera: return 0.0
        case .selectLens: return 0.16
        case .measureObject: return 0.33
        case .frameObject: return 0.5
        case .measureDistance: return 0.66
        case .review: return 0.83
        case .complete: return 1.0
        @unknown default: return 0.0
        }
    }
}

// MARK: - Step 1: Select Camera

struct SelectCameraStep: View {
    @ObservedObject var session: CalibrationSession
    @State private var cameras: [MyGearModel] = []
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "camera.metering.center.weighted")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Select Your Camera")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Choose which camera you're calibrating for")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                if cameras.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No cameras in your gear")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Add cameras in 'Manage My Gear' first")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(cameras) { camera in
                                Button(action: {
                                    session.selectedCamera = camera
                                    session.selectedCapturePlane = camera.capturePlane
                                    withAnimation {
                                        session.step = .selectLens
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(camera.cameraName)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text(camera.capturePlane)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        Text("\(camera.lenses.count) lens\(camera.lenses.count == 1 ? "" : "es")")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            cameras = MyGearModel.loadGearList()
        }
    }
}

// MARK: - Step 2: Select iPhone Lens

struct SelectiPhoneLensStep: View {
    @ObservedObject var session: CalibrationSession
    
    let lenses: [(String, CGFloat)] = [
        ("0.5x Ultra-Wide", 0.5),
        ("1x Wide", 1.0),
        ("2x Telephoto", 2.0),
        ("3x Telephoto", 3.0)
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Select iPhone Lens")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Choose which iPhone lens to calibrate")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    if let camera = session.selectedCamera {
                        Text("for \(camera.cameraName)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                VStack(spacing: 16) {
                    ForEach(lenses, id: \.0) { lens in
                        Button(action: {
                            selectiPhoneLens(lens)
                        }) {
                            HStack {
                                Image(systemName: "camera")
                                    .foregroundColor(.white)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lens.0)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    if let camera = session.selectedCamera,
                                       let suggestedFocal = session.getSuggestedFocalLength(for: String(lens.0.prefix(3)), camera: camera) {
                                        Text("Will use \(suggestedFocal)mm lens")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Button(action: {
                    withAnimation {
                        session.step = .selectCamera
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 32)
                
                Spacer()
            }
        }
    }
    
    func selectiPhoneLens(_ lens: (String, CGFloat)) {
        session.selectedLensType = lens.0.components(separatedBy: " ").first ?? "1x"
        session.selectedZoomFactor = lens.1
        
        // Auto-select appropriate focal length for this iPhone lens
        if let camera = session.selectedCamera {
            if let suggestedFocal = session.getSuggestedFocalLength(for: session.selectedLensType, camera: camera) {
                session.selectedFocalLength = suggestedFocal
            }
        }
        
        withAnimation {
            session.step = .measureObject
        }
    }
}

struct MeasureObjectStep: View {
    @ObservedObject var session: CalibrationSession
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "ruler")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Measure Reference Object")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Find a large, flat object with a known width (like a wall, door, or shed)")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Object Width (inches)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("e.g., 96", text: $session.measuredObjectSize)
                            .keyboardType(.decimalPad)
                            .focused($isInputFocused)
                            .padding()
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .font(.title2)
                    }
                    
                    Text("💡 Tip: Larger objects (60+ inches) provide better calibration accuracy")
                        .font(.caption)
                        .foregroundColor(.yellow)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation {
                            session.step = .selectLens
                        }
                    }) {
                        Text("Back")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        isInputFocused = false
                        withAnimation {
                            session.step = .frameObject
                        }
                    }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canProceed ? Color.blue : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!canProceed)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
    }
    
    var canProceed: Bool {
        guard let value = Double(session.measuredObjectSize) else { return false }
        return value > 0
    }
}

// MARK: - Step 4: Frame Object (Camera View)

struct FrameObjectStep: View {
    @ObservedObject var session: CalibrationSession
    @State private var showingInstructions = true
    
    var hasLiDAR: Bool {
        return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
    
    var body: some View {
        ZStack {
            // Always use CameraView for crop marks (they work correctly)
            CameraView(
                isCalibrationMode: true,
                calibrationCapturePlane: session.selectedCamera?.capturePlane ?? "",
                calibrationWidth: session.selectedCamera?.capturePlaneWidth ?? 60,
                calibrationHeight: session.selectedCamera?.capturePlaneHeight ?? 60,
                calibrationDiagonal: session.selectedCamera?.capturePlaneDiagonal ?? 0,
                calibrationFocalLength: session.selectedFocalLength,
                calibrationZoom: session.selectedZoomFactor
            )
            .ignoresSafeArea()
            
            // Instructions overlay
            if showingInstructions {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("Position your iPhone so the white crop marks frame your measured object edge-to-edge")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("The object should fill the crop marks completely")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        if hasLiDAR {
                            Text("📡 If your iPhone has LiDAR, the distance will be measured automatically in the next step.")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        } else {
                            Text("📝 You'll enter the shooting distance manually in the next step.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.top, 8)
                        }
                        
                        Button(action: {
                            showingInstructions = false
                        }) {
                            Text("Got It")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(16)
                    .padding()
                }
            }
            
            // Calibration shutter button
            if !showingInstructions {
                VStack {
                    Spacer()
                    
                    Button(action: {
                        captureCalibrationFrame()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(hasLiDAR ? Color.green : Color.white, lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                )
                            
                            if hasLiDAR {
                                Image(systemName: "laser.burst")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            print("📸 Calibration mode activated")
            print("   Camera: \(session.selectedCamera?.cameraName ?? "Unknown")")
            print("   Capture plane: \(session.selectedCamera?.capturePlane ?? "Unknown")")
            print("   Focal length: \(session.selectedFocalLength)mm")
            print("   iPhone lens: \(session.selectedLensType) (\(session.selectedZoomFactor)x)")
        }
    }
    
    func captureCalibrationFrame() {
        // CRITICAL: Get the calculated field size from CameraView
        // This is the horizontal field width that the crop marks represent
        
        // TEMPORARY PLACEHOLDER - You need to replace this!
        // Get this value from your actual CameraView calculation
        session.calculatedFieldSize = 45.0
        
        print("📏 Calibration frame captured")
        print("   Format: \(session.selectedCamera?.capturePlane ?? "Unknown")")
        print("   Focal length: \(session.selectedFocalLength)mm")
        print("   iPhone lens: \(session.selectedLensType)")
        print("   ⚠️  Calculated field size: \(session.calculatedFieldSize) inches (PLACEHOLDER - needs real value!)")
        print("   👆 This value must come from CameraView's FOV calculation!")
        
        withAnimation {
            session.step = .measureDistance
        }
    }
}

// MARK: - AR Camera View Container (still available for future AR-based UI)

struct ARCameraViewContainer: UIViewRepresentable {
    @ObservedObject var lidarManager: LiDARManager
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        
        // Ensure we use the LiDAR manager's session
        if let session = lidarManager.arSession {
            arView.session = session
        }
        
        // Show camera feed
        arView.scene = SCNScene()
        
        // Enable default lighting
        arView.autoenablesDefaultLighting = true
        arView.automaticallyUpdatesLighting = true
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Update session if needed
        if let session = lidarManager.arSession, uiView.session != session {
            uiView.session = session
        }
    }
}

// MARK: - Crop Marks for AR View (unused in current flow but kept)

struct CropMarksForARView: View {
    let capturePlane: String
    let capturePlaneWidth: Double
    let capturePlaneHeight: Double
    let capturePlaneDiagonal: Double
    let focalLength: Int
    let iPhoneZoom: CGFloat
    @ObservedObject var lidarManager: LiDARManager
    
    var body: some View {
        GeometryReader { geometry in
            CropMarksContent(
                screenWidth: geometry.size.width,
                screenHeight: geometry.size.height,
                capturePlane: capturePlane,
                capturePlaneWidth: capturePlaneWidth,
                capturePlaneHeight: capturePlaneHeight,
                capturePlaneDiagonal: capturePlaneDiagonal,
                focalLength: focalLength,
                actualDiagonalFOV: lidarManager.actualDiagonalFOV
            )
        }
    }
}

struct CropMarksContent: View {
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let capturePlane: String
    let capturePlaneWidth: Double
    let capturePlaneHeight: Double
    let capturePlaneDiagonal: Double
    let focalLength: Int
    let actualDiagonalFOV: Double? // From ARKit camera intrinsics
    
    var body: some View {
        let cropFrame = calculateCropFrame()
        
        ZStack {
            if actualDiagonalFOV != nil {
                if cropFrame.isVisible {
                    // Draw crop marks rectangle
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropFrame.width, height: cropFrame.height)
                        .position(x: screenWidth / 2, y: screenHeight / 2)
                    
                    // Corner markers
                    cornerMarkers(cropFrame: cropFrame)
                    
                    // Label
                    Text("\(capturePlane) / \(focalLength)mm")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .position(x: screenWidth / 2, y: screenHeight - 100)
                } else {
                    // Show message if crop marks don't fit
                    Text("Crop marks too large for screen")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .position(x: screenWidth / 2, y: screenHeight / 2)
                }
            } else {
                // Waiting for FOV data
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Calculating camera FOV...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .position(x: screenWidth / 2, y: screenHeight / 2)
            }
        }
    }
    
    @ViewBuilder
    func cornerMarkers(cropFrame: (width: CGFloat, height: CGFloat, isVisible: Bool)) -> some View {
        Group {
            CornerMarker(position: .topLeading)
                .position(
                    x: (screenWidth - cropFrame.width) / 2,
                    y: (screenHeight - cropFrame.height) / 2
                )
            CornerMarker(position: .topTrailing)
                .position(
                    x: (screenWidth + cropFrame.width) / 2,
                    y: (screenHeight - cropFrame.height) / 2
                )
            CornerMarker(position: .bottomLeading)
                .position(
                    x: (screenWidth - cropFrame.width) / 2,
                    y: (screenHeight + cropFrame.height) / 2
                )
            CornerMarker(position: .bottomTrailing)
                .position(
                    x: (screenWidth + cropFrame.width) / 2,
                    y: (screenHeight + cropFrame.height) / 2
                )
        }
    }
    
    func calculateCropFrame() -> (width: CGFloat, height: CGFloat, isVisible: Bool) {
        
        // Use actual diagonal FOV from ARKit, or return not visible if not available yet
        guard let iPhoneDiagonalFOV = actualDiagonalFOV else {
            return (0, 0, false)
        }
        
        // Calculate the capture plane's diagonal FOV
        let capturePlaneDiagonalFOV = 2.0 * atan((capturePlaneDiagonal / 2.0) / Double(focalLength)) * (180.0 / .pi)
        
        // Calculate the ratio of FOVs
        let fovRatio = capturePlaneDiagonalFOV / iPhoneDiagonalFOV
        
        // Calculate screen diagonal
        let screenDiagonal = sqrt(screenWidth * screenWidth + screenHeight * screenHeight)
        
        // Calculate crop frame diagonal
        let cropDiagonal = screenDiagonal * CGFloat(fovRatio)
        
        // Calculate crop frame dimensions maintaining aspect ratio
        let aspectRatio = capturePlaneWidth / capturePlaneHeight
        let cropHeight = cropDiagonal / sqrt(1 + aspectRatio * aspectRatio)
        let cropWidth = cropHeight * CGFloat(aspectRatio)
        
        // Check if visible
        let isVisible = cropWidth <= screenWidth && cropHeight <= screenHeight
        
        // Debug output
        print("📐 Crop Mark Calculation (AR):")
        print("   iPhone diagonal FOV: \(String(format: "%.2f", iPhoneDiagonalFOV))°")
        print("   Capture plane diagonal FOV: \(String(format: "%.2f", capturePlaneDiagonalFOV))°")
        print("   FOV ratio: \(String(format: "%.4f", fovRatio))")
        print("   Screen: \(Int(screenWidth)) × \(Int(screenHeight))")
        print("   Crop: \(Int(cropWidth)) × \(Int(cropHeight))")
        print("   Visible: \(isVisible)")
        
        return (cropWidth, cropHeight, isVisible)
    }
}

// Simple corner marker
struct CornerMarker: View {
    let position: CornerPosition
    let lineLength: CGFloat = 20
    let lineWidth: CGFloat = 2
    
    var body: some View {
        markerPath
            .stroke(Color.white, lineWidth: lineWidth)
    }
    
    var markerPath: Path {
        var path = Path()
        
        switch position {
        case .topLeading:
            path.move(to: CGPoint(x: 0, y: lineLength))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: lineLength, y: 0))
            
        case .topTrailing:
            path.move(to: CGPoint(x: -lineLength, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: lineLength))
            
        case .bottomLeading:
            path.move(to: CGPoint(x: 0, y: -lineLength))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: lineLength, y: 0))
            
        case .bottomTrailing:
            path.move(to: CGPoint(x: -lineLength, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -lineLength))
        }
        
        return path
    }
}

// MARK: - Step 5: Measure Distance

struct MeasureDistanceStep: View {
    @ObservedObject var session: CalibrationSession
    @StateObject private var lidarManager = LiDARManager()
    @FocusState private var isInputFocused: Bool
    @State private var isLiDARMeasuring: Bool = false
    @State private var lidarError: String? = nil
    
    var hasLiDAR: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                let isUsingLiDAR = session.distanceMode == .lidar
                let hasLiDARDistance = session.useAutoDistance && session.autoDistance != nil
                
                VStack(spacing: 16) {
                    Image(systemName: isUsingLiDAR ? "checkmark.circle.fill" : "ruler.fill")
                        .font(.system(size: 80))
                        .foregroundColor(isUsingLiDAR && hasLiDARDistance ? .green : .blue)
                    
                    Text(isUsingLiDAR
                         ? (hasLiDARDistance ? "Distance Captured!" : "Measuring Distance")
                         : "Enter Distance")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if isUsingLiDAR {
                        if hasLiDARDistance {
                            Text("LiDAR measured the distance to your object automatically.")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Hold still while LiDAR measures the distance to your object.")
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        Text("How far were you from the object?")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let lidarError = lidarError {
                        Text(lidarError)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                
                VStack(spacing: 24) {
                    if session.distanceMode == .lidar && session.autoDistance != nil && session.useAutoDistance {
                        // Show captured LiDAR distance
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text("Measured Distance")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                Text(String(format: "%.1f inches", session.autoDistance!))
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(String(format: "%.1f feet", session.autoDistance! / 12.0))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(16)
                            
                            Button(action: {
                                // Allow manual override
                                lidarManager.stopMeasuring()
                                isLiDARMeasuring = false
                                session.useAutoDistance = false
                                session.autoDistance = nil
                                session.distanceMode = .manual
                            }) {
                                Text("Enter Manually Instead")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    } else if session.distanceMode == .lidar && isLiDARMeasuring {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(.green)
                            Text("Measuring distance...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Button(action: {
                                // Cancel LiDAR, switch to manual
                                lidarManager.stopMeasuring()
                                isLiDARMeasuring = false
                                session.distanceMode = .manual
                                session.useAutoDistance = false
                            }) {
                                Text("Enter Manually Instead")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                    } else {
                        // Manual entry
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distance (inches)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("e.g., 36", text: $session.measuredDistance)
                                .keyboardType(.decimalPad)
                                .focused($isInputFocused)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .font(.title2)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: {
                        // 🔄 Reset LiDAR so coming back will force a new reading
                        session.autoDistance = nil
                        session.useAutoDistance = false
                        session.distanceMode = .lidar   // or .manual if you want manual by default
                        lidarManager.stopMeasuring()

                        withAnimation {
                            session.step = .frameObject
                        }
                    }) {
                        Text("Back")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        isInputFocused = false
                        withAnimation {
                            session.step = .review
                        }
                    }) {
                        Text("Next")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canProceed ? Color.blue : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!canProceed)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        .onAppear {
            startLiDARMeasurementIfNeeded()
        }
        .onDisappear {
            lidarManager.stopMeasuring()
            isLiDARMeasuring = false
        }
    }
    
    func startLiDARMeasurementIfNeeded() {
        guard hasLiDAR else {
            session.distanceMode = .manual
            return
        }
        
        // If we already have a LiDAR reading we're using, just show it
        if session.useAutoDistance, let distance = session.autoDistance, distance > 0 {
            session.distanceMode = .lidar
            return
        }
        
        // Start a new single-shot measurement if we don't have one yet
        if !isLiDARMeasuring && session.autoDistance == nil {
            session.distanceMode = .lidar
            session.useAutoDistance = false
            isLiDARMeasuring = true
            lidarError = nil
            
            lidarManager.startSingleShotMeasurement { distance in
                DispatchQueue.main.async {
                    self.isLiDARMeasuring = false
                    
                    if let distance = distance, distance > 0 {
                        self.session.autoDistance = distance
                        self.session.useAutoDistance = true
                        self.session.distanceMode = .lidar
                        print("📡 LiDAR single-shot distance: \(String(format: "%.1f", distance)) inches")
                    } else {
                        self.session.distanceMode = .manual
                        self.session.useAutoDistance = false
                        self.lidarError = "LiDAR could not get a reliable reading. Please enter the distance manually."
                        print("⚠️ LiDAR single-shot measurement failed or was invalid.")
                    }
                }
            }
        }
    }
    
    var canProceed: Bool {
        if session.useAutoDistance {
            return session.autoDistance != nil && session.autoDistance! > 0
        } else {
            guard let value = Double(session.measuredDistance) else { return false }
            return value > 0
        }
    }
}

// MARK: - Step 6: Review

struct ReviewStep: View {
    @ObservedObject var session: CalibrationSession
    @State private var showingNotes = false
    
    var correctionFactor: Double {
        guard let objectSize = Double(session.measuredObjectSize) else { return 1.0 }
        return objectSize / session.calculatedFieldSize
    }
    
    var accuracyPercentage: Double {
        return (correctionFactor - 1.0) * 100.0
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("Review Calibration")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 32)
                    
                    VStack(spacing: 20) {
                        ReviewRow(label: "Camera Lens", value: session.selectedLensType)
                        ReviewRow(label: "Format", value: session.selectedCapturePlane)
                        ReviewRow(label: "Focal Length", value: "\(session.selectedFocalLength)mm")
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        ReviewRow(label: "Object Size", value: "\(session.measuredObjectSize) in")
                        ReviewRow(label: "Distance", value: String(format: "%.1f in", session.finalDistance ?? 0))
                        ReviewRow(label: "Calculated Field", value: String(format: "%.2f in", session.calculatedFieldSize))
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        VStack(spacing: 8) {
                            Text("Correction Factor")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text(String(format: "%.4f", correctionFactor))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("\(accuracyPercentage > 0 ? "+" : "")\(String(format: "%.1f", accuracyPercentage))% adjustment")
                                .font(.subheadline)
                                .foregroundColor(abs(accuracyPercentage) < 5 ? .green : .orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(16)
                        
                        Button(action: {
                            showingNotes.toggle()
                        }) {
                            Label("Add Notes (Optional)", systemImage: "note.text")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        if showingNotes {
                            TextEditor(text: $session.notes)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation {
                                session.step = .measureDistance
                            }
                        }) {
                            Text("Back")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            saveCalibration()
                        }) {
                            Text("Save Calibration")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    func saveCalibration() {
        guard let calibration = session.createCalibration() else { return }
        CameraCalibrationManager.shared.addCalibration(calibration)
        
        withAnimation {
            session.step = .complete
        }
    }
}

struct ReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .font(.body)
    }
}

// MARK: - Step 7: Complete

struct CompleteStep: View {
    @ObservedObject var session: CalibrationSession
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.green)
                    
                    Text("Calibration Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Your \(session.selectedLensType) camera is now calibrated for \(session.selectedCapturePlane)")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        session.reset()
                        session.step = .selectLens
                    }) {
                        Text("Calibrate Another Lens")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Done")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - LiDAR Manager (with single-shot distance mode)

class LiDARManager: NSObject, ObservableObject, ARSessionDelegate {
    enum Mode {
        case idle
        case continuous
        case singleShot
    }
    
    @Published var measuredDistance: Double? = nil
    @Published var actualDiagonalFOV: Double? = nil // In degrees
    
    fileprivate(set) var mode: Mode = .idle
    var arSession: ARSession?
    
    private var singleShotCompletion: ((Double?) -> Void)?
    private var singleShotSamples: [Double] = []
    private let maxSingleShotSamples = 8
    
    override init() {
        super.init()
    }
    
    /// Legacy continuous-measurement API (kept for compatibility)
    @available(*, deprecated, message: "Use startContinuousMeasuring or startSingleShotMeasurement instead.")
    func startMeasuring(preferredZoom: CGFloat = 1.0) {
        startContinuousMeasuring(preferredZoom: preferredZoom)
    }
    
    /// Continuous LiDAR measurement (updates `measuredDistance` live).
    func startContinuousMeasuring(preferredZoom: CGFloat = 1.0) {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("❌ LiDAR not supported on this device")
            return
        }
        
        stopMeasuring()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.frameSemantics = .sceneDepth
        
        print("📸 ARKit starting continuous measurement with default wide camera")
        
        let session = ARSession()
        session.delegate = self
        session.run(configuration)
        
        self.arSession = session
        self.mode = .continuous
        self.measuredDistance = nil
        
        print("📡 LiDAR continuous measurement started")
    }
    
    /// Single-shot measurement: runs ARKit briefly, collects several samples, averages them, then stops.
    func startSingleShotMeasurement(preferredZoom: CGFloat = 1.0,
                                    completion: @escaping (Double?) -> Void) {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("❌ LiDAR not supported on this device")
            completion(nil)
            return
        }
        
        stopMeasuring()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.frameSemantics = .sceneDepth
        
        print("📸 ARKit starting single-shot measurement with default wide camera")
        
        let session = ARSession()
        session.delegate = self
        session.run(configuration)
        
        self.arSession = session
        self.mode = .singleShot
        self.singleShotCompletion = completion
        self.singleShotSamples.removeAll()
        self.measuredDistance = nil
        
        print("📡 LiDAR single-shot measurement started")
    }
    
    func stopMeasuring() {
        arSession?.pause()
        arSession = nil
        mode = .idle
        print("📡 LiDAR measurement stopped")
    }
    
    private func handleDepthSample(_ depthInInches: Double) {
        self.measuredDistance = depthInInches
        
        guard mode == .singleShot else { return }
        
        singleShotSamples.append(depthInInches)
        
        // Collect a small burst of samples, then average
        if singleShotSamples.count >= maxSingleShotSamples {
            let sum = singleShotSamples.reduce(0.0, +)
            let avg = sum / Double(singleShotSamples.count)
            finishSingleShot(with: avg)
        }
    }
    
    private func finishSingleShot(with distance: Double?) {
        let completion = singleShotCompletion
        singleShotCompletion = nil
        
        stopMeasuring()
        
        completion?(distance)
    }
    
    // ARSessionDelegate method
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Get camera intrinsics to calculate actual FOV
        let intrinsics = frame.camera.intrinsics
        let imageResolution = frame.camera.imageResolution
        
        // Calculate diagonal FOV from intrinsics
        let focalLengthX = intrinsics[0, 0]
        let focalLengthY = intrinsics[1, 1]
        let width = Float(imageResolution.width)
        let height = Float(imageResolution.height)
        
        // Calculate diagonal FOV
        let diagonal = sqrt(width * width + height * height)
        let focalLengthDiag = sqrt(focalLengthX * focalLengthX + focalLengthY * focalLengthY)
        let fovDiagonal = 2.0 * atan(diagonal / (2.0 * focalLengthDiag))
        let fovDiagonalDegrees = Double(fovDiagonal * 180.0 / .pi)
        
        DispatchQueue.main.async {
            if self.actualDiagonalFOV == nil {
                self.actualDiagonalFOV = fovDiagonalDegrees
                print("📐 AR Camera diagonal FOV: \(String(format: "%.2f", fovDiagonalDegrees))°")
            }
        }
        
        // Get depth at center of screen
        guard let sceneDepth = frame.sceneDepth else { return }
        
        let depthMap = sceneDepth.depthMap
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        
        // Lock the pixel buffer
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        // Get pointer to depth data
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        
        // Sample center pixel
        let centerX = depthWidth / 2
        let centerY = depthHeight / 2
        let centerIndex = centerY * depthWidth + centerX
        
        let depthInMeters = floatBuffer[centerIndex]
        
        // Convert to inches and update (only if valid)
        if depthInMeters > 0 && depthInMeters < 100 {
            let depthInInches = Double(depthInMeters) * 39.3701 // meters to inches
            
            DispatchQueue.main.async {
                self.handleDepthSample(depthInInches)
            }
        }
    }
}

