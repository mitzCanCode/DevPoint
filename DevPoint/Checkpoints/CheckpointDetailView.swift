//
//  CheckpointDetailView.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import SwiftUI
import SwiftData
import gitdiff

struct CheckpointDetailView: View {
    @Bindable var checkpoint: WebsiteCheckpoint
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isRefreshing = false
    @State private var showBrowser = false
    @State private var unifiedDiff = ""

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var body: some View {
        NavigationStack {
            Form {
                overviewSection
                ignoredLinesSection
                expectedSection
                diffSection
            }
            .navigationTitle(checkpoint.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
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

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showBrowser = true
                    } label: {
                        Label("Open Website", systemImage: "safari")
                    }
                }
            }
            .sheet(isPresented: $showBrowser) {
                InAppBrowserView(url: checkpoint.url)
            }
            .onAppear { updateDiff() }
            .onChange(of: checkpoint.lastResponse) { _, _ in updateDiff() }
            .onChange(of: checkpoint.expectedResponse) { _, _ in updateDiff() }
        }
    }

    private var overviewSection: some View {
        Section("Overview") {
            HStack {
                Circle()
                    .fill(checkpoint.status.color)
                    .frame(width: 10, height: 10)
                Text(checkpoint.status.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(checkpoint.status.color)
            }

            LabeledContent("URL") {
                Text(checkpoint.url.absoluteString)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }

            LabeledContent("Last Checked") {
                Text(
                    Self.relativeDateFormatter.localizedString(
                        for: checkpoint.lastRunDate,
                        relativeTo: Date()
                    )
                )
                .foregroundStyle(.secondary)
            }

            if !checkpoint.lastResponseTitle.isEmpty {
                LabeledContent("Result") {
                    Text(checkpoint.lastResponseTitle)
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
        }
    }


    private var expectedSection: some View {
        Section("Expected Response") {
            if checkpoint.expectedResponse.isEmpty {
                Text("Empty baseline")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text(checkpoint.expectedResponse)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var matchKind: ResponseMatchKind {
        compareResponses(
            expected: checkpoint.expectedResponse,
            actual: checkpoint.lastResponse,
            ignoredLineNumbers: checkpoint.ignoredLineNumbers
        )
    }

    private var ignoredLinesSection: some View {
        IgnoredLinesEditor(
            text: checkpoint.lastResponse.isEmpty ? checkpoint.expectedResponse : checkpoint.lastResponse,
            ignoredLineNumbers: Binding(
                get: { checkpoint.ignoredLineNumbers },
                set: { newValue in
                    checkpoint.ignoredLineNumbers = newValue
                    checkpoint.recomputeStatus()
                    try? modelContext.save()
                }
            ),
            differingLineNumbers: differingLineNumbers(
                expected: checkpoint.expectedResponse,
                actual: checkpoint.lastResponse
            ),
            title: "Last Response",
            footer: "Tap a line to ignore that line number during mismatch checks. Ignored lines are grayed out. If only ignored line numbers differ, status becomes OK (Expected Mismatch)."
        )
    }

    @ViewBuilder
    private var diffSection: some View {
        Section {
            switch matchKind {
            case .exact:
                Label("Responses match", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .expectedMismatch:
                Label("Only ignored lines differ", systemImage: "checkmark.circle")
                    .foregroundStyle(.mint)
                if !unifiedDiff.isEmpty {
                    DiffRenderer(diffText: unifiedDiff)
                        .diffConfiguration(.mobile)
                        .diffTheme(colorScheme == .dark ? .dark : .light)
                        .diffWordWrap(true)
                        .diffFileHeaders(true)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .frame(minHeight: 180, maxHeight: 360)
                }
            case .mismatch:
                if unifiedDiff.isEmpty {
                    Text("Unable to compute diff")
                        .foregroundStyle(.secondary)
                } else {
                    DiffRenderer(diffText: unifiedDiff)
                        .diffConfiguration(.mobile)
                        .diffTheme(colorScheme == .dark ? .dark : .light)
                        .diffWordWrap(true)
                        .diffFileHeaders(true)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .frame(minHeight: 220, maxHeight: 420)
                }
            }
        } header: {
            Text("Diff")
        } footer: {
            Text("Expected response (−) vs last response (+).")
        }
    }

    private func updateDiff() {
        guard checkpoint.expectedResponse != checkpoint.lastResponse else {
            unifiedDiff = ""
            return
        }

        unifiedDiff = UnifiedDiffBuilder.make(
            oldText: checkpoint.expectedResponse,
            newText: checkpoint.lastResponse,
            oldName: "expected",
            newName: "actual"
        )
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

// MARK: - Unified diff (git-style)

enum UnifiedDiffBuilder {
    static func make(
        oldText: String,
        newText: String,
        oldName: String,
        newName: String
    ) -> String {
        let oldLines = lines(from: oldText)
        let newLines = lines(from: newText)
        let edits = myersDiff(old: oldLines, new: newLines)

        var body = ""
        body += "diff --git a/\(oldName) b/\(newName)\n"
        body += "--- a/\(oldName)\n"
        body += "+++ b/\(newName)\n"

        let oldCount = oldLines.count
        let newCount = newLines.count

        if oldCount == 0 && newCount == 0 {
            body += "@@ -0,0 +0,0 @@\n"
            return body
        } else if oldCount == 0 {
            body += "@@ -0,0 +1,\(newCount) @@\n"
        } else if newCount == 0 {
            body += "@@ -1,\(oldCount) +0,0 @@\n"
        } else {
            body += "@@ -1,\(oldCount) +1,\(newCount) @@\n"
        }

        for edit in edits {
            switch edit {
            case .equal(let line):
                body += " \(line)\n"
            case .delete(let line):
                body += "-\(line)\n"
            case .insert(let line):
                body += "+\(line)\n"
            }
        }

        return body
    }

    private static func lines(from text: String) -> [String] {
        if text.isEmpty { return [] }
        var result = text.components(separatedBy: "\n")
        if text.hasSuffix("\n") {
            result.removeLast()
        }
        return result
    }

    private enum Edit {
        case equal(String)
        case delete(String)
        case insert(String)
    }

    /// Minimal Myers diff producing a linear edit script.
    private static func myersDiff(old: [String], new: [String]) -> [Edit] {
        let n = old.count
        let m = new.count
        let maxD = n + m

        if n == 0 {
            return new.map { .insert($0) }
        }
        if m == 0 {
            return old.map { .delete($0) }
        }

        var v = Array(repeating: 0, count: 2 * maxD + 1)
        var trace: [[Int]] = []

        outer: for d in 0...maxD {
            trace.append(v)
            for k in stride(from: -d, through: d, by: 2) {
                let index = k + maxD
                var x: Int
                if k == -d || (k != d && v[index - 1] < v[index + 1]) {
                    x = v[index + 1]
                } else {
                    x = v[index - 1] + 1
                }
                var y = x - k
                while x < n, y < m, old[x] == new[y] {
                    x += 1
                    y += 1
                }
                v[index] = x
                if x >= n, y >= m {
                    break outer
                }
            }
        }

        var edits: [Edit] = []
        var x = n
        var y = m

        for d in stride(from: trace.count - 1, through: 0, by: -1) {
            let vSnapshot = trace[d]
            let k = x - y
            let index = k + maxD

            let prevK: Int
            if k == -d || (k != d && vSnapshot[index - 1] < vSnapshot[index + 1]) {
                prevK = k + 1
            } else {
                prevK = k - 1
            }

            let prevX = vSnapshot[prevK + maxD]
            let prevY = prevX - prevK

            while x > prevX, y > prevY {
                x -= 1
                y -= 1
                edits.append(.equal(old[x]))
            }

            if d == 0 { break }

            if x == prevX {
                y -= 1
                edits.append(.insert(new[y]))
            } else {
                x -= 1
                edits.append(.delete(old[x]))
            }
        }

        return edits.reversed()
    }
}

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
