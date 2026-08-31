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
    @State private var showDeleteConfirmation = false
    @State private var editedName: String = ""
    @State private var editedURLString: String = ""
    @State private var urlEditError: String?
    
    @State private var now = Date()
    
    private var navigationSubtitle: String {
        let elapsed = now.timeIntervalSince(checkpoint.lastRunDate)

        if elapsed < 60 {
            return "Last Checked: Now"
        }

        return "Last Checked: \(Self.relativeDateFormatter.localizedString( for: checkpoint.lastRunDate, relativeTo: now ))"
    }
    
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
                editSection
                overviewSection
                navigationSection
            }
            //            }
            .refreshable {
                await refresh()
            }
            .navigationTitle(editedName.isEmpty ? checkpoint.name : editedName)
            .navigationSubtitle(navigationSubtitle)
            .onAppear {
                editedName = checkpoint.name
                editedURLString = checkpoint.url.absoluteString
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        commitURLEdit()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete Checkpoint", systemImage: "trash", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .confirmationDialog(
                        "Delete Checkpoint?",
                        isPresented: $showDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            modelContext.delete(checkpoint)
                            try? modelContext.save()
                            dismiss()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes \"\(checkpoint.name)\" and cannot be undone.")
                    }
                }
            }
            .sheet(isPresented: $showBrowser) {
                InAppBrowserView(url: checkpoint.url)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                now = Date()
            }
        }
    }
    
    private var editSection: some View {
        Section {
            TextField("Name", text: $editedName)
                .textInputAutocapitalization(.words)
                .onChange(of: editedName) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, trimmed != checkpoint.name else { return }
                    checkpoint.name = trimmed
                    try? modelContext.save()
                }
            
            TextField("https://example.com", text: $editedURLString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { commitURLEdit() }
                .onChange(of: editedURLString) { _, _ in
                    urlEditError = nil
                }
            
            Button {
                showBrowser = true
            } label: {
                Label("Visit Website", systemImage: "safari")
            }
            
            if let urlEditError {
                Text(urlEditError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Checkpoint")
        } footer: {
            Text("Details about this checkpoint and the website it represents.")
        }
        .onDisappear {
            commitURLEdit()
        }
    }
    
    private var overviewSection: some View {
        Section {
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
            
            if !checkpoint.lastResponseTitle.isEmpty {
                LabeledContent("Status Code") {
                    Text(checkpoint.lastResponseStatusCode)
                        .foregroundStyle(checkpoint.status.color)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            LabeledContent("Match Type") {
                Text(matchSummary)
                    .foregroundStyle(matchColor)
                    .multilineTextAlignment(.trailing)
            }
            
            if !checkpoint.lastResponseDescription.isEmpty {
                LabeledContent("Details") {
                    Text(checkpoint.lastResponseDescription)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Text("Overview")
        } footer: {
            Text("A summary of the checkpoint's current status and latest results.")
        }
    }

    private func commitURLEdit() {
        guard let url = AddCheckpointView.normalizeURL(from: editedURLString) else {
            urlEditError = "Enter a valid URL."
            editedURLString = checkpoint.url.absoluteString
            return
        }
        
        urlEditError = nil
        editedURLString = url.absoluteString
        
        guard url != checkpoint.url else { return }
        checkpoint.url = url
        try? modelContext.save()
    }
    
    private var navigationSection: some View {
        Section {
            
            NavigationLink {
                CheckpointHeadersView(checkpoint: checkpoint)
            } label: {
                Label("Headers", systemImage: "list.bullet.rectangle")
            }
            
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
        } header: {
            Text("Responses")
        }  footer: {
            Text("Detailed information about the responses received from the website.")
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

        checkpoint.applyResponseResult(
            result,
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
