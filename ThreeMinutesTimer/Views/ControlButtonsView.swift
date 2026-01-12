//
//  ControlButtonsView.swift
//  ThreeMinutesTimer
//
//  Control buttons component for timer state management
//

import SwiftUI
import ThreeMinutesTimerKit

struct ControlButtonsView: View {
    @Bindable var alarmManager: AlarmManager
    let onStartSession: () -> Void

    private var timerState: TimerState {
        if alarmManager.isRunning {
            return .running
        } else if alarmManager.currentInterval > 0 {
            return .paused
        } else {
            return .idle
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            switch timerState {
            case .idle:
                Button("Start Session") {
                    onStartSession()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .running:
                Button("Pause") {
                    alarmManager.pause()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Stop") {
                    alarmManager.stop()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)

            case .paused:
                Button("Resume") {
                    alarmManager.resume()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Stop") {
                    alarmManager.stop()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            }
        }
        .padding()
    }
}
