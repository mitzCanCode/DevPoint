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
    /// JSON-encoded `[String: String]` of the latest response headers.
    var lastResponseHeadersJSON: String = "{}"
    /// JSON-encoded `[String: String]` of the baseline/expected response headers.
    var expectedResponseHeadersJSON: String = "{}"
    /// 1-based line numbers in the response body to exclude from mismatch checks.
    var ignoredLineNumbers: [Int] = []

    var lastResponseHeaders: [String: String] {
        get { Self.decodeHeaders(lastResponseHeadersJSON) }
        set { lastResponseHeadersJSON = Self.encodeHeaders(newValue) }
    }

    var expectedResponseHeaders: [String: String] {
        get { Self.decodeHeaders(expectedResponseHeadersJSON) }
        set { expectedResponseHeadersJSON = Self.encodeHeaders(newValue) }
    }

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
        self.lastResponseHeadersJSON = "{}"
        self.expectedResponseHeadersJSON = "{}"
        self.ignoredLineNumbers = []
    }

    /// Writes status/body/header fields from a live request result.
    func applyResponseResult(
        _ result: URLResponseResult,
        match: ResponseMatchKind? = nil,
        updateExpectedHeaders: Bool = false
    ) {
        lastResponse = result.body
        lastResponseTitle = result.statusCode == -1
            ? (result.errorMessage ?? "Request failed")
            : "HTTP \(result.statusCode)"
        lastResponseStatusCode = result.statusCode == -1
            ? "—"
            : "\(result.statusCode)"
        lastResponseDescription = result.headers["Content-Type"]
            ?? result.headers["content-type"]
            ?? result.errorMessage
            ?? ""
        lastResponseHeaders = result.headers
        if updateExpectedHeaders {
            expectedResponseHeaders = result.headers
        }
        lastRunDate = Date()

        if let match {
            status = determineCheckpointStatus(statusCode: result.statusCode, match: match)
        } else {
            recomputeStatus(statusCode: result.statusCode)
        }
    }

    private static func encodeHeaders(_ headers: [String: String]) -> String {
        guard JSONSerialization.isValidJSONObject(headers),
              let data = try? JSONSerialization.data(withJSONObject: headers, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    private static func decodeHeaders(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let headers = object as? [String: String]
        else {
            return [:]
        }
        return headers
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
