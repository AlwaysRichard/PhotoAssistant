//
//  FStops.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//

import Foundation

// MARK: - Model

struct FStop: Identifiable, Hashable, Codable {
    let id = UUID()

    /// Numeric aperture value (e.g. 2.8, 5.6, etc.)
    let value: Double

    /// Display label (e.g. "f/2.8")
    var label: String {
        "f/\(value.cleanFStop)"
    }

    /// EV offset relative to f/1.0
    ///
    /// EV_aperture = log2(N^2)
    /// where N is the f-number
    var evOffset: Double {
        log2(value * value)
    }

    init(_ value: Double) {
        self.value = value
    }
}

// MARK: - Formatting helpers

private extension Double {
    /// Round to 1 decimal for f-stop display (e.g. 1.4, 2.8, 5.6)
    var cleanFStop: String {
        let rounded = ((self * 10).rounded() / 10.0)
        if rounded == floor(rounded) {
            return String(format: "%.0f", rounded)
        } else {
            return String(format: "%.1f", rounded)
        }
    }
}

// MARK: - 1/3-stop scale generator (f/1.0 → f/64)

extension FStop {

    /// Third-stop f-stop scale from f/1.0 to f/64 using standard digital camera values
    static let thirdStopScale: [FStop] = [
        1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5, 2.8,
        3.2, 3.5, 4.0, 4.5, 5.0, 5.6, 6.3, 7.1, 8.0, 9.0,
        10.0, 11.0, 13.0, 14.0, 16.0, 18.0, 20.0, 22.0, 25.0, 29.0,
        32.0, 36.0, 40.0, 45.0, 51.0, 57.0, 64.0
    ].map { FStop($0) }
}
