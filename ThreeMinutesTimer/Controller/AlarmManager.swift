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
import Dispatch
import UIKit
import ObjectiveC

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
class AlarmManager: NSObject, AVAudioPlayerDelegate {
    var isRunning = false
    var currentInterval = 0
    var progress: Double = 0
    var timeRemaining = "3:00"
    var soundA: AlarmSound = .bell
    var soundB: AlarmSound = .chime
    var musicA: MusicTrack = .musicA
    var musicB: MusicTrack = .musicB
    var themeColor: ThemeColor {
        didSet {
            UserDefaults.standard.set(themeColor.rawValue, forKey: "themeColor")
        }
    }

    private var timer: Timer?
    private var dispatchTimer: DispatchSourceTimer?
    private var currentSession: AlarmSession?
    var secondsRemaining = 180 // 3 minutes
    private let intervalDuration = 180 // 3 minutes in seconds
    private let totalIntervals = 10
    private var musicPlayer: AVPlayer?
    private var alertPlayer: AVAudioPlayer?
    private var audioSessionActivated = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
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
    
    override init() {
        // Load saved theme color
        if let savedColorString = UserDefaults.standard.string(forKey: "themeColor"),
           let savedColor = ThemeColor(rawValue: savedColorString) {
            self.themeColor = savedColor
        } else {
            self.themeColor = .purple
        }

        // Initialize NSObject
        super.init()

        setupAudioSession()
        setupAudioSessionInterruptionHandling()
    }

