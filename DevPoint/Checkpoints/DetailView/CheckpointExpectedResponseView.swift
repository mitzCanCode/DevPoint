//
//  CheckpointExpectedResponseView.swift
//  DevPoint
//
//  Created by mitz on 25/8/26.
//

import SwiftUI
import SwiftData

struct CheckpointExpectedResponseView: View {
    @Bindable var checkpoint: WebsiteCheckpoint
    @Binding var ignoredLineNumbers: [Int]
    @Environment(\.modelContext) private var modelContext

    @State private var isResetting = false
    @State private var resetProgress: String?
    @State private var resetError: String?
    @State private var showResetConfirmation = false

    var body: some View {
        List {
            IgnoredLinesEditor(
                text: checkpoint.expectedResponse,
                ignoredLineNumbers: $ignoredLineNumbers,
                differingLineNumbers: differingLineNumbers(
                    expected: checkpoint.expectedResponse,
                    actual: checkpoint.lastResponse
                )
            )
        }
        .navigationTitle("Expected Response")
        .navigationSubtitle("\(ignoredLineNumbers.count) \(ignoredLineNumbers.count == 1 ? "line" : "lines") ignored")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(action: {
                    showResetConfirmation = true
                }) {
                    if isResetting {
                            ProgressView()
                    } else {
                        Label("Reset Expected Response", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .confirmationDialog(
                    "Reset Expected Response?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        Task { await resetExpectedResponse() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This replaces the current expected response and ignored lines using fresh samples from the site.")
                }
                .alert("Couldn't Reset Expected Response", isPresented: Binding(
                    get: { resetError != nil },
                    set: { if !$0 { resetError = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(resetError ?? "Unknown error")
                }
                .disabled(isResetting)
            }
        }
    }

    @MainActor
    private func resetExpectedResponse() async {
        guard !isResetting else { return }

        isResetting = true
        resetError = nil
        defer {
            isResetting = false
            resetProgress = nil
        }

        do {
            let sample = try await sampleResponseBaseline(from: checkpoint.url) { progress in
                resetProgress = progress
            }
            let result = sample.baseline

            checkpoint.expectedResponse = result.body
            checkpoint.lastResponse = result.body
            checkpoint.lastResponseTitle = result.statusCode == -1
                ? (result.errorMessage ?? "Request failed")
                : "HTTP \(result.statusCode)"
            checkpoint.lastResponseStatusCode = result.statusCode == -1
                ? "—"
                : "\(result.statusCode)"
            checkpoint.lastResponseDescription = result.headers["Content-Type"]
                ?? result.headers["content-type"]
                ?? result.errorMessage
                ?? ""
            checkpoint.lastRunDate = Date()
            ignoredLineNumbers = sample.ignoredLineNumbers
            checkpoint.status = determineCheckpointStatus(
                statusCode: result.statusCode,
                match: .exact
            )
            try? modelContext.save()
        } catch {
            resetError = error.localizedDescription
        }
    }
}
