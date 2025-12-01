// MyGearModel.swift
import Foundation

struct ZoomRange: Codable, Equatable, Hashable {
    var min: Int
    var max: Int
}

struct Lens: Identifiable, Codable, Equatable, Hashable {
    enum LensType: String, Codable, CaseIterable, Identifiable {
        case prime, zoom
        var id: String { rawValue }
    }
    let id = UUID()
    var name: String
    var type: LensType
    var primeFocalLength: Int? // for prime
    var zoomRange: ZoomRange? // for zoom
    
    static func == (lhs: Lens, rhs: Lens) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct MyGearModel: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    var cameraName: String
    var capturePlane: String
    var capturePlaneWidth: Double
    var capturePlaneHeight: Double
    var capturePlaneDiagonal: Double
    var lenses: [Lens]
    
    static func == (lhs: MyGearModel, rhs: MyGearModel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Persistence
    private static let storageKey = "myGearList"
    
    static func saveGearList(_ gearList: [MyGearModel]) {
        if let encoded = try? JSONEncoder().encode(gearList) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    static func loadGearList() -> [MyGearModel] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MyGearModel].self, from: data) else {
            return []
        }
        return decoded
    }
}
