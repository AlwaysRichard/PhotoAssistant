//
//  HomeView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 10/15/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding()
                
                Text("Welcome to Photo Assistant")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Your photography companion for capturing perfect shots with detailed orientation data.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        // Quick access to camera
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Open Camera")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        // Quick access to photo library
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("View Photos")
                        }
                        .foregroundColor(.blue)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}