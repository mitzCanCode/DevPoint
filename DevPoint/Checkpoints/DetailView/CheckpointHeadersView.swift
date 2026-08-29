//
//  CheckpointHeadersView.swift
//  DevPoint
//
//  Created by mitz on 26/8/26.
//

import SwiftUI
import SwiftData

struct CheckpointHeadersView: View {
    let checkpoint: WebsiteCheckpoint

    private var headers: [String: String] {
        checkpoint.lastResponseHeaders
    }

    var body: some View {
        List {
            if headers.isEmpty {
                ContentUnavailableView(
                    "No Headers",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Refresh this checkpoint to capture response headers.")
                )
            } else {
                Section {
                    ForEach(headers.keys.sorted(), id: \.self) { key in
                        ResponseHeaderRow(
                            key: key,
                            value: headers[key] ?? ""
                        )
                    }
                }
            }
        }
        .navigationTitle("Headers")
        .navigationSubtitle("\(headers.count) \(headers.count == 1 ? "header" : "headers") from the latest response.")
    }
}

#Preview {
    let checkpoint = WebsiteCheckpoint(
        name: "Example",
        url: URL(string: "https://example.com")!,
        expectedResponse: "{\"ok\":true}"
    )
    checkpoint.lastResponseTitle = "HTTP 200"
    checkpoint.lastResponseHeaders = [
        "Content-Type": "application/json",
        "Cache-Control": "max-age=0"
    ]

    return NavigationStack {
        CheckpointHeadersView(checkpoint: checkpoint)
    }
    .modelContainer(for: WebsiteCheckpoint.self, inMemory: true)
}
