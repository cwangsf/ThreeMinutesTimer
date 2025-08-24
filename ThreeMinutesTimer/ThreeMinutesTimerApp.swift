//
//  ThreeMinutesTimerApp.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/19/25.
//

import SwiftUI
import SwiftData

// MARK: - Main App
@main
struct IntervalAlarmApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: AlarmSession.self)
    }
}
