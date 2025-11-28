//
//  ShutterSpeeds.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//
//  Updated for full 1/3-stop range: 1/8000s → 68 minutes
//

import Foundation

struct ShutterSpeed: Identifiable, Hashable, Codable {
    let id = UUID()

    /// Duration in seconds (e.g. 0.008 for 1/125)
    let seconds: Double

    /// Formatted label (e.g., "8000", "0.4s", "3m 20s", "1h 8m")
    var label: String {
        if seconds < 1.0 {
            return ShutterSpeed.formatFraction(seconds)
        } else if seconds < 60 {
            return "\(seconds.clean)s"
        } else if seconds < 3600 {
            return ShutterSpeed.formatMinutes(seconds)
        } else {
            return ShutterSpeed.formatHours(seconds)
        }
    }

    /// EV relative to 1 second
    var evOffset: Double {
        -log2(seconds)
    }

    init(_ seconds: Double) {
        self.seconds = seconds
    }
}


// MARK: - Formatting Helpers

private extension Double {
    var clean: String {
        self == floor(self)
            ? String(format: "%.0f", self)
            : String(format: "%.1f", self)
    }
}

extension ShutterSpeed {

    /// Formats under 1 second as just the denominator (e.g., "8000" for 1/8000s)
    static func formatFraction(_ seconds: Double) -> String {
        let denom = Int(round(1.0 / seconds))
        return "\(denom)"
    }

    /// Formats exposures in minutes as "Xm Ys" or "Xm"
    static func formatMinutes(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let sec = Int(seconds) % 60
        if sec == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(sec)s"
        }
    }
    
    /// Formats exposures in hours as "Xh Ym" or "Xh"
    static func formatHours(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Full 1/3-stop scale generator

extension ShutterSpeed {

    /// Generates a 1/3-stop shutter scale from 1/8000s to 8 hours (28,800 seconds)
    static let thirdStopScale: [ShutterSpeed] = {
        let fastestSeconds = 1.0 / 8000.0          // 1/8000s
        let longistSeconds = 28800.0               // 8 hours

        let minEV = -log2(fastestSeconds)          // ≈ +13 EV
        let maxEV = -log2(longistSeconds)          // ≈ -14.8 EV
        let step = 1.0 / 3.0                       // 1/3 stop increments

        // EV range from fastest → slowest
        let evRange = stride(from: minEV, through: maxEV, by: -step)

        // Convert EV → seconds (t = 2^-EV)
        return evRange.map { ev in
            let seconds = pow(2.0, -ev)
            return ShutterSpeed(seconds)
        }
    }()
}
