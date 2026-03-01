//
//  TaskWritePort.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/28.
//

import Foundation

protocol TaskWritePort {
    func insertDDL(_ params: DDLInsertParams) async throws -> Int64
}
