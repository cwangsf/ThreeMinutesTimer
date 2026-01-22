//
//  MusicSelectionView.swift
//  ThreeMinutesTimer
//
//  Music selection component for background music
//

import SwiftUI
import ThreeMinutesTimerKit

struct MusicSelectionView: View {
    @Bindable var alarmManager: AlarmManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background Music")
                .font(.headline)
                .foregroundColor(alarmManager.themeColor.color)

            HStack {
                VStack {
                    Text("Music A")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(alarmManager.musicA.rawValue) {
                        alarmManager.musicA = nextMusic(alarmManager.musicA)
                    }
                    .buttonStyle(.bordered)
                    .disabled(alarmManager.isRunning)
                }

                Spacer()

                VStack {
                    Text("Music B")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(alarmManager.musicB.rawValue) {
                        alarmManager.musicB = nextMusic(alarmManager.musicB)
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

    private func nextMusic(_ current: BackgrounMusic) -> BackgrounMusic {
        let tracks = BackgrounMusic.allCases
        let currentIndex = tracks.firstIndex(of: current) ?? 0
        let nextIndex = (currentIndex + 1) % tracks.count
        return tracks[nextIndex]
    }
}
