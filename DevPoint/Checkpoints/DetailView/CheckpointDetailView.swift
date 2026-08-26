//
//  CheckpointDetailView.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI
import SwiftData

struct CheckpointDetailView: View {
    @Bindable var checkpoint: WebsiteCheckpoint
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isRefreshing = false
    @State private var showBrowser = false

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private var matchKind: ResponseMatchKind {
        compareResponses(
            expected: checkpoint.expectedResponse,
            actual: checkpoint.lastResponse,
            ignoredLineNumbers: checkpoint.ignoredLineNumbers
        )
    }

    private var ignoredLinesBinding: Binding<[Int]> {
        Binding(
            get: { checkpoint.ignoredLineNumbers },
            set: { newValue in
                checkpoint.ignoredLineNumbers = newValue
                checkpoint.recomputeStatus()
                try? modelContext.save()
            }
        )
    }

    var body: some View {
        NavigationStack {
//            ScrollView{
                Form {
                    overviewSection
                    navigationSection
                }
//            }
            .navigationTitle(checkpoint.name)
            .navigationSubtitle(
                "Last Checked: \(Self.relativeDateFormatter.localizedString(for: checkpoint.lastRunDate, relativeTo: Date()))"
            )
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel("Refresh")
                }
            }
            .sheet(isPresented: $showBrowser) {
                InAppBrowserView(url: checkpoint.url)
            }
        }
    }

    private var overviewSection: some View {
            Section("Overview") {
                LabeledContent("Health") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(checkpoint.status.color)
                            .frame(width: 10, height: 10)
                            .shadow(
                                color: checkpoint.status.color.opacity(0.2),
                                radius: 2
                            )

                        Text(checkpoint.status.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(checkpoint.status.color)
                    }
                }

                LabeledContent("URL") {
                    Button {
                        showBrowser = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                            Text(checkpoint.url.absoluteString)
                        }
                    }
                }

                if !checkpoint.lastResponseTitle.isEmpty {
                    LabeledContent("Status Code") {
                        Text(checkpoint.lastResponseStatusCode)
                            .foregroundStyle(checkpoint.status.color)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if !checkpoint.lastResponseDescription.isEmpty {
                    LabeledContent("Details") {
                        Text(checkpoint.lastResponseDescription)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }

                LabeledContent("Match Type") {
                    Text(matchSummary)
                        .foregroundStyle(matchColor)
                        .multilineTextAlignment(.trailing)
                }
            
        }
    }

    private var navigationSection: some View {
        Section("Responses") {
            NavigationLink {
                CheckpointDiffView(checkpoint: checkpoint)
            } label: {
                Label("Latest Response", systemImage: "arrow.left.arrow.right")
            }

            NavigationLink {
                CheckpointExpectedResponseView(
                    checkpoint: checkpoint,
                    ignoredLineNumbers: ignoredLinesBinding
                )
            } label: {
                Label("Expected Response", systemImage: "doc.text")
            }
        }
    }

    private var matchSummary: String {
        switch matchKind {
        case .exact:
            return "Exact match"
        case .expectedMismatch:
            return "Only ignored lines differ"
        case .mismatch:
            return "Mismatch"
        }
    }

    private var matchColor: Color {
        switch matchKind {
        case .exact:
            return .green
        case .expectedMismatch:
            return .mint
        case .mismatch:
            return .orange
        }
    }

    @MainActor
    private func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

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

// MARK: - Destination views



#Preview {
    let checkpoint = WebsiteCheckpoint(
        name: "Example",
        url: URL(string: "https://example.com")!,
        expectedResponse: "{\"ok\":true}"
    )
    checkpoint.lastResponse = "{\"ok\":false,\"error\":\"down\"}"
    checkpoint.lastResponseTitle = "HTTP 200"
    checkpoint.lastResponseDescription = "application/json"
    checkpoint.status = .responseMismatch

    return CheckpointDetailView(checkpoint: checkpoint)
        .modelContainer(for: WebsiteCheckpoint.self, inMemory: true)
}