    private func setupAudioSessionInterruptionHandling() {
        let audioSession = AVAudioSession.sharedInstance()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(notification:)),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        print("🎧 Audio session interruption handler registered")
    }

    @objc private func handleAudioSessionInterruption(notification: Notification) {
        print("🎧 Audio session interruption received")
        guard let userInfo = notification.userInfo else {
            print("❌ No userInfo in interruption notification")
            return
        }

        guard let typeValue = userInfo["AVAudioSessionInterruptionTypeKey"] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            print("❌ Could not get interruption type from userInfo")
            return
        }

        print("🎧 Audio session interruption: \(type == .began ? "BEGAN" : "ENDED")")

        if type == .ended {
            // Resume playback after interruption
            if isRunning && musicPlayer != nil {
                print("▶️ Resuming music after interruption ended")
                musicPlayer?.play()
            }
        }
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            // Use empty options to NOT deactivate on interruption
            try audioSession.setActive(true)
            audioSessionActivated = true
            print("✅ Audio session setup successfully")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
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

            // Play music for current interval since we just entered it
            playCurrentMusic()
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
        setupAudioSession()
        requestBackgroundTask()
        startTimer()
        playCurrentMusic()
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        dispatchTimer?.cancel()
        dispatchTimer = nil
        musicPlayer?.pause()
        musicPlayer = nil
        alertPlayer?.stop()
        alertPlayer = nil
        endBackgroundTask()
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        dispatchTimer?.cancel()
        dispatchTimer = nil
        musicPlayer?.pause()
        musicPlayer = nil
        alertPlayer?.stop()
        alertPlayer = nil
        currentInterval = 0
        progress = 0
        secondsRemaining = intervalDuration
        updateTimeRemaining()
        endBackgroundTask()

        if let session = currentSession {
            session.endTime = Date()
            session.completedIntervals = currentInterval
        }
        currentSession = nil
        intervalStartTime = nil
        sessionStartTime = nil
    }
    
    private func startTimer() {
        let queue = DispatchQueue.global(qos: .userInitiated)
        dispatchTimer = DispatchSource.makeTimerSource(queue: queue)
        dispatchTimer?.schedule(wallDeadline: .now(), repeating: 1.0)
        dispatchTimer?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                // If player is paused but we're still running, resume it
                if let player = self?.musicPlayer, self?.isRunning == true {
                    if player.timeControlStatus == .paused {
                        print("⚠️ Player was paused, resuming...")
                        player.play()
                    }
                    print("🎵 Timer tick - Player status: \(player.timeControlStatus.rawValue), currentTime: \(player.currentTime().seconds)")
                }
                self?.updateTimer()
            }
        }
        dispatchTimer?.resume()
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
        // Play alert sound at the end of the interval
        playAlertSound()

        currentInterval += 1

        if currentInterval >= totalIntervals {
            // Session completed
            completeSession()
        } else {
            // Start next interval with music
            secondsRemaining = intervalDuration
            intervalStartTime = Date()

            // Schedule music to play after alert finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playCurrentMusic()
            }
        }
    }
    
    private func completeSession() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        dispatchTimer?.cancel()
        dispatchTimer = nil
        musicPlayer?.pause()
        musicPlayer = nil
        alertPlayer?.stop()
        alertPlayer = nil
        endBackgroundTask()

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
    
    private func playCurrentMusic() {
        let music = (currentInterval % 2 == 0) ? musicA : musicB
        playMusic(music)
    }

    private func playAlertSound() {
        let sound = (currentInterval % 2 == 0) ? soundA : soundB
        playAlertSoundWithType(sound)
    }

    private func playAlertSoundWithType(_ sound: AlarmSound) {
        guard let url = Bundle.main.url(forResource: sound.filename, withExtension: "mp3") else {
            // Fallback to system sound
            playSystemSound()
            return
        }

        do {
            alertPlayer = try AVAudioPlayer(contentsOf: url)
            alertPlayer?.delegate = self
            alertPlayer?.play()
            print("Playing alert sound: \(sound.rawValue)")
        } catch {
            print("Error playing alert sound: \(error)")
            playSystemSound()
        }
    }

    private func playMusic(_ music: MusicTrack) {
        guard let url = Bundle.main.url(forResource: music.filename, withExtension: "mp3") else {
            print("❌ Music file not found: \(music.filename)")
            return
        }

        print("📁 Music URL: \(url)")

        // Ensure audio session is active before playing
        if !audioSessionActivated {
            print("🔊 Setting up audio session before playing")
            setupAudioSession()
        }

        print("🎵 Creating AVPlayer with URL")
        let playerItem = AVPlayerItem(url: url)
        musicPlayer = AVPlayer(playerItem: playerItem)
        musicPlayer?.volume = 1.0

        // Add observer to track playback status
        if let player = musicPlayer {
            print("👀 Adding status observer")
            let observer = player.observe(\.status) { player, _ in
                print("🎬 AVPlayer status changed: \(player.status.rawValue)")
                switch player.status {
                case .readyToPlay:
                    print("✅ Player ready to play")
                case .failed:
                    print("❌ Player failed: \(player.error?.localizedDescription ?? "Unknown")")
                case .unknown:
                    print("❓ Player status unknown")
                @unknown default:
                    print("⚠️ Unknown player status")
                }
            }
            // Store observer to prevent deallocation
            objc_setAssociatedObject(player, "statusObserver", observer, .OBJC_ASSOCIATION_RETAIN)
        }

        print("▶️ Calling play()")
        musicPlayer?.play()

        // Check immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let player = self.musicPlayer {
                print("🎵 After 0.1s - timeControlStatus: \(player.timeControlStatus.rawValue), currentTime: \(player.currentTime().seconds)")
            }
        }

        // Check after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let player = self.musicPlayer {
                print("🎵 After 1.0s - timeControlStatus: \(player.timeControlStatus.rawValue), currentTime: \(player.currentTime().seconds)")
            }
        }

        print("✅ Playing music with AVPlayer: \(music.rawValue), isPlaying: \(musicPlayer?.timeControlStatus == .playing)")
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

    // MARK: - Background Task Management
    private func requestBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        print("Background task requested: \(backgroundTaskID.rawValue)")
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("Background task ended")
        }
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("Audio finished playing successfully")
        } else {
            print("Audio playback interrupted")
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio decode error: \(error)")
        }
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

// MARK: - Music Tracks
enum MusicTrack: String, CaseIterable {
    case musicA = "Music A"
    case musicB = "Music B"

    var filename: String {
        switch self {
        case .musicA: return "musicA"
        case .musicB: return "musicB"
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


