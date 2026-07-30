//
//  SyncDebugLog.swift
//  Deadliner
//
//  Compatibility facades backed by the app-wide 30-minute log buffer.
//

import Foundation
import Darwin

enum AppLogLevel: String, Codable {
    case debug
    case info
    case warning
    case error
}

/// Stable domains make a report useful even when it combines Swift, KMP and
/// captured stdout records. Do not put user-entered text, credentials or full
/// network payloads in `context`.
enum AppLogDomain: String, Codable {
    case lifecycle
    case persistence
    case kmp
    case sync
    case ai
    case ui
    case watch
    case network
    case stdio
    case app
}

enum AppLogExportFormat: Equatable {
    case standard
    case json
}

/// The sole file-backed logging entry point for the iOS process.
///
/// The buffer deliberately does not write to stdout/stderr: the process-wide
/// stdio tee already feeds those streams back into this buffer, and printing
/// here would create a feedback loop.
enum AppLog {
    static func log(
        _ message: String,
        level: AppLogLevel = .info,
        category: String = "app"
    ) {
        Task {
            await AppLogBuffer.shared.append(message, level: level, category: category)
        }
    }

    /// Preferred entry point for new core logic. It records a stable event
    /// name plus queryable, privacy-safe diagnostic fields in the JSONL file.
    static func event(
        _ name: String,
        domain: AppLogDomain,
        level: AppLogLevel = .info,
        context: [String: String] = [:]
    ) {
        Task {
            await AppLogBuffer.shared.append(
                "[\(name)]",
                level: level,
                category: domain.rawValue,
                context: context
            )
        }
    }

    static func failure(
        _ name: String,
        domain: AppLogDomain,
        error: Error,
        context: [String: String] = [:]
    ) {
        var values = context
        values["error"] = error.localizedDescription
        event(name, domain: domain, level: .error, context: values)
    }

    static func exportURL(format: AppLogExportFormat = .standard) async -> URL {
        await AppLogBuffer.shared.exportURL(format: format)
    }

    static func exportURLs() async -> [URL] {
        await AppLogBuffer.shared.exportURLs()
    }

    static func clear() async throws {
        try await AppLogBuffer.shared.clear()
    }

    /// Starts periodic retention maintenance without deleting restart evidence.
    static func beginSession() {
        Task {
            await AppLogBuffer.shared.beginSession()
        }
    }
}

private struct AppLogRecord: Codable {
    let schemaVersion: Int?
    let timestamp: TimeInterval
    let sessionID: String?
    let processID: Int32?
    let level: AppLogLevel
    let category: String
    let message: String
    let context: [String: String]?
}

