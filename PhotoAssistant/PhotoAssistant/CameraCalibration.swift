import Foundation
import Combine

// MARK: - Calibration Data Model

/// Stores calibration data for a specific camera lens on a specific device
struct CameraCalibration: Codable, Identifiable {
    let id: UUID
    let deviceModel: String          // e.g., "iPhone 15 Pro"
    let lensType: String              // "0.5x", "1x", "2x", "3x"
    let zoomFactor: CGFloat           // 0.5, 1.0, 2.0, 3.0
    let capturePlane: String          // "Medium Format 6x6cm", "Hasselblad X1D/X2D", etc.
    let focalLength: Int              // 80, 35, 50, etc.
    
    // Measurement data
    let measuredObjectSize: Double    // Actual size of reference object in inches
    let measuredDistance: Double      // Distance to object in inches
    let calculatedFieldSize: Double   // What the app THOUGHT the field size was
    let correctionFactor: Double      // measuredObjectSize / calculatedFieldSize
    
    // Metadata
    let calibrationDate: Date
    let notes: String?                // Optional notes about calibration conditions
    
    // Computed property for display
    var accuracyPercentage: Double {
        return (correctionFactor - 1.0) * 100.0
    }
    
    var key: String {
        return "\(deviceModel)_\(lensType)_\(capturePlane)_\(focalLength)"
    }
    
    init(id: UUID = UUID(),
         deviceModel: String,
         lensType: String,
         zoomFactor: CGFloat,
         capturePlane: String,
         focalLength: Int,
         measuredObjectSize: Double,
         measuredDistance: Double,
         calculatedFieldSize: Double,
         calibrationDate: Date = Date(),
         notes: String? = nil) {
        self.id = id
        self.deviceModel = deviceModel
        self.lensType = lensType
        self.zoomFactor = zoomFactor
        self.capturePlane = capturePlane
        self.focalLength = focalLength
        self.measuredObjectSize = measuredObjectSize
        self.measuredDistance = measuredDistance
        self.calculatedFieldSize = calculatedFieldSize
        // FIXED: Correction factor should be calculatedFieldSize / measuredObjectSize
        // If app calculated 45" but reality is 24", we need to multiply by 45/24 = 1.875 to correct
        self.correctionFactor = calculatedFieldSize / measuredObjectSize
        self.calibrationDate = calibrationDate
        self.notes = notes
    }
}

// MARK: - Calibration Manager

/// Manages storing, loading, and applying camera calibrations
class CameraCalibrationManager: ObservableObject {
    static let shared = CameraCalibrationManager()
    
    @Published var calibrations: [CameraCalibration] = []
    
    private let fileURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("camera_calibrations.json")
    }()
    
    private init() {
        loadCalibrations()
    }
    
    // MARK: - Storage
    
    func saveCalibrations() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(calibrations)
            try data.write(to: fileURL)
            print("✅ Saved \(calibrations.count) calibrations to \(fileURL.path)")
        } catch {
            print("❌ Error saving calibrations: \(error)")
        }
    }
    
    func loadCalibrations() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ℹ️ No calibration file found, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            calibrations = try decoder.decode([CameraCalibration].self, from: data)
            print("✅ Loaded \(calibrations.count) calibrations from \(fileURL.path)")
        } catch {
            print("❌ Error loading calibrations: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func addCalibration(_ calibration: CameraCalibration) {
        // Remove any existing calibration with the same key
        calibrations.removeAll { $0.key == calibration.key }
        
        // Add new calibration
        calibrations.append(calibration)
        
        // Sort by date (newest first)
        calibrations.sort { $0.calibrationDate > $1.calibrationDate }
        
        saveCalibrations()
        
        print("✅ Added calibration: \(calibration.key)")
        print("   Correction factor: \(calibration.correctionFactor) (\(calibration.accuracyPercentage > 0 ? "+" : "")\(String(format: "%.1f", calibration.accuracyPercentage))%)")
    }
    
    func deleteCalibration(_ calibration: CameraCalibration) {
        calibrations.removeAll { $0.id == calibration.id }
        saveCalibrations()
        print("✅ Deleted calibration: \(calibration.key)")
    }
    
    func deleteAllCalibrations() {
        calibrations.removeAll()
        saveCalibrations()
        print("✅ Deleted all calibrations")
    }
    
    // MARK: - Lookup
    
    func getCalibration(deviceModel: String,
                       lensType: String,
                       capturePlane: String,
                       focalLength: Int) -> CameraCalibration? {
        let key = "\(deviceModel)_\(lensType)_\(capturePlane)_\(focalLength)"
        return calibrations.first { $0.key == key }
    }
    
    func getCorrectionFactor(deviceModel: String,
                            lensType: String,
                            capturePlane: String,
                            focalLength: Int) -> Double? {
        return getCalibration(deviceModel: deviceModel,
                            lensType: lensType,
                            capturePlane: capturePlane,
                            focalLength: focalLength)?.correctionFactor
    }
    
    // NEW: Get correction factor for device/lens/plane combo, ignoring focal length
    // This is the preferred method since the correction factor is determined by the
    // iPhone lens + capture plane characteristics, not the simulated focal length
    func getCorrectionFactorForCombo(deviceModel: String,
                                     lensType: String,
                                     capturePlane: String) -> (correctionFactor: Double, focalLength: Int)? {
        // Find any calibration matching this device/lens/plane combo
        // Prefer the most recent one (they're sorted by date, newest first)
        if let calibration = calibrations.first(where: {
            $0.deviceModel == deviceModel &&
            $0.lensType == lensType &&
            $0.capturePlane == capturePlane
        }) {
            return (calibration.correctionFactor, calibration.focalLength)
        }
        return nil
    }
    
    // MARK: - Statistics
    
    func calibrationsFor(deviceModel: String) -> [CameraCalibration] {
        return calibrations.filter { $0.deviceModel == deviceModel }
    }
    
    func calibrationsFor(lensType: String) -> [CameraCalibration] {
        return calibrations.filter { $0.lensType == lensType }
    }
    
    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // Map identifiers to friendly names
        let deviceMap: [String: String] = [
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 14",
            "iPhone15,5": "iPhone 14 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone16,3": "iPhone 15",
            "iPhone16,4": "iPhone 15 Plus",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
        ]
        
        return deviceMap[identifier] ?? identifier
    }
}

