//
//  FilmReciprocity.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//

import Foundation

// MARK: - Top-level film struct
struct FilmReciprocity: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let iso: Int
    let model: ReciprocityModel
}

// MARK: - Reciprocity Model (dynamic types)
enum ReciprocityModel: Codable, Hashable {
    case powerLaw(PowerLawModel)
    case lookupTable(LookupTableModel)
    case stopCorrection(StopCorrectionModel)
    case none(NoneModel)

    // MARK: Codable support
    private enum CodingKeys: String, CodingKey {
        case type
    }

    private enum ModelType: String, Codable {
        case powerLaw
        case lookupTable
        case stopCorrection
        case none
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ModelType.self, forKey: .type)

        switch type {
        case .powerLaw:
            self = .powerLaw(try PowerLawModel(from: decoder))
        case .lookupTable:
            self = .lookupTable(try LookupTableModel(from: decoder))
        case .stopCorrection:
            self = .stopCorrection(try StopCorrectionModel(from: decoder))
        case .none:
            self = .none(try NoneModel(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .powerLaw(let model):
            try model.encode(to: encoder)
        case .lookupTable(let model):
            try model.encode(to: encoder)
        case .stopCorrection(let model):
            try model.encode(to: encoder)
        case .none(let model):
            try model.encode(to: encoder)
        }
    }
}

// MARK: - Power Law Model
struct PowerLawModel: Codable, Hashable {
    let type: String          // "powerLaw"
    let factor: Double
    let cutoffTime: Double
}

// MARK: - Lookup Table Model
struct LookupTableModel: Codable, Hashable {
    struct DataPoint: Codable, Hashable {
        let metered: Double
        let corrected: Double
    }

    let type: String            // "lookupTable"
    let dataPoints: [DataPoint]
    let colorFilterSuggestion: String?
    let cutoffTime: Double
}

// MARK: - Stop Correction Model
struct StopCorrectionModel: Codable, Hashable {
    struct DataPoint: Codable, Hashable {
        let metered: Double
        let stopAdjustment: Double
    }

    let type: String           // "stopCorrection"
    let dataPoints: [DataPoint]
    let colorFilterSuggestion: String?
    let cutoffTime: Double
}

// MARK: - None Model
struct NoneModel: Codable, Hashable {
    let type: String          // "none"
    let cutoffTime: Double
}
