//
//  AddCheckpointResponseView.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI

struct AddCheckpointResponseView: View {
    let name: String
    let url: URL
    let result: URLResponseResult
    @Binding var ignoredLineNumbers: [Int]
    let onSave: () -> Void
    
    var body: some View {
        Form {
            overviewSection
            
            if !result.headers.isEmpty {
                headersSection
            }
            
            IgnoredLinesEditor(
                text: result.body,
                ignoredLineNumbers: $ignoredLineNumbers
            )
        }
        .navigationTitle("Overview")
        .navigationSubtitle("Please review the sample response before saving the checkpoint.")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: onSave) {
                    Label("Save Checkpoint", systemImage: "checkmark")
                }
                .disabled(result.statusCode < 200 || result.statusCode >= 300)
            }
        }
    }
    
    private var overviewSection: some View {
        Section {
            LabeledContent("Name") {
                Text(name)
                    .foregroundStyle(.secondary)
            }
            
            LabeledContent("URL") {
                Text(url.absoluteString)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            
            LabeledContent("Response Status") {
                ResponseStatusBadge(statusCode: result.statusCode)
            }
        } header: {
            Text("Overview")
        }
    }
    
    
    private var headersSection: some View {
        Section("Headers") {
            ForEach(result.headers.keys.sorted(), id: \.self) { key in
                ResponseHeaderRow(
                    key: key,
                    value: result.headers[key] ?? ""
                )
            }
        }
    }
}

struct ResponseStatusBadge: View {
    let statusCode: Int
    
    private var title: String {
        switch statusCode {
        case 200...299: return "Success"
        case 400...499: return "Client Error"
        case 500...599: return "Server Error"
        case -1: return "Unreachable"
        default: return "Unknown"
        }
    }
    
    private var icon: String {
        switch statusCode {
        case 200...299: return "checkmark.seal.fill"
        case 400...499: return "exclamationmark.triangle.fill"
        case 500...599: return "xmark.octagon.fill"
        case -1: return "wifi.slash"
        default: return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(Image(systemName: icon))
            Text("\(title) (\(statusCode))")
        }
        .foregroundStyle(Self.color(for: statusCode))
    }
    
    static func color(for code: Int) -> Color {
        switch code {
        case 200...299: return .green
        case 400...499: return .orange
        case 500...599: return .red
        case -1: return .red
        default: return .gray
        }
    }
}

struct ResponseHeaderRow: View {
    let key: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AddCheckpointResponseView(
            name: "Example",
            url: URL(string: "https://example.com")!,
            result: URLResponseResult(
                statusCode: 200,
                body: "{\"ok\":true}\ntimestamp: 1",
                headers: ["Content-Type": "application/json"]
            ),
            ignoredLineNumbers: .constant([2]),
            onSave: {}
        )
        .navigationTitle("Review Response")
    }
}
