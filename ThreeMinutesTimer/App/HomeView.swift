//
//  HomeView.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/19/25.
//

import SwiftUI
import SwiftData
import ThreeMinutesTimerKit

// MARK: - Home View
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var sessions: [AlarmSession]
    @State private var alarmManager = AlarmManager()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                getBackgroundImage()
                
                ScrollView {
                    VStack() {
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

                    // Progress & Status
                    ProgressStatusView(alarmManager: alarmManager)

                    // Sound Selection
                    //SoundSelectionView(alarmManager: alarmManager)

                    // Music Selection
                    MusicSelectionView(alarmManager: alarmManager)

                    // Control Buttons
                    ControlButtonsView(alarmManager: alarmManager) {
                        startNewSession()
                    }
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

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    //TODO: get the background image list and rotate them, the background color with change by extracting the main color's opposite color
    private func getBackgroundImage() -> some View {
        // Background Image
        Image("Portrait1")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: AlarmSession.self, inMemory: true)
}
