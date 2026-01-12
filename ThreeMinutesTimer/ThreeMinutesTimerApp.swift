//
//  ThreeMinutesTimerApp.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/19/25.
//

import SwiftUI
import SwiftData
import ThreeMinutesTimerKit

// MARK: - Main App
@main
struct IntervalAlarmApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: AlarmSession.self)
    }
}
