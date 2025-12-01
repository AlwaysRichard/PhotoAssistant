//
//  ShutterSpeeds.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//
//  Updated for full 1/3-, 1/2-, and full-stop ranges: 1/8000s → 8 hours
//  Uses exact EV math internally, but snaps labels to camera-like values.
//

import Foundation

struct ShutterSpeed: Identifiable, Hashable, Codable {
    let id = UUID()
    let seconds: Double

    init(seconds: Double) {
        self.seconds = seconds
    }

    var label: String {
        if seconds < 0.25 {
            return ShutterSpeed.formatFraction(seconds)
        } else if seconds < 60 {
            return "\(seconds.clean)s"
        } else if seconds < 3600 {
            return ShutterSpeed.formatMinutes(seconds)
        } else {
            return ShutterSpeed.formatHours(seconds)
        }
    }
    
    var evOffset: Double {
        -log2(seconds)
    }

    init(_ seconds: Double) {
        self.seconds = seconds
    }
}

// MARK: - Photographer-friendly formatting

extension ShutterSpeed {

    /// Canonical sub-second denominators used by real cameras for 1/3-stop speeds.
    /// These are "nice" numbers photographers expect to see.
    private static let canonicalFractionDenominators: [Int] = [
        8000, 6400, 5000,
        4000, 3200, 2500,
        2000, 1600, 1250,
        1000, 800, 640,
        500, 400, 320,
        250, 200, 160,
        125, 100, 80,
        60, 50, 40,
        30, 25, 20,
        15, 13, 10,
        8, 6, 5,
        4, 3, 2,
        1
    ]

    /// For 1s–30s we can also snap to camera-like whole-second values if desired.
    /// You can tweak this list later if you want even closer matching.
    private static let canonicalWholeSeconds: [Double] = [
        1.0, 1.3, 1.6,
        2.0, 2.5, 3.2,
        4.0, 5.0, 6.0,
        8.0, 10.0, 13.0,
        15.0, 20.0, 25.0,
        30.0
    ]
    
    private static let canonicalNearOneThirdStops: [Double] = [
        0.25,  // 1/4
        0.3,
        0.4,
        0.5,
        0.6,
        0.8,
        1.0,
        1.3,
        1.6,
        2.0
    ]

    private static let canonicalNearOneHalfStops: [Double] = [
        0.25,  // 1/4
        0.3,
        0.5,
        0.7,
        1.0,
        1.4,
        2.0
    ]

    private static let canonicalNearOneFullStops: [Double] = [
        0.25,  // 1/4
        0.5,
        1.0,
        2.0
    ]

    /// Formats under 1 second as just the denominator (e.g., "8000" for 1/8000s),
    /// snapped to the nearest canonical denominator so photographers see familiar values.
    static func formatFraction(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0" }

        let rawDenom = 1.0 / seconds

        // Find nearest "nice" denominator (8000, 6400, 5000, ...)
        let bestDenom = canonicalFractionDenominators.min(by: { a, b in
            abs(Double(a) - rawDenom) < abs(Double(b) - rawDenom)
        }) ?? Int(round(rawDenom))

        return "\(bestDenom)"
    }

    /// Formats exposures in minutes as "Xm Ys" or "Xm"
    static func formatMinutes(_ seconds: Double) -> String {
        let totalSeconds = Int(round(seconds))
        let minutes = totalSeconds / 60
        let sec = totalSeconds % 60

        if sec == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(sec)s"
        }
    }

    /// Formats exposures in hours as "Xh Ym" or "Xh Ym Zs"
    static func formatHours(_ seconds: Double) -> String {
        let totalSeconds = Int(round(seconds))
        let hours = totalSeconds / 3600
        let remaining = totalSeconds % 3600
        let minutes = remaining / 60
        let sec = remaining % 60

        if minutes == 0 && sec == 0 {
            return "\(hours)h"
        } else if sec == 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(hours)h \(minutes)m \(sec)s"
        }
    }

    /// Optionally snap 1–30s to common camera values (1, 1.3, 1.6, 2, 2.5, 3.2, ...)
    static func snappedSeconds(_ seconds: Double) -> Double {
        guard seconds >= 1.0, seconds <= 30.0 else { return seconds }

        let best = canonicalWholeSeconds.min(by: { a, b in
            abs(a - seconds) < abs(b - seconds)
        }) ?? seconds

        return best
    }
}

// MARK: - Pretty Double formatting

private extension Double {
    /// Formats a Double with either no decimals (if integer) or one decimal place.
    var clean: String {
        if self == floor(self) {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.1f", self)
        }
    }
}

// MARK: - Step modes and scale generation

/// Step size for shutter-speed scales.
enum ShutterStepMode: String, Codable, CaseIterable {
    case full   // 1-stop steps
    case half   // 1/2-stop steps
    case third  // 1/3-stop steps

    var evStep: Double {
        switch self {
        case .full:
            return 1.0
        case .half:
            return 0.5
        case .third:
            return 1.0 / 3.0
        }
    }
}

extension ShutterSpeed {

    /// Generates a shutter-speed scale using exact EV math internally,
    /// from fastestSeconds to slowestSeconds, with the requested step mode.
    ///
    /// The default range is 1/8000s to 8 hours (28,800 seconds).
    static func scale(from fastestSeconds: Double = 1.0 / 8000.0,
                  to slowestSeconds: Double = 28800.0,
                  stepMode: ShutterStepMode = .third) -> [ShutterSpeed] {

        let minEV = -log2(fastestSeconds)   // fastest
        let maxEV = -log2(slowestSeconds)   // slowest

        var result: [ShutterSpeed] = []
        var lastLabel: String? = nil

        var ev = minEV
        while ev >= maxEV {
            let rawSeconds = pow(2.0, -ev)

            // Choose snapping behavior
            var secondsForStorage = rawSeconds

            // 1/4s–2s region → snap based on stepMode
            if rawSeconds >= 0.24 && rawSeconds <= 2.1 {
                let canonical: [Double]
                switch stepMode {
                case .third:
                    canonical = canonicalNearOneThirdStops
                case .half:
                    canonical = canonicalNearOneHalfStops
                case .full:
                    canonical = canonicalNearOneFullStops
                }

                if let best = canonical.min(by: { abs($0 - rawSeconds) < abs($1 - rawSeconds) }) {
                    secondsForStorage = best
                }
            }
            // (Optionally, you can still keep your old snapping for 1–30s here if you like)

            // Build candidate
            let candidate = ShutterSpeed(seconds: secondsForStorage)
            let label = candidate.label

            // Skip duplicates (e.g. multiple EV steps that land on "0.5s" or "2s")
            if label != lastLabel {
                result.append(candidate)
                lastLabel = label
            }

            ev -= stepMode.evStep
        }

        return result
    }

    /// Common prebuilt scales if you want easy access.
    static let fullStopScale: [ShutterSpeed] = ShutterSpeed.scale(stepMode: .full)
    static let halfStopScale: [ShutterSpeed] = ShutterSpeed.scale(stepMode: .half)
    static let thirdStopScale: [ShutterSpeed] = ShutterSpeed.scale(stepMode: .third)
}

