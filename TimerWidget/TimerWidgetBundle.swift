//
//  TimerWidgetBundle.swift
//  TimerWidget
//
//  Created by Cynthia Wang on 1/6/26.
//

import WidgetKit
import SwiftUI

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerWidget()
        TimerWidgetControl()
        TimerWidgetLiveActivity()
    }
}
