//
//  Filters.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//

import Foundation

// MARK: - Top-level wrapper if your JSON is { "filters": [ ... ] }

struct FilterDatabase: Codable {
    let filters: [FilterType]
}

// MARK: - Filter type (one entry per filter family, e.g. "ND", "CPL", etc.)

struct FilterType: Identifiable, Codable, Hashable {
    /// Stable string id from JSON (e.g. "uv", "cpl", "nd", "ir")
    let id: String
    let name: String
    let category: String

    /// For simple filters like UV or CPL
    let compensationStops: Double?
    let compensationStopsMin: Double?
    let compensationStopsMax: Double?

    /// For filters that have multiple variants (ND, GND, IR, etc.)
    let variants: [FilterVariant]?

    // Convenience helpers for app logic
    var hasVariants: Bool { (variants?.isEmpty == false) }
    var isSimple: Bool { compensationStops != nil }
    var isRange: Bool { compensationStopsMin != nil && compensationStopsMax != nil }
}

// MARK: - Filter variant (e.g. ND2, ND4, 720nm, 81A, etc.)

struct FilterVariant: Identifiable, Codable, Hashable {
    /// Stable id for SwiftUI + app logic, derived from JSON key (nd/gnd/filter)
    let id: String
    /// Human-readable label to show in UI (usually same as id)
    let name: String

    /// For ND-style data
    let opticalDensity: Double?

    /// Single-stop value (e.g. 1, 2, 10)
    let stops: Double?

    /// Range when the variant itself has a min/max stop value
    let stopsMin: Double?
    let stopsMax: Double?

    // MARK: - Custom CodingKeys to handle nd/gnd/filter variants in JSON

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case opticalDensity
        case stops
        case stopsMin
        case stopsMax

        // Variant label keys as used in JSON:
        //   { "nd": "ND2", ... }
        //   { "gnd": "GND0.6", ... }
        //   { "filter": "81A", ... }
        case nd
        case gnd
        case filter
    }

    // MARK: - Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Figure out the variant label from nd/gnd/filter/id
        if let nd = try? container.decode(String.self, forKey: .nd) {
            id = nd
            name = nd
        } else if let gnd = try? container.decode(String.self, forKey: .gnd) {
            id = gnd
            name = gnd
        } else if let filter = try? container.decode(String.self, forKey: .filter) {
            id = filter
            name = filter
        } else {
            // Fallback: explicit id/name fields if you decide to add them
            let decodedID = try container.decode(String.self, forKey: .id)
            id = decodedID
            name = (try? container.decode(String.self, forKey: .name)) ?? decodedID
        }

        opticalDensity = try? container.decode(Double.self, forKey: .opticalDensity)
        stops          = try? container.decode(Double.self, forKey: .stops)
        stopsMin       = try? container.decode(Double.self, forKey: .stopsMin)
        stopsMax       = try? container.decode(Double.self, forKey: .stopsMax)
    }

    // MARK: - Encoding

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode a generic shape; if you want to round-trip using "nd"/"gnd"/"filter",
        // you can specialize this based on naming conventions.
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(opticalDensity, forKey: .opticalDensity)
        try container.encodeIfPresent(stops, forKey: .stops)
        try container.encodeIfPresent(stopsMin, forKey: .stopsMin)
        try container.encodeIfPresent(stopsMax, forKey: .stopsMax)
    }
}

