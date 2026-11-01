//
//  TorpedouWidgetBundle.swift
//  TorpedouWidget
//
//  Created by Dragos Dima on 01.11.2026.
//

import WidgetKit
import SwiftUI

@main
struct TorpedouWidgetBundle: WidgetBundle {
    var body: some Widget {
        TorpedouWidget()
        TorpedouWidgetControl()
        TorpedouWidgetLiveActivity()
    }
}
