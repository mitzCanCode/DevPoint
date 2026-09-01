//
//  ContentView.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            CheckpointsView()
                .tabItem {
                    Label("Websites", systemImage: "network")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Checkpoint.self, inMemory: true)
}
