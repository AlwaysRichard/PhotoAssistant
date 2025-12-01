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
    
    // MARK: - Canonical ISO series for different step modes
    
    /// Full-stop ISO values (roughly doubling per stop)
    private static let canonicalFullStops: [Double] = [
        25, 50, 100, 200, 400, 800,
        1600, 3200, 6400, 12800, 25600, 51200, 102400
    ]
    
    /// Half-stop ISO values
    private static let canonicalHalfStops: [Double] = [
        25, 32, 40, 50, 64, 80,
        100, 125, 160, 200, 250, 320,
        400, 500, 640, 800, 1000, 1250,
        1600, 2000, 2500, 3200, 4000, 5000,
        6400, 8000, 10000, 12800, 16000, 20000,
        25600, 32000, 40000, 51200, 64000, 80000,
        102400
    ]
    
    /// Third-stop ISO values (your existing set)
    private static let canonicalThirdStops: [Double] = [
        25, 32, 40, 50, 64, 80, 100, 125,
        160, 200, 250, 320, 400, 500, 640, 800,
        1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000,
        6400, 8000, 10000, 12800, 16000, 20000, 25600, 32000,
        40000, 51200, 64000, 80000, 102400
    ]
}

// MARK: - Scale API (like ShutterSpeed.scale)

extension ISOSetting {
    /// Generates an ISO scale from `minISO` to `maxISO` using EV math internally,
    /// snapping to photographer-friendly canonical ISO values based on the step mode.
    ///
    /// - Parameters:
    ///   - minISO: lowest ISO in the scale (default: 25)
    ///   - maxISO: highest ISO in the scale (default: 102400)
    ///   - stepMode: .full, .half, or .third (same as ShutterSpeed.scale)
    static func scale(from minISO: Double = 25.0,
                      to maxISO: Double = 102400.0,
                      stepMode: ShutterStepMode = .third) -> [ISOSetting] {

        // EV space for ISO: each doubling of ISO is +1 EV
        // We can work directly with log2(ISO).
        let minEV = log2(minISO)
        let maxEV = log2(maxISO)

        var result: [ISOSetting] = []
        var lastLabel: String? = nil

        var ev = minEV
        while ev <= maxEV {
            // Raw ISO from EV:
            let rawISO = pow(2.0, ev)

            // Choose canonical list for this mode
            let canonical: [Double]
            switch stepMode {
            case .full:
                canonical = canonicalFullStops
            case .half:
                canonical = canonicalHalfStops
            case .third:
                canonical = canonicalThirdStops
            }

            // Snap to nearest canonical ISO value
            let snappedISO = canonical.min(by: {
                abs($0 - rawISO) < abs($1 - rawISO)
            }) ?? rawISO

            // Create setting and dedupe by formatted ISO string
            let setting = ISOSetting(snappedISO)
            let label = ISOSetting.formatISO(snappedISO)

            if label != lastLabel {
                result.append(setting)
                lastLabel = label
            }

            ev += stepMode.evStep
        }

        return result
    }

    /// Convenience: same as your existing property, but now driven by `scale`.
    static let thirdStopScale: [ISOSetting] = ISOSetting.scale(stepMode: .third)
    static let halfStopScale: [ISOSetting] = ISOSetting.scale(stepMode: .half)
    static let fullStopScale: [ISOSetting] = ISOSetting.scale(stepMode: .full)
}

