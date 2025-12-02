//
//  PlusMinusDiagonalIcon.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/28/25.
//


//
//  PlusMinusDiagonalIcon.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 11/27/25.
//

import SwiftUI

struct PlusMinusDiagonalIcon: View {
    var size: CGFloat = 18
    var backgroundColor: Color = .black
    var textColor: Color = .white
    
    var body: some View {
        ZStack {
            // Rounded background
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(backgroundColor)
            // Diagonal slash
            Rectangle()
                .fill(textColor)
                .frame(width: size * 0.075, height: size * 1.12)
                .rotationEffect(.degrees(45))
            // PLUS (top-left)
            VStack {
                HStack {
                    Text("+")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundColor(textColor)
                        .padding(size * 0.10)
                    Spacer()
                }
                Spacer()
            }
            // MINUS (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("−") // true minus sign
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundColor(textColor)
                        .padding(size * 0.10)
                }
            }
        }
        .frame(width: size, height: size)
    }
}