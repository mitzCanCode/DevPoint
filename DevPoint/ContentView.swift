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
            APIView()
                .tabItem {
                    Label("APIs", systemImage: "server.rack")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WebsiteCheckpoint.self, inMemory: true)
}
