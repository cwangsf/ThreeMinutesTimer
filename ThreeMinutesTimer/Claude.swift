//
//  Claude.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/19/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import UserNotifications

// MARK: - Models
@Model
class AlarmSession {
    var id = UUID()
    var startTime = Date()
    var endTime: Date?
    var totalIntervals = 10
    var completedIntervals = 0
    var isCompleted = false
    
    init() {}
}

// MARK: - Main App
//@main
//struct IntervalAlarmApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//        .modelContainer(for: AlarmSession.self)
//    }
//}

// MARK: - Content View
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [AlarmSession]
    @StateObject private var alarmManager = AlarmManager()
    
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
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: alarmManager.progress)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: alarmManager.progress)
                    
                    VStack {
                        Text("Interval")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(alarmManager.currentInterval + 1)/10")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if alarmManager.isRunning {
                            Text(alarmManager.timeRemaining)
                                .font(.title2)
                                .foregroundColor(.blue)
                                .monospacedDigit()
                        }
                    }
                }
                
                // Status
                VStack {
                    Text(alarmManager.statusText)
                        .font(.headline)
                        .foregroundColor(alarmManager.isRunning ? .blue : .secondary)
                    
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
            .navigationBarHidden(true)
        }
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

// MARK: - Alarm Manager
class AlarmManager: ObservableObject {
    @Published var isRunning = false
    @Published var currentInterval = 0
    @Published var progress: Double = 0
    @Published var timeRemaining = "3:00"
    @Published var soundA: AlarmSound = .bell
    @Published var soundB: AlarmSound = .chime
    
    private var timer: Timer?
    private var currentSession: AlarmSession?
    private var secondsRemaining = 180 // 3 minutes
    private let intervalDuration = 180 // 3 minutes in seconds
    private let totalIntervals = 10
    private var audioPlayer: AVAudioPlayer?
    
    var statusText: String {
        if !isRunning && currentInterval == 0 {
            return "Ready to start"
        } else if !isRunning && currentInterval > 0 {
            return "Paused"
        } else if currentInterval >= totalIntervals {
            return "Session completed!"
        } else {
            return "Interval \(currentInterval + 1) active"
        }
    }
    
    var currentSoundName: String {
        let sound = (currentInterval % 2 == 0) ? soundA : soundB
        return sound.rawValue
    }
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func startSession(session: AlarmSession) {
        currentSession = session
        currentInterval = 0
        secondsRemaining = intervalDuration
        isRunning = true
        startTimer()
        playCurrentSound()
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        currentInterval = 0
        progress = 0
        secondsRemaining = intervalDuration
        updateTimeRemaining()
        
        if let session = currentSession {
            session.endTime = Date()
            session.completedIntervals = currentInterval
        }
        currentSession = nil
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTimer()
        }
    }
    
    private func updateTimer() {
        secondsRemaining -= 1
        updateProgress()
        updateTimeRemaining()
        
        if secondsRemaining <= 0 {
            completeInterval()
        }
    }
    
    private func completeInterval() {
        currentInterval += 1
        
        if currentInterval >= totalIntervals {
            // Session completed
            completeSession()
        } else {
            // Start next interval
            secondsRemaining = intervalDuration
            playCurrentSound()
        }
    }
    
    private func completeSession() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        
        if let session = currentSession {
            session.endTime = Date()
            session.completedIntervals = totalIntervals
            session.isCompleted = true
        }
        
        // Show completion notification
        scheduleNotification(title: "Session Complete!", body: "Your 30-minute interval session has finished.")
    }
    
    private func updateProgress() {
        let totalSeconds = Double(totalIntervals * intervalDuration)
        let elapsedSeconds = Double(currentInterval * intervalDuration) + Double(intervalDuration - secondsRemaining)
        progress = elapsedSeconds / totalSeconds
    }
    
    private func updateTimeRemaining() {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        timeRemaining = String(format: "%d:%02d", minutes, seconds)
    }
    
    private func playCurrentSound() {
        let sound = (currentInterval % 2 == 0) ? soundA : soundB
        playSound(sound)
    }
    
    private func playSound(_ sound: AlarmSound) {
        guard let url = Bundle.main.url(forResource: sound.filename, withExtension: "mp3") else {
            // Fallback to system sound
            playSystemSound()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error)")
            playSystemSound()
        }
    }
    
    private func playSystemSound() {
        // Fallback system sound
        AudioServicesPlaySystemSound(1005) // System sound ID for alarm
    }
    
    private func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Alarm Sounds
enum AlarmSound: String, CaseIterable {
    case bell = "Bell"
    case chime = "Chime"
    case beep = "Beep"
    case tone = "Tone"
    case alert = "Alert"
    
    var filename: String {
        switch self {
        case .bell: return "bell"
        case .chime: return "chime"
        case .beep: return "beep"
        case .tone: return "tone"
        case .alert: return "alert"
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
        .modelContainer(for: AlarmSession.self, inMemory: true)
}
