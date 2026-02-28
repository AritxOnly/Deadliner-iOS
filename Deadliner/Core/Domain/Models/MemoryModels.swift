//
//  MemoryModels.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/22.
//

import Foundation
import Combine

struct MemoryFragment: Codable, Identifiable {
    var id = UUID()
    let content: String
    let category: String
    let timestamp: Date
    let importance: Int
}

final class MemoryBank: ObservableObject {
    static let shared = MemoryBank()

    @Published private(set) var fragments: [MemoryFragment] = []

    @Published private(set) var userProfile: String = ""

    private let storageKey = "deadliner_local_memories"
    private let storageProfileKey = "deadliner_user_profile"
    
    private let maxFragments = 60
    private let maxAgeDays = 120

    private init() {
        loadFromDisk()
        loadProfileFromDisk()
    }

    func saveMemory(content: String, category: String = "Auto") {
        let newFrag = MemoryFragment(content: content, category: category, timestamp: Date(), importance: 3)
        guard !fragments.contains(where: { $0.content == content }) else { return }

        DispatchQueue.main.async {
            self.fragments.append(newFrag)
            self.pruneMemories()
            self.saveToDisk()
        }
    }

    func saveUserProfile(_ profile: String) {
        let trimmed = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        DispatchQueue.main.async {
            self.userProfile = trimmed
            self.saveProfileToDisk()
        }
    }
    
    func getLongTermContext(maxProfileChars: Int = 420, maxBullets: Int = 6, maxTotalChars: Int = 900) -> String {
        var parts: [String] = []

        let p = String(userProfile.prefix(maxProfileChars)).trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty {
            parts.append("【用户画像】\n\(p)")
        } else {
            parts.append("【用户画像】\n(暂无)")
        }

        if !fragments.isEmpty, maxBullets > 0 {
            let bullets = fragments.suffix(maxBullets).map { "- \($0.content)" }.joined(separator: "\n")
            parts.append("【近期用户偏好/事实】\n\(bullets)")
        }

        let joined = parts.joined(separator: "\n\n")
        return String(joined.prefix(maxTotalChars))
    }

    // MARK: - Local Persistence
    private func saveToDisk() {
        if let encoded = try? JSONEncoder().encode(fragments) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func loadFromDisk() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MemoryFragment].self, from: data) {
            self.fragments = decoded
        }
    }

    private func saveProfileToDisk() {
        UserDefaults.standard.set(userProfile, forKey: storageProfileKey)
    }

    private func loadProfileFromDisk() {
        if let s = UserDefaults.standard.string(forKey: storageProfileKey) {
            self.userProfile = s
        }
    }

    func clearAllMemories() {
        fragments.removeAll()
        userProfile = ""
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: storageProfileKey)
    }
    
    // MARK: - Editing / Deleting

    func setUserProfileAllowEmpty(_ profile: String) {
        let trimmed = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
            self.userProfile = trimmed
            self.saveProfileToDisk()
        }
    }

    func deleteFragment(id: UUID) {
        DispatchQueue.main.async {
            self.fragments.removeAll { $0.id == id }
            self.saveToDisk()
        }
    }

    func updateFragment(id: UUID, newContent: String, newCategory: String? = nil, newImportance: Int? = nil) {
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async {
            guard let idx = self.fragments.firstIndex(where: { $0.id == id }) else { return }
            let old = self.fragments[idx]
            let updated = MemoryFragment(
                id: old.id,
                content: trimmed.isEmpty ? old.content : trimmed,
                category: newCategory ?? old.category,
                timestamp: old.timestamp,
                importance: newImportance ?? old.importance
            )
            self.fragments[idx] = updated
            self.saveToDisk()
        }
    }

    func replaceAllFragments(_ newList: [MemoryFragment]) {
        DispatchQueue.main.async {
            self.fragments = newList
            self.saveToDisk()
        }
    }
    
    private func pruneMemories() {
        // 1) 先按时间过期淘汰
        let now = Date()
        let cutoff = now.addingTimeInterval(TimeInterval(-maxAgeDays) * 86400)
        fragments = fragments.filter { $0.timestamp >= cutoff }

        // 2) 超容量：优先删“低重要度 + 更旧”的
        if fragments.count > maxFragments {
            fragments.sort {
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                return $0.timestamp > $1.timestamp
            }
            fragments = Array(fragments.prefix(maxFragments))
        }
    }
}
