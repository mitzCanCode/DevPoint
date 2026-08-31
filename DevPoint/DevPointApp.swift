//
//  DevPointApp.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI
import SwiftData

@main
struct DevPointApp: App {
    private let modelContainer: ModelContainer

    init() {
        modelContainer = Self.makeModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color.accentColor)
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([WebsiteCheckpoint.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
// Schema changes (e.g. new ignored fields) can make the
            // existing store unloadable. Reset once so the app can launch and
            // keep accepting new checkpoints.
            print("SwiftData load failed, resetting store: \(error)")
            Self.deleteStoreFiles(for: configuration)

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    private static func deleteStoreFiles(for configuration: ModelConfiguration) {
        let url = configuration.url
        let fm = FileManager.default
        let candidates = [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal")
        ]

        for fileURL in candidates {
            try? fm.removeItem(at: fileURL)
        }
    }
}
