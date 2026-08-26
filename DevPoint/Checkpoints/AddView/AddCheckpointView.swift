//
//  AddCheckpointView.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI
import SwiftData

enum AddCheckpointStep {
    case details
    case response
}

struct AddCheckpointView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var step: AddCheckpointStep = .details
    @State private var name: String = ""
    @State private var urlString: String = ""

@State private var isLoading = false
    @State private var loadingProgress: String?
    @State private var requestError: String?
    @State private var saveError: String?
    @State private var responseResult: URLResponseResult?
@State private var ignoredLineNumbers: [Int] = []

    private var normalizedURL: URL? {
        Self.normalizeURL(from: urlString)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .details:
AddCheckpointDetailsView(
                        name: $name,
                        urlString: $urlString,
                        isLoading: isLoading,
                        loadingProgress: loadingProgress,
                        requestError: requestError,
                        normalizedURL: normalizedURL,
                        onMakeRequest: {
                            Task { await makeRequest() }
                        }
                    )
                case .response:
                    if let responseResult, let normalizedURL {
                        AddCheckpointResponseView(
                            name: name,
                            url: normalizedURL,
                            result: responseResult,
                            ignoredLineNumbers: $ignoredLineNumbers,
                            onSave: saveCheckpoint
                        )
                    }
                }
            }
            .navigationTitle(step == .details ? "New Checkpoint" : "Review Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .details ? "Cancel" : "Back") {
                        if step == .response {
                            step = .details
                            requestError = nil
                            saveError = nil
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Couldn't Save Checkpoint", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Unknown error")
            }
        }
    }

    static func normalizeURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmed)")
    }

@MainActor
    private func makeRequest() async {
        guard let url = normalizedURL else {
            requestError = "Enter a valid URL."
            return
        }

        isLoading = true
        requestError = nil
        defer {
            isLoading = false
            loadingProgress = nil
        }

        do {
            let sample = try await sampleResponseBaseline(from: url) { progress in
                loadingProgress = progress
            }
            responseResult = sample.baseline
            ignoredLineNumbers = sample.ignoredLineNumbers
            step = .response
        } catch {
            requestError = error.localizedDescription
        }
    }

    private func saveCheckpoint() {
        guard
            let url = normalizedURL,
            let result = responseResult
        else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let checkpoint = WebsiteCheckpoint(
            name: trimmedName,
            url: url,
            expectedResponse: result.body
        )
        checkpoint.lastResponse = result.body
        checkpoint.lastResponseTitle = "HTTP \(result.statusCode)"
        checkpoint.lastResponseStatusCode = "\(result.statusCode)"
        checkpoint.lastResponseDescription = result.headers["Content-Type"]
            ?? result.headers["content-type"]
            ?? ""
        checkpoint.ignoredLineNumbers = ignoredLineNumbers
        checkpoint.status = determineCheckpointStatus(
            statusCode: result.statusCode,
            match: .exact
        )
        checkpoint.lastRunDate = Date()

        modelContext.insert(checkpoint)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.delete(checkpoint)
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    AddCheckpointView()
        .modelContainer(for: WebsiteCheckpoint.self, inMemory: true)
}
