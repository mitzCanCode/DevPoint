//
//  CheckpointExpectedResponseView.swift
//  DevPoint
//
//  Created by mitz on 25/8/26.
//

import SwiftUI

struct CheckpointExpectedResponseView: View {
    @Bindable var checkpoint: WebsiteCheckpoint
    @Binding var ignoredLineNumbers: [Int]

    var body: some View {
        List {
            IgnoredLinesEditor(
                text: checkpoint.expectedResponse,
                ignoredLineNumbers: $ignoredLineNumbers,
                differingLineNumbers: differingLineNumbers(
                    expected: checkpoint.expectedResponse,
                    actual: checkpoint.lastResponse
                ),
                title: "Expected Response",
                footer: "Tap a line to ignore that line number during mismatch checks. Ignored lines are grayed out. If only ignored line numbers differ, status becomes OK (Expected Mismatch)."
            )
        }
        .navigationTitle("Expected Response")
        .navigationBarTitleDisplayMode(.inline)
    }
}
