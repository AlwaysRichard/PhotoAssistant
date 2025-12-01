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


// MARK: - f-stop scale generator (f/1.0 → f/64)

enum FStopStepMode {
    case full
    case half
    case third
}

extension FStop {

    private static let canonicalFullStops: [Double] = [
        1.0, 1.4, 2.0, 2.8, 4.0, 5.6,
        8.0, 11.0, 16.0, 22.0, 32.0, 45.0, 64.0
    ]

    private static let canonicalHalfStops: [Double] = [
        1.0, 1.2, 1.4, 1.7, 2.0, 2.4,
        2.8, 3.4, 4.0, 4.8, 5.6, 6.7,
        8.0, 9.5, 11.0, 13.5, 16.0, 19.0,
        22.0, 27.0, 32.0, 38.0, 45.0, 54.0, 64.0
    ]

    private static let canonicalThirdStops: [Double] = [
        1.0, 1.1, 1.2, 1.4, 1.6, 1.8, 2.0,
        2.2, 2.5, 2.8, 3.2, 3.5, 4.0, 4.5,
        5.0, 5.6, 6.3, 7.1, 8.0, 9.0, 10.0,
        11.0, 13.0, 14.0, 16.0, 18.0, 20.0,
        22.0, 25.0, 29.0, 32.0, 36.0, 40.0,
        45.0, 51.0, 57.0, 64.0
    ]
}

extension FStop {

    static func scale(from minValue: Double = 1.0,
                      to maxValue: Double = 64.0,
                      stepMode: ShutterStepMode = .third) -> [FStop] {

        let minEV = log2(pow(minValue, 2))   // EV for f/1.0
        let maxEV = log2(pow(maxValue, 2))   // EV for f/64

        let step = stepMode.evStep  // 1, 1/2, or 1/3 EV

        var result: [FStop] = []
        var lastLabel: String? = nil

        var ev = minEV
        while ev <= maxEV {
            // Convert EV back to f-number: N = sqrt(2^EV)
            let rawF = sqrt(pow(2.0, ev))

            // Select snapping set
            let canonical: [Double]
            switch stepMode {
            case .full: canonical = canonicalFullStops
            case .half: canonical = canonicalHalfStops
            case .third: canonical = canonicalThirdStops
            }

            // Snap to nearest photographer-friendly value
            let snapped = canonical.min(by: {
                abs($0 - rawF) < abs($1 - rawF)
            }) ?? rawF

            let fstop = FStop(snapped)

            if fstop.label != lastLabel {
                result.append(fstop)
                lastLabel = fstop.label
            }

            ev += step
        }

        return result
    }

    static var fullStopScale: [FStop] { scale(stepMode: .full) }
    static var halfStopScale: [FStop] { scale(stepMode: .half) }
    static var thirdStopScale: [FStop] { scale(stepMode: .third) }
}
