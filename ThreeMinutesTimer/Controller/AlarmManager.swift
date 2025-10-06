//
//  AlarmManager.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/23/25.
//


import SwiftData
import AVFoundation
import UserNotifications
import SwiftUI

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

// MARK: - Alarm Manager
@Observable
class AlarmManager {
    var isRunning = false
    var currentInterval = 0
    var progress: Double = 0
    var timeRemaining = "3:00"
    var soundA: AlarmSound = .bell
    var soundB: AlarmSound = .chime
    var themeColor: ThemeColor {
        didSet {
            UserDefaults.standard.set(themeColor.rawValue, forKey: "themeColor")
        }
    }

    private var timer: Timer?
    private var currentSession: AlarmSession?
    private var secondsRemaining = 10 // 3 minutes
    private let intervalDuration = 10 // 3 minutes in seconds
    private let totalIntervals = 10
    private var audioPlayer: AVAudioPlayer?
    private var intervalStartTime: Date?
    private var sessionStartTime: Date?
    
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
        // Load saved theme color
        if let savedColorString = UserDefaults.standard.string(forKey: "themeColor"),
           let savedColor = ThemeColor(rawValue: savedColorString) {
            self.themeColor = savedColor
        } else {
            self.themeColor = .purple
        }

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

    func handleAppReturningToForeground() {
        guard isRunning, let startTime = intervalStartTime else { return }

        // Recalculate time based on actual elapsed time
        let elapsed = Date().timeIntervalSince(startTime)
        let totalElapsedSeconds = Int(elapsed)

        // Check if we missed any intervals
        let missedIntervals = totalElapsedSeconds / intervalDuration

        if missedIntervals > 0 {
            // We missed one or more intervals while in background
            currentInterval += missedIntervals

            if currentInterval >= totalIntervals {
                completeSession()
                return
            }

            // Play sound for current interval since we just entered it
            playCurrentSound()
        }

        // Calculate seconds into current interval
        let secondsIntoInterval = totalElapsedSeconds % intervalDuration
        secondsRemaining = intervalDuration - secondsIntoInterval

        if secondsRemaining <= 0 {
            completeInterval()
        } else {
            updateProgress()
            updateTimeRemaining()
        }
    }
    
    func startSession(session: AlarmSession) {
        currentSession = session
        currentInterval = 0
        secondsRemaining = intervalDuration
        isRunning = true
        sessionStartTime = Date()
        intervalStartTime = Date()
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
        intervalStartTime = nil
        sessionStartTime = nil
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
            intervalStartTime = Date()
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

        intervalStartTime = nil
        sessionStartTime = nil

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

// MARK: - Theme Color
enum ThemeColor: String, CaseIterable, Codable {
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case orange = "Orange"
    case green = "Green"
    case red = "Red"

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .red: return .red
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .blue: return [.blue, .cyan]
        case .purple: return [.purple, .pink]
        case .pink: return [.pink, .orange]
        case .orange: return [.orange, .yellow]
        case .green: return [.green, .mint]
        case .red: return [.red, .orange]
        }
    }
}


