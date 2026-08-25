//
//  CheckpointsView.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI
import SwiftData

struct CheckpointsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WebsiteCheckpoint.creationDate, order: .reverse) private var checkpoints: [WebsiteCheckpoint]

    @State private var showSheet = false
    @State private var selectedCheckpoint: WebsiteCheckpoint?
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            Group {
                if checkpoints.isEmpty {
                    ContentUnavailableView(
                        "No Checkpoints",
                        systemImage: "server.rack",
                        description: Text("Add a checkpoint to start monitoring a website response.")
                    )
                } else {
                    List(checkpoints) { checkpoint in
                        Button {
                            selectedCheckpoint = checkpoint
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(checkpoint.status.color)
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(checkpoint.name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text(checkpoint.url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                if isRefreshing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text(checkpoint.status.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(checkpoint.status.color)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Checkpoints")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Checkpoint")
                }
            }
            .sheet(isPresented: $showSheet) {
                AddCheckpointView()
            }
            .sheet(item: $selectedCheckpoint) { checkpoint in
                CheckpointDetailView(checkpoint: checkpoint)
            }
            .onAppear {
                Task {
                    await refreshAllCheckpoints()
                }
            }
        }
    }

    @MainActor
    private func refreshAllCheckpoints() async {
        guard !checkpoints.isEmpty, !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        await withTaskGroup(of: Void.self) { group in
            for checkpoint in checkpoints {
                group.addTask { @MainActor in
                    await refresh(checkpoint)
                }
            }
        }
    }

    @MainActor
    private func refresh(_ checkpoint: WebsiteCheckpoint) async {
        let result = await requestUrl(checkpoint.url)

        checkpoint.lastResponse = result.body
        checkpoint.lastResponseTitle = result.statusCode == -1
            ? (result.errorMessage ?? "Request failed")
            : "HTTP \(result.statusCode)"
        checkpoint.lastResponseDescription = result.headers["Content-Type"]
            ?? result.headers["content-type"]
            ?? result.errorMessage
            ?? ""
        checkpoint.lastRunDate = Date()
        checkpoint.status = determineCheckpointStatus(
            statusCode: result.statusCode,
            match: compareResponses(
                expected: checkpoint.expectedResponse,
                actual: result.body,
                ignoredLineNumbers: checkpoint.ignoredLineNumbers
            )
        )
        try? modelContext.save()
    }
}

#Preview {
    CheckpointsView()
        .modelContainer(for: WebsiteCheckpoint.self, inMemory: true)
}