actor AppLogBuffer {
    static let shared = AppLogBuffer()

    private let standardFileName = "deadliner-diagnostics.log"
    private let jsonFileName = "deadliner-diagnostics.jsonl"
    private let directoryName = "Diagnostics"
    private let retention: TimeInterval = 14 * 24 * 60 * 60
    private let maximumFileBytes = 8 * 1_024 * 1_024
    private let pruneInterval: TimeInterval = 5 * 60
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let timestampFormatter = ISO8601DateFormatter()
    private let sessionID = UUID().uuidString.lowercased()
    private var retentionTask: Task<Void, Never>?
    private var lastPrunedAt: Date = .distantPast

    private init() {
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func append(
        _ message: String,
        level: AppLogLevel,
        category: String,
        context: [String: String]? = nil
    ) {
        let record = AppLogRecord(
            schemaVersion: 1,
            timestamp: Date().timeIntervalSince1970,
            sessionID: sessionID,
            processID: getpid(),
            level: level,
            category: category,
            message: message,
            context: context?.isEmpty == false ? context : nil
        )
        guard var data = try? encoder.encode(record) else { return }
        data.append(0x0A)

        let jsonURL = fileURL(format: .json)
        append(data, to: jsonURL)
        append(Data(standardLine(for: record).utf8), to: fileURL(format: .standard))
        if Date().timeIntervalSince(lastPrunedAt) >= pruneInterval || fileSize(at: jsonURL) > maximumFileBytes {
            pruneExpiredEntries(at: jsonURL)
        }
    }

    func exportURL(format: AppLogExportFormat) -> URL {
        let jsonURL = fileURL(format: .json)
        pruneExpiredEntries(at: jsonURL)
        return fileURL(format: format)
    }

    func exportURLs() -> [URL] {
        let jsonURL = fileURL(format: .json)
        pruneExpiredEntries(at: jsonURL)
        return [fileURL(format: .standard), jsonURL]
    }

    func clear() throws {
        try Data().write(to: fileURL(format: .standard), options: .atomic)
        try Data().write(to: fileURL(format: .json), options: .atomic)
    }

    func pruneExpiredEntries() {
        pruneExpiredEntries(at: fileURL(format: .json))
    }

    func beginSession() {
        pruneExpiredEntries()
        guard retentionTask == nil else { return }

        retentionTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.pruneExpiredEntries()
            }
        }
    }

    private func fileURL(format: AppLogExportFormat) -> URL {
        let fileManager = FileManager.default
        let base = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: KMPSharedDatabaseLocation.appGroupID
        ) ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = format == .standard ? standardFileName : jsonFileName
        return directory.appendingPathComponent(fileName)
    }

    private func append(_ data: Data, to url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: data)
            return
        }

        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            // Logging must never block or fail the user-facing operation.
        }
    }

    private func pruneExpiredEntries(at url: URL) {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return }

        let cutoff = Date().timeIntervalSince1970 - retention
        let retainedEntries = data
            .split(separator: 0x0A, omittingEmptySubsequences: true)
            .compactMap { line -> (record: AppLogRecord, data: Data)? in
                let lineData = Data(line)
                guard let record = try? decoder.decode(AppLogRecord.self, from: lineData),
                      record.timestamp >= cutoff else {
                    return nil
                }
                var output = lineData
                output.append(0x0A)
                return (record, output)
            }
        var retained = Data()
        var retainedRecords: [AppLogRecord] = []
        for entry in retainedEntries.reversed() {
            guard retained.count + entry.data.count <= maximumFileBytes || retained.isEmpty else { break }
            retained.insert(contentsOf: entry.data, at: 0)
            retainedRecords.insert(entry.record, at: 0)
        }

        if retained.count != data.count {
            try? retained.write(to: url, options: .atomic)
        }
        let standardData = retainedRecords.reduce(into: Data()) { output, record in
            output.append(contentsOf: standardLine(for: record).utf8)
        }
        try? standardData.write(to: fileURL(format: .standard), options: .atomic)
        lastPrunedAt = Date()
    }

    private func standardLine(for record: AppLogRecord) -> String {
        let source = record.category == AppLogDomain.kmp.rawValue || record.message.contains("[KMP]")
            ? "KMP"
            : "Native"
        let eventName = record.message.hasPrefix("[") && record.message.hasSuffix("]")
            ? String(record.message.dropFirst().dropLast())
            : nil
        let module = eventName ?? record.category
        let message = eventName == nil ? normalized(record.message) : ""
        let level = record.level == .info ? "" : " level=\(record.level.rawValue)"
        let fields = (record.context ?? [:])
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(normalized($0.value))" }
            .joined(separator: " ")
        let suffix = [message, fields].filter { !$0.isEmpty }.joined(separator: " ")
        return "[\(timestampFormatter.string(from: Date(timeIntervalSince1970: record.timestamp)))][\(source)][\(module)]\(level)\(suffix.isEmpty ? "" : " \(suffix)")\n"
    }

    private func normalized(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private func fileSize(at url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }
}

// MARK: - Legacy compatibility

/// Existing sync call sites keep compiling while writing to `deadliner.log`.
enum SyncDebugLog {
    static func log(_ message: String) {
        AppLog.log(message, category: "sync")
    }

    static func exportURL() async -> URL {
        await AppLog.exportURL()
    }

    static func clear() async throws {
        try await AppLog.clear()
    }

    static func clearForNewLaunchSession() {
        AppLog.beginSession()
    }
}

/// Existing AI call sites keep compiling while writing to `deadliner.log`.
enum AILog {
    static func log(_ message: String) {
        AppLog.log(message, category: "ai")
    }

    static func exportURL() async -> URL {
        await AppLog.exportURL()
    }

    static func clear() async throws {
        try await AppLog.clear()
    }

    static func clearForNewLaunchSession() {
        AppLog.beginSession()
    }
}

/// Existing icon diagnostics keep compiling while writing to `deadliner.log`.
enum IconDebugLog {
    static func log(_ message: String) {
        AppLog.log(message, category: "icon")
    }

    static func exportURL() async -> URL {
        await AppLog.exportURL()
    }

    static func clear() async throws {
        try await AppLog.clear()
    }

    static func clearForNewLaunchSession() {
        AppLog.beginSession()
    }
}
