//
//  ICloudSyncBlobTransport.swift
//  Deadliner
//
//  Native iCloud Drive storage adapter for Shared's provider-neutral sync contract.
//

#if canImport(Shared) && canImport(CryptoKit)
import CryptoKit
import Foundation
import Shared

/// Stores KMP sync blobs in the app's iCloud Drive ubiquitous container.
/// Business merge and payload ownership remain in Shared; this type owns only
/// native file coordination and optimistic version checks.
final class ICloudSyncBlobTransport: NSObject, SyncBlobTransport, @unchecked Sendable {
    static let containerIdentifier = "iCloud.top.aritxonly.deadliner"

    private let fileManager: FileManager
    private let workQueue = DispatchQueue(label: "top.aritxonly.deadliner.sync.icloud")

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func close() {}

    func ensureCollection(
        path: String,
        completionHandler: @escaping (KotlinBoolean?, Error?) -> Void
    ) {
        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let url = try self.url(for: path, directory: true)
                try self.fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                completionHandler(KotlinBoolean(bool: true), nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    func read(
        path: String,
        completionHandler: @escaping (SyncBlob?, Error?) -> Void
    ) {
        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let url = try self.url(for: path)
                var data: Data?
                try self.coordinateReading(url) { coordinatedURL in
                    guard self.fileManager.fileExists(atPath: coordinatedURL.path) else { return }
                    data = try Data(contentsOf: coordinatedURL)
                }
                guard let data else {
                    completionHandler(nil, nil)
                    return
                }
                completionHandler(
                    SyncBlob(bytes: Self.kotlinBytes(from: data), version: Self.version(for: data)),
                    nil
                )
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    func write(
        path: String,
        bytes: KotlinByteArray,
        condition: any SyncWriteCondition,
        completionHandler: @escaping (Error?) -> Void
    ) {
        workQueue.async { [weak self] in
            guard let self else { return }
            do {
                let url = try self.url(for: path)
                try self.fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = Self.data(from: bytes)
                try self.coordinateWriting(url) { coordinatedURL in
                    let currentData = self.fileManager.fileExists(atPath: coordinatedURL.path)
                        ? try Data(contentsOf: coordinatedURL)
                        : nil
                    try self.validate(condition: condition, currentData: currentData)
                    try data.write(to: coordinatedURL, options: .atomic)
                }
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    private func validate(condition: any SyncWriteCondition, currentData: Data?) throws {
        if condition is SyncWriteConditionCreateOnly {
            guard currentData == nil else { throw SyncTransportPreconditionFailedException() }
            return
        }
        if let match = condition as? SyncWriteConditionMatchVersion {
            guard let currentData, Self.version(for: currentData) == match.value else {
                throw SyncTransportPreconditionFailedException()
            }
        }
    }

    private func url(for path: String, directory: Bool = false) throws -> URL {
        let segments = path.split(separator: "/").map(String.init)
        guard !segments.isEmpty, segments.allSatisfy({ $0 != "." && $0 != ".." && !$0.isEmpty }) else {
            throw ICloudSyncBlobTransportError.invalidPath
        }
        guard let container = fileManager.url(forUbiquityContainerIdentifier: Self.containerIdentifier) else {
            throw ICloudSyncBlobTransportError.containerUnavailable
        }
        let documents = container.appendingPathComponent("Documents", isDirectory: true)
        try fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
        return segments.reduce(documents) { partial, segment in
            partial.appendingPathComponent(segment, isDirectory: directory && segment == segments.last)
        }
    }

    private func coordinateReading(_ url: URL, accessor: (URL) throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var accessorError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try accessor(coordinatedURL)
            } catch {
                accessorError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let accessorError { throw accessorError }
    }

    private func coordinateWriting(_ url: URL, accessor: (URL) throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var accessorError: Error?
        coordinator.coordinate(writingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try accessor(coordinatedURL)
            } catch {
                accessorError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let accessorError { throw accessorError }
    }

    private static func version(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func kotlinBytes(from data: Data) -> KotlinByteArray {
        let result = KotlinByteArray(size: Int32(data.count))
        for (offset, value) in data.enumerated() {
            result.set(index: Int32(offset), value: Int8(bitPattern: value))
        }
        return result
    }

    private static func data(from bytes: KotlinByteArray) -> Data {
        Data((0 ..< Int(bytes.size)).map { UInt8(bitPattern: bytes.get(index: Int32($0))) })
    }
}

private enum ICloudSyncBlobTransportError: LocalizedError {
    case containerUnavailable
    case invalidPath

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "iCloud Drive is unavailable. Sign in to iCloud and enable iCloud Drive before syncing."
        case .invalidPath:
            return "The KMP sync provider requested an invalid iCloud path."
        }
    }
}
#endif
