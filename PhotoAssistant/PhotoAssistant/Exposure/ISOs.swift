//
//  ISOs.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//

import Foundation

// MARK: - Model

struct ISOSetting: Identifiable, Hashable, Codable {
    let id = UUID()

    /// Numeric ISO value (e.g., 64, 100, 2500, etc.)
    let value: Double

    /// Display label
    var label: String {
        ISOSetting.formatISO(value)
    }

    /// EV offset relative to ISO 100
    /// EV = log2(ISO / 100)
    var evOffset: Double {
        log2(value / 100.0)
    }

    init(_ value: Double) {
        self.value = value
    }
}

extension ISOSetting {

    /// Formats ISO numbers:
    ///  - whole numbers (ISO 100)
    ///  - no decimals
    static func formatISO(_ value: Double) -> String {
        value == floor(value)
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    /// Third-stop ISO scale from ISO 100 → ISO 102400
    ///
    /// Uses standard ISO values commonly found on cameras
    static let thirdStopScale: [ISOSetting] = [
        100, 125, 160, 200, 250, 320, 400, 500, 640, 800,
        1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000,
        10000, 12800, 16000, 20000, 25600, 32000, 40000, 51200, 64000, 80000,
        102400
    ].map { ISOSetting($0) }
}
