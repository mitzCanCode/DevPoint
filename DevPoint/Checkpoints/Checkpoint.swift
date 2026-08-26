//
//  Checkpoint.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import Foundation
import SwiftUI
import SwiftData

enum CheckpointStatus: String, Codable {
    case healthy
    case unreachable
    case unknown
    case warning
    case serverError
    case notFound
    case responseMismatch
    /// HTTP OK, but the body differs only on lines the user chose to ignore.
    case expectedMismatch

    var title: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .unreachable:
            return "Unreachable"
        case .unknown:
            return "Unknown"
        case .warning:
            return "Warning"
        case .serverError:
            return "Server Error"
        case .notFound:
            return "Not Found"
        case .responseMismatch:
            return "Response Mismatch"
        case .expectedMismatch:
            return "OK (Expected Mismatch)"
        }
    }

    var color: Color {
        switch self {
        case .healthy:
            return .green
        case .unreachable:
            return .red
        case .unknown:
            return .gray
        case .warning:
            return .yellow
        case .serverError:
            return .red
        case .notFound:
            return .orange
        case .responseMismatch:
            return .orange
        case .expectedMismatch:
            return .mint
        }
    }
}


@Model
final class WebsiteCheckpoint {
    var name: String
    var creationDate: Date
    var lastRunDate: Date
    var status: CheckpointStatus

    var url: URL
    var expectedResponse: String
    var lastResponseTitle: String
    var lastResponseStatusCode: String
    
    var lastResponseDescription: String
    var lastResponse: String
    /// 1-based line numbers in the response body to exclude from mismatch checks.
    var ignoredLineNumbers: [Int] = []

    init(
        name: String,
        url: URL,
        expectedResponse: String
    ) {
        self.name = name
        self.creationDate = Date()
        self.lastRunDate = Date()
        self.status = .unknown

        self.url = url
        self.expectedResponse = expectedResponse

        self.lastResponseTitle = ""
        self.lastResponseStatusCode = ""
        self.lastResponseDescription = ""
        self.lastResponse = ""
        self.ignoredLineNumbers = []
    }

    func recomputeStatus(statusCode: Int? = nil) {
        let code: Int
        if let statusCode {
            code = statusCode
        } else if lastResponseTitle.hasPrefix("HTTP "),
                  let parsed = Int(lastResponseTitle.dropFirst(5).trimmingCharacters(in: .whitespaces)) {
            code = parsed
        } else if status == .unreachable || lastResponseTitle == "Request failed" {
            code = -1
        } else {
            code = 200
        }

        status = determineCheckpointStatus(
            statusCode: code,
            match: compareResponses(
                expected: expectedResponse,
                actual: lastResponse,
                ignoredLineNumbers: ignoredLineNumbers
            )
        )
    }

    func toggleIgnoredLineNumber(_ lineNumber: Int) {
        if let index = ignoredLineNumbers.firstIndex(of: lineNumber) {
            ignoredLineNumbers.remove(at: index)
        } else {
            ignoredLineNumbers.append(lineNumber)
            ignoredLineNumbers.sort()
        }
        recomputeStatus()
    }
}
