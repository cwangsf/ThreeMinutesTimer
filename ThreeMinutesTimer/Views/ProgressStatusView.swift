//
//  ProgressStatusView.swift
//  ThreeMinutesTimer
//
//  Progress circle and status display component
//

import SwiftUI
import ThreeMinutesTimerKit

struct ProgressStatusView: View {
    var alarmManager: AlarmManager

    var body: some View {
        VStack(spacing: 20) {
            // Progress Circle
            ProgressCircleView(alarmManager: alarmManager)

            // Status
            VStack {
                Text(alarmManager.statusText)
                    .font(.headline)
                    .foregroundColor(alarmManager.isRunning ? alarmManager.themeColor.color : .secondary)

                if alarmManager.isRunning {
                    Text("Sound: \(alarmManager.currentSoundName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
