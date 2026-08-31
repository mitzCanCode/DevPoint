//
//  AddCheckpointView.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI
import SwiftData

struct AddCheckpointView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var urlString: String = ""
    
    @State private var isLoading = false
    @State private var loadingProgress: String?
    @State private var requestError: String?
    @State private var saveError: String?
@State private var responseResult: URLResponseResult?
    @State private var ignoredLineNumbers: [Int] = []
    @State private var ignoredHeaderNames: [String] = []
    @State private var nextStep: Bool = false
    
    private var normalizedURL: URL? {
        Self.normalizeURL(from: urlString)
    }
    
    @State private var showBrowser = false
    
    private var canMakeRequest: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && normalizedURL != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("https://example.com", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Checkpoint Details")
                } footer: {
Text("Enter a name and URL, then open the site or sample the live response. Four requests are made one second apart so fluctuating body lines and headers can be ignored automatically.")
                }
                

                
                if let requestError {
                    Section {
                        Label(requestError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationDestination(isPresented: $nextStep) {
                if let responseResult, let normalizedURL {
AddCheckpointResponseView(
                        name: name,
                        url: normalizedURL,
                        result: responseResult,
                        ignoredLineNumbers: $ignoredLineNumbers,
                        ignoredHeaderNames: $ignoredHeaderNames,
                        onSave: saveCheckpoint
                    )
                    .onDisappear {
                        requestError = nil
                        saveError = nil
                    }
                }
            }
            .sheet(isPresented: $showBrowser) {
                if let normalizedURL {
                    InAppBrowserView(url: normalizedURL)
                }
            }
            
            .navigationTitle("New Checkpoint")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showBrowser = true
                    } label: {
                        Label("Visit Website", systemImage: "safari")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(normalizedURL == nil)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Task {
                            await makeRequest()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Label(
                                "Make Request",
                                systemImage: "chevron.forward"
                            )
                        }
                    }
                    .disabled(!canMakeRequest || isLoading)
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
            ignoredHeaderNames = sample.ignoredHeaderNames
            nextStep.toggle()
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
checkpoint.ignoredLineNumbers = ignoredLineNumbers
        checkpoint.ignoredHeaderNames = ignoredHeaderNames
        checkpoint.applyResponseResult(
            result,
            match: .exact,
            updateExpectedHeaders: true
        )
        
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
