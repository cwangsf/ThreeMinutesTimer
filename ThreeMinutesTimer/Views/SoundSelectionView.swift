//
//  SoundSelectionView.swift
//  ThreeMinutesTimer
//
//  Sound selection component for alarm sounds
//

import SwiftUI
import ThreeMinutesTimerKit

struct SoundSelectionView: View {
    @Bindable var alarmManager: AlarmManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alarm Sounds")
                .font(.headline)
                .foregroundColor(alarmManager.themeColor.color)

            HStack {
                VStack {
                    Text("Sound A")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(alarmManager.soundA.rawValue) {
                        alarmManager.soundA = nextSound(alarmManager.soundA)
                    }
                    .buttonStyle(.bordered)
                    .disabled(alarmManager.isRunning)
                }

                Spacer()

                VStack {
                    Text("Sound B")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(alarmManager.soundB.rawValue) {
                        alarmManager.soundB = nextSound(alarmManager.soundB)
                    }
                    .buttonStyle(.bordered)
                    .disabled(alarmManager.isRunning)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }

    private func nextSound(_ current: AlarmSound) -> AlarmSound {
        let sounds = AlarmSound.allCases
        let currentIndex = sounds.firstIndex(of: current) ?? 0
        let nextIndex = (currentIndex + 1) % sounds.count
        return sounds[nextIndex]
    }
}
