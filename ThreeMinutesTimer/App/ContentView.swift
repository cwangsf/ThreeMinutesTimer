//
//  ContentView.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/19/25.
//

import SwiftUI
import SwiftData
import ThreeMinutesTimerKit

// MARK: - Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var sessions: [AlarmSession]
    @State private var alarmManager = AlarmManager()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Image
                Image("Portrait1")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                    // Header
                    VStack {
                        Text("Interval Alarm")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(alarmManager.themeColor.color)

                        Text("30min • 3min intervals • Alternating sounds")
                            .font(.subheadline)
                            .foregroundColor(alarmManager.themeColor.color)
                    }

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

                    // Sound Selection
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

                    // Music Selection
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

                    // Control Buttons
                    HStack(spacing: 20) {
                        if !alarmManager.isRunning {
                            Button("Start Session") {
                                startNewSession()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else {
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
                        }
                    }
                    .padding()
                    }
                }
                .onAppear {
                    requestNotificationPermission()
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                            .foregroundColor(alarmManager.themeColor.color)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(alarmManager: alarmManager)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("🔄 Scene phase changed: \(oldPhase) -> \(newPhase)")
                if newPhase == .active && oldPhase == .background {
                    print("📱 App returning to foreground")
                    alarmManager.handleAppReturningToForeground()
                } else if newPhase == .background {
                    print("📵 App going to background")
                }
            }
        }
        .tint(alarmManager.themeColor.color)
    }
    
    private func startNewSession() {
        let session = AlarmSession()
        modelContext.insert(session)
        alarmManager.startSession(session: session)
    }
    
    private func nextSound(_ current: AlarmSound) -> AlarmSound {
        let sounds = AlarmSound.allCases
        let currentIndex = sounds.firstIndex(of: current) ?? 0
        let nextIndex = (currentIndex + 1) % sounds.count
        return sounds[nextIndex]
    }

    private func nextMusic(_ current: BackgrounMusic) -> BackgrounMusic {
        let tracks = BackgrounMusic.allCases
        let currentIndex = tracks.firstIndex(of: current) ?? 0
        let nextIndex = (currentIndex + 1) % tracks.count
        return tracks[nextIndex]
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: AlarmSession.self, inMemory: true)
}
