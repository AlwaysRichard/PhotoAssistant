//
//  CalculationButtons.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 12/02/25.
//

import SwiftUI

// MARK: - F-Stop Button Section

struct FStopButtonSection: View {
    let selectedAperture: FStop
    let fStops: [FStop]
    let onApertureChange: (FStop) -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Aperture icon
                Image(systemName: "camera.aperture")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                
                // "Aperture" label
                Text("Aperture:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Slider for aperture adjustment
                Slider(
                    value: Binding(
                        get: {
                            // Find current index in fStops array
                            if let index = fStops.firstIndex(where: { $0.value == selectedAperture.value }) {
                                return Double(index)
                            }
                            return 0
                        },
                        set: { newValue in
                            let index = Int(newValue.rounded())
                            if index >= 0 && index < fStops.count {
                                onApertureChange(fStops[index])
                            }
                        }
                    ),
                    in: 0...Double(fStops.count - 1),
                    step: 1
                )
                .frame(maxWidth: .infinity)
                .accentColor(.blue)
                
                // Current aperture value display
                Text(selectedAperture.label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Lens Button Section

struct LensButtonSection: View {
    let selectedLens: Lens?
    let selectedZoom: Int
    let onZoomChange: (Int) -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Lens icon
                Image("CameraLensIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.primary)
                
                // "Lens" label
                Text(selectedLens?.type == .zoom ? "Zoom:" : "Prime Lens")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Zoom slider for zoom lenses (in the middle)
                if let lens = selectedLens, lens.type == .zoom, let range = lens.zoomRange {
                    Slider(
                        value: Binding(
                            get: { Double(selectedZoom) },
                            set: { onZoomChange(Int($0)) }
                        ),
                        in: Double(range.min)...Double(range.max),
                        step: 1
                    )
                    .frame(maxWidth: .infinity)
                    .accentColor(.blue)
                } else {
                    Spacer()
                }
                
                // Focal length display on the right
                if let lens = selectedLens {
                    Text(lensDisplayText(lens))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func lensDisplayText(_ lens: Lens) -> String {
        switch lens.type {
        case .prime:
            return "\(lens.primeFocalLength ?? 50)mm"
        case .zoom:
            return "\(selectedZoom)mm"
        }
    }
}

// MARK: - Focus Distance Button Section

struct FocusDistanceButtonSection: View {
    let focusDistanceFeet: Int
    let focusDistanceInches: Int
    let isInfinity: Bool
    let minFeet: Int
    let maxFeet: Int
    let onDistanceChange: (Int) -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "ruler")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                
                Text("Focus:")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Slider for distance adjustment
                if !isInfinity {
                    Slider(
                        value: Binding(
                            get: { Double(focusDistanceFeet) + Double(focusDistanceInches) / 12.0 },
                            set: { onDistanceChange(Int($0)) }
                        ),
                        in: Double(minFeet)...Double(maxFeet),
                        step: 1
                    )
                    .frame(maxWidth: .infinity)
                    .accentColor(.blue)
                } else {
                    Spacer()
                }
                
                Text(focusDistanceDisplay)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var focusDistanceDisplay: String {
        if isInfinity {
            return "∞"
        } else {
            return String(format: "%d'%d\"", focusDistanceFeet, focusDistanceInches)
        }
    }
}

// MARK: - Filter Button Section

struct FilterButtonSection: View {
    let totalFilterStops: Double
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "camera.filters")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                
                Text("Filters")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if totalFilterStops > 0 {
                    Text(String(format: "Stops +%.1f", totalFilterStops))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
