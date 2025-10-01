//
//  ContentView.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/19/25.
//

import SwiftUI
import SwiftData

// MARK: - Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [AlarmSession]
    @State private var alarmManager = AlarmManager()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack {
                    Text("Interval Alarm")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("30min • 3min intervals • Alternating sounds")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
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
                
                Spacer()
                
                // Sound Selection
                VStack(alignment: .leading, spacing: 10) {
                    Text("Alarm Sounds")
                        .font(.headline)
                    
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
            }
            .padding()
            .onAppear {
                requestNotificationPermission()
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
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: AlarmSession.self, inMemory: true)
}
