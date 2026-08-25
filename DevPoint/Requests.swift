//
//  Requests.swift
//  DevPoint
//
//  Created by mitz on 24/8/26.
//

import Foundation

struct URLResponseResult {
    let statusCode: Int
    let body: String
    let headers: [String: String]
    let errorMessage: String?

    init(
        statusCode: Int,
        body: String,
        headers: [String: String],
        errorMessage: String? = nil
    ) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
        self.errorMessage = errorMessage
    }
}

func requestUrl(_ url: URL) async -> URLResponseResult {
    do {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            return URLResponseResult(
                statusCode: -1,
                body: String(data: data, encoding: .utf8) ?? "",
                headers: [:],
                errorMessage: "The server did not return an HTTP response."
            )
        }

        let body = String(data: data, encoding: .utf8) ?? ""

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) {
            $0[String(describing: $1.key)] = String(describing: $1.value)
        }

        return URLResponseResult(
            statusCode: httpResponse.statusCode,
            body: body,
            headers: headers
        )

    } catch {
        return URLResponseResult(
            statusCode: -1,
            body: "",
            headers: [:],
            errorMessage: error.localizedDescription
        )
    }
}

enum ResponseMatchKind: Equatable {
    case exact
    /// Bodies differ, but only on lines the user marked as ignorable.
    case expectedMismatch
    case mismatch
}

func responseLines(from text: String) -> [String] {
    if text.isEmpty { return [] }
    var result = text.components(separatedBy: "\n")
    if text.hasSuffix("\n") {
        result.removeLast()
    }
    return result
}

/// Drops 1-based line numbers from a response body before comparison.
func normalizeResponse(_ text: String, ignoringLineNumbers ignored: [Int]) -> String {
    let ignoredSet = Set(ignored)
    return responseLines(from: text)
        .enumerated()
        .filter { !ignoredSet.contains($0.offset + 1) }
        .map(\.element)
        .joined(separator: "\n")
}

func compareResponses(
    expected: String,
    actual: String,
    ignoredLineNumbers: [Int]
) -> ResponseMatchKind {
    if expected == actual {
        return .exact
    }

    let normalizedExpected = normalizeResponse(expected, ignoringLineNumbers: ignoredLineNumbers)
    let normalizedActual = normalizeResponse(actual, ignoringLineNumbers: ignoredLineNumbers)

    if normalizedExpected == normalizedActual {
        return .expectedMismatch
    }

    return .mismatch
}

/// 1-based line numbers where expected and actual differ (for highlighting).
func differingLineNumbers(expected: String, actual: String) -> Set<Int> {
    let oldLines = responseLines(from: expected)
    let newLines = responseLines(from: actual)
    let maxCount = max(oldLines.count, newLines.count)
    var result = Set<Int>()

    for index in 0..<maxCount {
        let old = index < oldLines.count ? oldLines[index] : nil
        let new = index < newLines.count ? newLines[index] : nil
        if old != new {
            result.insert(index + 1)
        }
    }

    return result
}

func determineCheckpointStatus(
    statusCode: Int,
    match: ResponseMatchKind
) -> CheckpointStatus {
    switch statusCode {
    case 200...299:
        switch match {
        case .exact:
            return .healthy
        case .expectedMismatch:
            return .expectedMismatch
        case .mismatch:
            return .responseMismatch
        }

    case 400...499:
        if statusCode == 404 {
            return .notFound
        }
        return .warning

    case 500...599:
        return .serverError

    case -1:
        return .unreachable

    default:
        return .unknown
    }
}

/// Convenience for call sites that only know whether the raw bodies match.
func determineCheckpointStatus(
    statusCode: Int,
    responseMatches: Bool
) -> CheckpointStatus {
    determineCheckpointStatus(
        statusCode: statusCode,
        match: responseMatches ? .exact : .mismatch
    )
}
