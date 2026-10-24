//
//  Item.swift
//  AutoGuard
//
//  Created by Dragos Dima on 24.10.2026.
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
