//
//  ContentView.swift
//  PhotoAssistant
//
//  Created by Richard Cox on 10/13/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        PhotoAssistantView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