// MARK: - Calibration Session

/// Temporary state during an active calibration session
class CalibrationSession: ObservableObject {
    @Published var step: CalibrationStep = .selectLens
    @Published var selectedLensType: String = "1x"
    @Published var selectedZoomFactor: CGFloat = 1.0
    @Published var selectedCamera: MyGearModel?
    @Published var selectedLens: Lens?
    @Published var selectedCapturePlane: String = ""
    @Published var selectedFocalLength: Int = 50
    @Published var measuredObjectSize: String = ""
    @Published var measuredDistance: String = ""
    @Published var calculatedFieldSize: Double = 0.0
    @Published var useAutoDistance: Bool = false
    @Published var autoDistance: Double? = nil
    @Published var notes: String = ""
    
    enum CalibrationStep {
        case selectCamera
        case selectLens
        case measureObject
        case frameObject
        case measureDistance
        case review
        case complete
    }
    
    enum DistanceMode {
        case manual
        case lidar
    }
    
    @Published var distanceMode: DistanceMode = .manual
    
    func reset() {
        step = .selectCamera
        selectedLensType = "1x"
        selectedZoomFactor = 1.0
        selectedCamera = nil
        selectedLens = nil
        selectedCapturePlane = ""
        selectedFocalLength = 50
        measuredObjectSize = ""
        measuredDistance = ""
        calculatedFieldSize = 0.0
        useAutoDistance = false
        autoDistance = nil
        notes = ""
        distanceMode = .manual
    }
    
    /// Get suggested focal length for each iPhone lens to fill screen nicely
    func getSuggestedFocalLength(for iPhoneLens: String, camera: MyGearModel) -> Int? {
        // Get available focal lengths from camera's lenses
        var availableFocalLengths: [Int] = []
        
        for lens in camera.lenses {
            if lens.type == .prime, let focal = lens.primeFocalLength {
                availableFocalLengths.append(focal)
            } else if lens.type == .zoom, let range = lens.zoomRange {
                // For zoom, add min, max, and some intermediate values
                availableFocalLengths.append(range.min)
                availableFocalLengths.append(range.max)
                // Add middle point
                availableFocalLengths.append((range.min + range.max) / 2)
            }
        }
        
        // Suggested focal lengths for good screen fill on each iPhone lens
        let suggestions: [String: Int] = [
            "0.5x": 35,   // Wide lens needs wider film lens
            "1x": 80,     // Standard matches well with 80mm
            "2x": 120,    // Telephoto needs longer lens
            "3x": 150     // Long telephoto needs even longer
        ]
        
        guard let idealFocal = suggestions[iPhoneLens] else { return nil }
        
        // Find closest available focal length
        return availableFocalLengths.min(by: { abs($0 - idealFocal) < abs($1 - idealFocal) })
    }
    
    var isReadyToComplete: Bool {
        guard let objectSize = Double(measuredObjectSize),
              objectSize > 0,
              calculatedFieldSize > 0 else {
            return false
        }
        
        // Check distance
        if useAutoDistance {
            return autoDistance != nil && autoDistance! > 0
        } else {
            guard let distance = Double(measuredDistance),
                  distance > 0 else {
                return false
            }
        }
        
        return true
    }
    
    var finalDistance: Double? {
        if useAutoDistance {
            return autoDistance
        } else {
            return Double(measuredDistance)
        }
    }
    
    func createCalibration() -> CameraCalibration? {
        guard let objectSize = Double(measuredObjectSize),
              let distance = finalDistance,
              let camera = selectedCamera else {
            return nil
        }
        
        return CameraCalibration(
            deviceModel: CameraCalibrationManager.shared.deviceModel,
            lensType: selectedLensType,
            zoomFactor: selectedZoomFactor,
            capturePlane: camera.capturePlane,
            focalLength: selectedFocalLength,
            measuredObjectSize: objectSize,
            measuredDistance: distance,
            calculatedFieldSize: calculatedFieldSize,
            notes: notes.isEmpty ? nil : notes
        )
    }
}
