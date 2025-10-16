//
//  ContentView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 10/13/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingCamera = false
    
    var body: some View {
        if showingCamera {
            CameraView(onBack: {
                withAnimation {
                    showingCamera = false
                    selectedTab = 0 // Return to home
                }
            })
                .ignoresSafeArea()
                .onTapGesture(count: 2) {
                    // Double tap to return to menu
                    withAnimation {
                        showingCamera = false
                        selectedTab = 0 // Return to home
                    }
                }
        } else {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)
                
                SearchView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(1)
                
                Text("Camera Placeholder")
                    .tabItem {
                        Image(systemName: "camera.fill")
                        Text("Camera")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(3)
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == 2 { // Camera tab
                    withAnimation {
                        showingCamera = true
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}