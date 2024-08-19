//
//  Item.swift
//  WarframeInfoHub
//
//  Created by Miklós Lekszikov on 10.08.24.
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
