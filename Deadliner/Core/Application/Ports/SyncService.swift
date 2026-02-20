//
//  SyncService.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/16.
//

import Foundation

public protocol SyncService: Sendable {
    func syncOnce() async -> SyncResult
}
