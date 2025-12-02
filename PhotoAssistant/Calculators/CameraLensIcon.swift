//
//  CameraLensIcon.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/29/25.
//

import SwiftUI

/// A SwiftUI view that creates a stylized camera lens/aperture icon.
struct CameraLensIcon: View {
    var body: some View {
        ZStack {
            // 1. Outer Ring
            Circle()
                .stroke(lineWidth: 4) // Creates the defined outer boundary

            // 2. Aperture Blades (The six triangular segments)
            ApertureBlades(bladeCount: 6)
                // Offset the blades slightly inward from the very edge
                .scaleEffect(0.9) 
            
            // 3. Central Lens Detail 
            Group {
                // Outer circle for the main lens (acts as an internal bezel)
                Circle()
                    .stroke(lineWidth: 3)
                    .scaleEffect(0.55) 

                // Innermost 'Pupil'
                Circle()
                    .fill(Color.primary) // Use .primary to respect system dark/light mode
                    .scaleEffect(0.3)

                // Highlight/Reflection 1 (Larger)
                Circle()
                    .fill(Color.white)
                    .scaleEffect(0.12)
                    .offset(x: -0.15, y: -0.15) // Position it near the top-left

                // Highlight/Reflection 2 (Smaller)
                Circle()
                    .fill(Color.white)
                    .scaleEffect(0.06)
                    .offset(x: -0.05, y: -0.05) // Position it slightly inside the first
            }
        }
        // Ensure the ZStack fills its parent frame
        .aspectRatio(1, contentMode: .fit)
    }
}

// Helper Shape to create the stylized aperture blades
struct ApertureBlades: Shape {
    let bladeCount: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let angleIncrement = .pi * 2 / CGFloat(bladeCount)

        // Draw each blade segment
        for i in 0..<bladeCount {
            let startAngle = angleIncrement * CGFloat(i)
            let endAngle = angleIncrement * CGFloat(i + 1)
            
            // Define the three points of the triangular/trapezoidal shape
            let innerRadius: CGFloat = radius * 0.50 // Defines the size of the central hole
            let outerRadius: CGFloat = radius * 0.95 // The outer edge of the segment

            // Point A (Inner-Left)
            let innerLeftX = center.x + innerRadius * cos(startAngle)
            let innerLeftY = center.y + innerRadius * sin(startAngle)
            let pointA = CGPoint(x: innerLeftX, y: innerLeftY)

            // Point B (Outer-Left)
            let outerLeftX = center.x + outerRadius * cos(startAngle)
            let outerLeftY = center.y + outerRadius * sin(startAngle)
            let pointB = CGPoint(x: outerLeftX, y: outerLeftY)

            // Point C (Outer-Right)
            let outerRightX = center.x + outerRadius * cos(endAngle)
            let outerRightY = center.y + outerRadius * sin(endAngle)
            let pointC = CGPoint(x: outerRightX, y: outerRightY)

            // Point D (Inner-Right)
            let innerRightX = center.x + innerRadius * cos(endAngle)
            let innerRightY = center.y + innerRadius * sin(endAngle)
            let pointD = CGPoint(x: innerRightX, y: innerRightY)

            // Draw the blade path
            path.move(to: pointA)
            path.addLine(to: pointB)
            path.addLine(to: pointC)
            path.addLine(to: pointD)
            path.closeSubpath()
        }

        return path
    }
}

// --- Preview for Development ---
struct CameraLensIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Your requested usage:
            CameraLensIcon()
                .frame(width: 50, height: 50)
                .foregroundColor(.black)
            
            // Larger Example
            CameraLensIcon()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            // Example with different fill color
            CameraLensIcon()
                .frame(width: 80, height: 80)
                .foregroundColor(.white)
                .background(Color.black)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
