//
//  CropMarksOverlay.swift
//  PhotoAssistant
//
//  Created by Assistant on 11/19/25.
//

import SwiftUI

// MARK: - Crop Marks and Film Format Definitions

struct CropMarksOverlay: View {
    let filmFormat: FilmFormat
    let selectedFocalLength: Int
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            GeometryReader { geometry in
                let cropFrame = calculateCropFrame(
                    for: selectedFocalLength,
                    format: filmFormat,
                    in: geometry.size
                )
                
                ZStack {
                    // Semi-transparent overlay to dim the area outside the crop
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .mask(
                            Rectangle()
                                .fill(Color.white)
                                .overlay(
                                    Rectangle()
                                        .frame(width: cropFrame.width, height: cropFrame.height)
                                        .blendMode(.destinationOut)
                                )
                        )
                    
                    // Crop frame outline
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropFrame.width, height: cropFrame.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    
                    // Corner marks
                    Group {
                        cornerMark(at: .topLeading, in: cropFrame, geometry: geometry)
                        cornerMark(at: .topTrailing, in: cropFrame, geometry: geometry)
                        cornerMark(at: .bottomLeading, in: cropFrame, geometry: geometry)
                        cornerMark(at: .bottomTrailing, in: cropFrame, geometry: geometry)
                    }
                    
                    // Focal length label
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(selectedFocalLength)mm")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(6)
                                .padding(.trailing, 20)
                                .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
    }
    
    private func calculateCropFrame(for focalLength: Int, format: FilmFormat, in screenSize: CGSize) -> CGSize {
        // Field of view calculations for 6x6 cm format (60mm diagonal)
        let filmDiagonal: Double = 84.85 // mm (60mm x 60mm = 84.85mm diagonal)
        
        // Calculate field of view angle (in radians)
        let fovRadians = 2 * atan(filmDiagonal / (2 * Double(focalLength)))
        
        // Convert to degrees for reference
        let fovDegrees = fovRadians * 180 / .pi
        
        // Calculate crop frame size based on the screen dimensions
        // We'll use the smaller screen dimension as our reference to maintain aspect ratio
        let minScreenDimension = min(screenSize.width, screenSize.height)
        
        // Base the crop size on the field of view relative to a "normal" 80mm lens
        let normalFocalLength: Double = 80 // mm (normal lens for 6x6 format)
        let normalFovRadians = 2 * atan(filmDiagonal / (2 * normalFocalLength))
        
        // Scale factor based on field of view ratio
        let scaleFactor = sin(fovRadians / 2) / sin(normalFovRadians / 2)
        
        // Calculate crop dimensions (square for 6x6 format)
        let baseCropSize = minScreenDimension * 0.7 // 70% of screen for normal lens
        let cropSize = baseCropSize * scaleFactor
        
        // Ensure crop doesn't exceed screen bounds
        let maxCropSize = min(screenSize.width * 0.9, screenSize.height * 0.9)
        let finalCropSize = min(cropSize, maxCropSize)
        
        return CGSize(width: finalCropSize, height: finalCropSize)
    }
    
    private func cornerMark(at corner: CornerPosition, in cropFrame: CGSize, geometry: GeometryProxy) -> some View {
        let markLength: CGFloat = 20
        let markThickness: CGFloat = 2
        
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        let frameLeft = centerX - cropFrame.width / 2
        let frameRight = centerX + cropFrame.width / 2
        let frameTop = centerY - cropFrame.height / 2
        let frameBottom = centerY + cropFrame.height / 2
        
        var x: CGFloat
        var y: CGFloat
        var horizontalAlignment: HorizontalAlignment
        var verticalAlignment: VerticalAlignment
        
        switch corner {
        case .topLeading:
            x = frameLeft
            y = frameTop
            horizontalAlignment = .leading
            verticalAlignment = .top
        case .topTrailing:
            x = frameRight
            y = frameTop
            horizontalAlignment = .trailing
            verticalAlignment = .top
        case .bottomLeading:
            x = frameLeft
            y = frameBottom
            horizontalAlignment = .leading
            verticalAlignment = .bottom
        case .bottomTrailing:
            x = frameRight
            y = frameBottom
            horizontalAlignment = .trailing
            verticalAlignment = .bottom
        }
        
        return VStack(alignment: horizontalAlignment, spacing: 0) {
            if verticalAlignment == .top {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: markLength, height: markThickness)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: markThickness, height: markLength)
                    .alignmentGuide(.leading) { _ in
                        horizontalAlignment == .leading ? 0 : markThickness - markLength
                    }
            } else {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: markThickness, height: markLength)
                    .alignmentGuide(.leading) { _ in
                        horizontalAlignment == .leading ? 0 : markThickness - markLength
                    }
                Rectangle()
                    .fill(Color.white)
                    .frame(width: markLength, height: markThickness)
            }
        }
        .position(x: x, y: y)
    }
}

enum CornerPosition {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
}

struct FilmFormat {
    let name: String
    let width: Double // mm
    let height: Double // mm
    let diagonal: Double // mm
    
    static let format6x6 = FilmFormat(
        name: "6x6 cm (120 Film)",
        width: 60,
        height: 60,
        diagonal: 84.85
    )
    
    static let format35mm = FilmFormat(
        name: "35mm Film",
        width: 36,
        height: 24,
        diagonal: 43.27
    )
    
    static let format4x5 = FilmFormat(
        name: "4x5 inch",
        width: 101.6,
        height: 127,
        diagonal: 162.6
    )
}

// MARK: - Crop Marks Control Panel
struct CropMarksControlPanel: View {
    @Binding var selectedFocalLength: Int
    @Binding var showCropMarks: Bool
    let availableFocalLengths: [Int] = [50, 80, 120]
    
    var body: some View {
        VStack(spacing: 12) {
            // Toggle switch
            HStack {
                Text("Crop Marks")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: $showCropMarks)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            if showCropMarks {
                // Focal length selector
                HStack(spacing: 8) {
                    Text("Focal Length:")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    ForEach(availableFocalLengths, id: \.self) { focalLength in
                        Button(action: {
                            selectedFocalLength = focalLength
                        }) {
                            Text("\(focalLength)mm")
                                .font(.system(size: 14, weight: selectedFocalLength == focalLength ? .bold : .regular))
                                .foregroundColor(selectedFocalLength == focalLength ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFocalLength == focalLength ? Color.white : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                )
                                .cornerRadius(15)
                        }
                    }
                }
                
                // Format info
                Text("6x6 cm (120 Film)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

#Preview {
    ZStack {
        Color.black
        CropMarksOverlay(
            filmFormat: .format6x6,
            selectedFocalLength: 80,
            isVisible: true
        )
    }
}