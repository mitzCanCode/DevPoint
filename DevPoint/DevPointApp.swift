//
//  DevPointApp.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI
import SwiftData
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    // Show banners even while DevPoint is in the foreground (needed when debugging).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }
}

@main
struct DevPointApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer

    init() {
        // Must register before the app finishes launching.
        CheckpointMonitoringService.registerBackgroundTasks()

        let container = Self.makeModelContainer()
        modelContainer = container

        let monitoring = CheckpointMonitoringService.shared
        monitoring.configure(modelContainer: container)
        monitoring.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color.accentColor)
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                ) { _ in
                    // Ask iOS again whenever the app returns to the foreground.
                    CheckpointMonitoringService.shared.scheduleBackgroundRefresh()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
                ) { _ in
                    // Also (re-)submit right as we background — this is when iOS actually
                    // evaluates the request against usage heuristics, so a fresh
                    // earliestBeginDate here gives the system its best shot at honoring it.
                    CheckpointMonitoringService.shared.scheduleBackgroundRefresh()
                }
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([Checkpoint.self])
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
