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
                )
            )
        }
        .navigationTitle("Expected Response")
        .navigationSubtitle("\(ignoredLineNumbers.count) \(ignoredLineNumbers.count == 1 ? "line" : "lines") ignored")
    }
}
