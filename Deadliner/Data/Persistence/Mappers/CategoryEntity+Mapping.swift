//
//  CategoryEntity+Mapping.swift
//  Deadliner
//
//  Created by Codex on 2026/7/17.
//

import Foundation

extension CategoryEntity {
    func toDomain() -> TaskCategory {
        TaskCategory(
            uid: uid,
            name: name,
            iconKey: iconKey,
            colorHex: colorHex,
            isPreset: isPreset,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func toSnapshotV2Doc() -> CategorySnapshotV2Doc {
        CategorySnapshotV2Doc(
            name: name,
            icon_key: iconKey,
            color_hex: colorHex,
            is_preset: isPreset ? 1 : 0,
            sort_order: sortOrder,
            created_at: createdAt,
            updated_at: updatedAt
        )
    }
}
