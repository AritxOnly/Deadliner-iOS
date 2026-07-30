//
//  AIStdStreamCapture.swift
//  Deadliner
//

import Foundation
import Darwin

/// Application-wide stdout/stderr tee. It captures Swift `print`, Kotlin
/// `println`, and `NSLog` into the unified local log buffer while preserving
/// Xcode console output.
final class AppStdStreamCapture {
    static let shared = AppStdStreamCapture()

    private let queue = DispatchQueue(label: "deadliner.app.stdout.capture")
    private var readSource: DispatchSourceRead?

    private var isStarted = false
    private var pipeReadFD: Int32 = -1
    private var pipeWriteFD: Int32 = -1
    private var stdoutBackupFD: Int32 = -1
    private var stderrBackupFD: Int32 = -1

    private var pendingLine = ""

    private init() {}

    func startIfNeeded() {
        guard !isStarted else { return }
        isStarted = true

        // Disable stdio buffering so Swift/Kotlin prints can be flushed immediately.
        setvbuf(stdout, nil, _IONBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)

        var fds: [Int32] = [0, 0]
        guard pipe(&fds) == 0 else {
            isStarted = false
            return
        }

        pipeReadFD = fds[0]
        pipeWriteFD = fds[1]
        _ = fcntl(pipeReadFD, F_SETFL, fcntl(pipeReadFD, F_GETFL) | O_NONBLOCK)
        stdoutBackupFD = dup(STDOUT_FILENO)
        stderrBackupFD = dup(STDERR_FILENO)

        guard stdoutBackupFD >= 0, stderrBackupFD >= 0 else {
            closeIfNeeded(pipeReadFD)
            closeIfNeeded(pipeWriteFD)
            isStarted = false
            return
        }

        // Route both stdout/stderr to the same pipe.
        _ = dup2(pipeWriteFD, STDOUT_FILENO)
        _ = dup2(pipeWriteFD, STDERR_FILENO)

        let source = DispatchSource.makeReadSource(fileDescriptor: pipeReadFD, queue: queue)
        source.setEventHandler { [weak self] in
            self?.drainPipe()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            self.closeIfNeeded(self.pipeReadFD)
            self.closeIfNeeded(self.pipeWriteFD)
        }
        source.resume()
        readSource = source

        AILog.log("[StdCapture] started")
    }

    private func drainPipe() {
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let count = read(pipeReadFD, &buffer, buffer.count)
            if count > 0 {
                let data = Data(buffer[0..<count])
                mirrorToOriginalConsole(data: data)
                collectForAppLog(data: data)
            } else {
                break
            }
        }
    }

    private func mirrorToOriginalConsole(data: Data) {
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            if stdoutBackupFD >= 0 {
                _ = write(stdoutBackupFD, base, raw.count)
            }
            if stderrBackupFD >= 0 {
                _ = write(stderrBackupFD, base, raw.count)
            }
        }
    }

    private func collectForAppLog(data: Data) {
        guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }

        pendingLine += chunk
        let parts = pendingLine.components(separatedBy: .newlines)

        if parts.isEmpty {
            return
        }

        for line in parts.dropLast() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Kotlin's iOS runtime writes through stdout. Preserve it in the
            // same durable log, but distinguish it from unstructured Swift
            // prints so a report can be filtered by runtime boundary.
            let domain: AppLogDomain = trimmed.contains("[KMP]") || trimmed.contains("Kotlin") ? .kmp : .stdio
            AppLog.log(trimmed, category: domain.rawValue)
        }

        pendingLine = parts.last ?? ""
    }

    private func closeIfNeeded(_ fd: Int32) {
        if fd >= 0 {
            close(fd)
        }
    }
}

/// Source compatibility for callers not yet migrated to the app-wide name.
typealias AIStdStreamCapture = AppStdStreamCapture
