//
//  RYFTWidgetsBundle.swift
//  RYFTWidgets
//
//  Created by Garrett Spencer on 3/24/26.
//

import WidgetKit
import SwiftUI

@main
struct RYFTWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RYFTWidgets()
        RYFTWidgetsControl()
        RYFTWidgetsLiveActivity()
    }
}
