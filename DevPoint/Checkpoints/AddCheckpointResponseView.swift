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

            IgnoredLinesEditor(
                text: result.body,
                ignoredLineNumbers: $ignoredLineNumbers
            )

            if !result.headers.isEmpty {
                headersSection
            }

            saveSection
        }
    }

    private var overviewSection: some View {
        Section {
            ResponseStatusBadge(statusCode: result.statusCode)

            LabeledContent("Status Code") {
                Text("\(result.statusCode)")
                    .fontWeight(.semibold)
                    .foregroundStyle(ResponseStatusBadge.color(for: result.statusCode))
            }

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

    private var saveSection: some View {
        Section {
            Button(action: onSave) {
                Label("Save Checkpoint", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        } footer: {
            Text("This response body becomes the expected baseline for future checks.")
        }
    }
}

struct ResponseStatusBadge: View {
    let statusCode: Int

    var body: some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Self.color(for: statusCode))
    }

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
