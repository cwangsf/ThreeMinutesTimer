//
//  AlarmManager.swift
//  ThreeMinutesTimer
//
//  Created by Cynthia Wang on 8/23/25.
//


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

// MARK: - Alarm Manager
@Observable
class AlarmManager {
    var isRunning = false
    var currentInterval = 0
    var progress: Double = 0
    var timeRemaining = "3:00"
    var soundA: AlarmSound = .bell
    var soundB: AlarmSound = .chime
    
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


