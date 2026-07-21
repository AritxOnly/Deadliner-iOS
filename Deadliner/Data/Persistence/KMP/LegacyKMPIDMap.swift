//
//  LegacyKMPIDMap.swift
//  Deadliner
//
//  Private, importer-only bridge while feature code moves to KMP UID APIs.
//

import Foundation

enum LegacyKMPIDMap {
    private static let prefix = "persistence.kmp.legacy-id-map"
    private static let projectionSequenceKey = "\(prefix).projection-sequence"

    static func record(resource: PersistenceResourceKind, legacyID: Int64, uid: String) {
        UserDefaults.standard.set(uid, forKey: uidKey(resource: resource, legacyID: legacyID))
        UserDefaults.standard.set(legacyID, forKey: legacyKey(resource: resource, uid: uid))
    }

    static func uid(resource: PersistenceResourceKind, legacyID: Int64) -> String? {
        UserDefaults.standard.string(forKey: uidKey(resource: resource, legacyID: legacyID))
    }

    static func legacyID(resource: PersistenceResourceKind, uid: String) -> Int64? {
        let value = UserDefaults.standard.object(forKey: legacyKey(resource: resource, uid: uid)) as? NSNumber
        return value?.int64Value
    }

    /// Allocates a temporary UI identity for records created after the one-time
    /// import. Negative values cannot collide with SwiftData's positive sequence.
    static func reserveLegacyID(resource: PersistenceResourceKind, uid: String) -> Int64 {
        if let existing = legacyID(resource: resource, uid: uid) {
            return existing
        }

        let defaults = UserDefaults.standard
        let next = defaults.object(forKey: projectionSequenceKey) as? NSNumber
        let legacyID = (next?.int64Value ?? 0) - 1
        defaults.set(legacyID, forKey: projectionSequenceKey)
        record(resource: resource, legacyID: legacyID, uid: uid)
        return legacyID
    }

    private static func uidKey(resource: PersistenceResourceKind, legacyID: Int64) -> String {
        "\(prefix).\(resource.rawValue).id.\(legacyID)"
    }

    private static func legacyKey(resource: PersistenceResourceKind, uid: String) -> String {
        "\(prefix).\(resource.rawValue).uid.\(uid)"
    }
}
