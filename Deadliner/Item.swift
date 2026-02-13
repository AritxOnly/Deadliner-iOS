//
//  Item.swift
//  Deadliner
//
//  Created by Aritx 音唯 on 2026/2/13.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
