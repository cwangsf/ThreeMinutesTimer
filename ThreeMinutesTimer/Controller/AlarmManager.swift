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
import ThreeMinutesTimerKit
import ActivityKit

// MARK: - Alarm Manager
@Observable
class AlarmManager: NSObject, AVAudioPlayerDelegate {
    // Timer core (shared business logic)
    private var timerCore = TimerCore()

    // Public properties delegated to TimerCore
    var isRunning: Bool { timerCore.isRunning }
    var currentInterval: Int { timerCore.currentInterval }
    var progress: Double { timerCore.progress }
    var timeRemaining: String { timerCore.timeRemaining }
    var statusText: String { timerCore.statusText }
    var secondsRemaining: Int { timerCore.secondsRemaining }

    // Audio preferences
    var soundA: AlarmSound = .bell
    var soundB: AlarmSound = .chime
    var musicA: BackgrounMusic = .musicA
    var musicB: BackgrounMusic = .musicB
    var themeColor: ThemeColor {
        didSet {
            UserDefaults.standard.set(themeColor.rawValue, forKey: "themeColor")
        }
    }

    // Platform-specific (iOS)
    private var dispatchTimer: DispatchSourceTimer?
    private var musicPlayer: AVPlayer?
    private var alertPlayer: AVAudioPlayer?
    private var audioSessionActivated = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // Live Activity
    private var currentActivity: Activity<TimerWidgetAttributes>?
    private var liveActivityUpdateCounter = 0

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

        // Set up TimerCore callbacks
        setupTimerCoreCallbacks()

        setupAudioSession()
        setupAudioSessionInterruptionHandling()
    }

    private func setupTimerCoreCallbacks() {
        timerCore.onIntervalComplete = { [weak self] completedInterval in
            guard let self = self else { return }
            self.playAlertSound()
            // Update Live Activity immediately when interval changes
            self.updateLiveActivity()
            self.liveActivityUpdateCounter = 0  // Reset counter
            // Schedule music to play after alert finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playCurrentMusic()
            }
        }

        timerCore.onSessionComplete = { [weak self] in
            guard let self = self else { return }
            self.cleanupSession()
            self.scheduleNotification(title: "Session Complete!", body: "Your 30-minute interval session has finished.")
        }

        timerCore.onTimerTick = { [weak self] in
            guard let self = self else { return }
            // Check if player is paused but we're still running, resume it
            if let player = self.musicPlayer, self.isRunning {
                if player.timeControlStatus == .paused {
                    print("⚠️ Player was paused, resuming...")
                    player.play()
                }
            }
            // Update Live Activity every 5 seconds (to avoid rate limiting)
            self.liveActivityUpdateCounter += 1
            if self.liveActivityUpdateCounter >= 5 {
                self.updateLiveActivity()
                self.liveActivityUpdateCounter = 0
            }
        }
    }

    // MARK: - Live Activity Management
    private func startLiveActivity() {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities not enabled")
            return
        }

        let attributes = TimerWidgetAttributes(sessionStartTime: Date())
        let contentState = TimerWidgetAttributes.ContentState(
            currentInterval: currentInterval,
            totalIntervals: 10,
            timeRemaining: timeRemaining,
            secondsRemaining: secondsRemaining,
            isRunning: isRunning
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: ActivityContent<TimerWidgetAttributes.ContentState>(
                    state: contentState,
                    staleDate: nil
                )
            )
            print("✅ Live Activity started: \(currentActivity?.id ?? "unknown")")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    private func updateLiveActivity() {
        guard let activity = currentActivity else { return }

        let contentState = TimerWidgetAttributes.ContentState(
            currentInterval: currentInterval,
            totalIntervals: 10,
            timeRemaining: timeRemaining,
            secondsRemaining: secondsRemaining,
            isRunning: isRunning
        )

        Task {
            await activity.update(
                ActivityContent<TimerWidgetAttributes.ContentState>(
                    state: contentState,
                    staleDate: nil
                )
            )
        }
    }

    private func endLiveActivity() {
        guard let activity = currentActivity else { return }

        let finalState = TimerWidgetAttributes.ContentState(
            currentInterval: currentInterval,
            totalIntervals: 10,
            timeRemaining: "0:00",
            secondsRemaining: 0,
            isRunning: false
        )

        Task {
            await activity.end(
                ActivityContent<TimerWidgetAttributes.ContentState>(
                    state: finalState,
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
            print("✅ Live Activity ended")
        }

        currentActivity = nil
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
        timerCore.handleAppReturningToForeground()
        // Play music if we transitioned to a new interval
        if isRunning {
            playCurrentMusic()
        }
    }

    func startSession(session: AlarmSession) {
        timerCore.startSession(session: session)
        setupAudioSession()
        // Background audio keeps app alive - no need for background task
        liveActivityUpdateCounter = 0  // Reset update counter
        startTimer()
        playCurrentMusic()
        startLiveActivity()
    }

    func pause() {
        timerCore.pause()
        stopTimer()
        musicPlayer?.pause()
        musicPlayer = nil
        alertPlayer?.stop()
        alertPlayer = nil
        updateLiveActivity() // Update to show paused state
    }

    func stop() {
        timerCore.stop()
        stopTimer()
        cleanupAudio()
        endLiveActivity()
    }

    private func cleanupSession() {
        stopTimer()
        cleanupAudio()
        endLiveActivity()
    }

    private func cleanupAudio() {
        musicPlayer?.pause()
        musicPlayer = nil
        alertPlayer?.stop()
        alertPlayer = nil
    }

    private func stopTimer() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
    }
    
    private func startTimer() {
        let queue = DispatchQueue.global(qos: .userInitiated)
        dispatchTimer = DispatchSource.makeTimerSource(queue: queue)
        dispatchTimer?.schedule(wallDeadline: .now(), repeating: 1.0)
        dispatchTimer?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.timerCore.updateTimer()
            }
        }
        dispatchTimer?.resume()
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

    private func playMusic(_ music: BackgrounMusic) {
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


