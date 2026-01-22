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
class AlarmManager: NSObject {
    // Timer core (shared business logic)
    private var timerCore = TimerCore()

    // Public properties delegated to TimerCore
    var isRunning: Bool { timerCore.isRunning }
    var currentInterval: Int { timerCore.currentInterval }
    var progress: Double { timerCore.progress }
    var timeRemaining: String { timerCore.timeRemaining }
    var statusText: String { timerCore.statusText }
    var secondsRemaining: Int { timerCore.secondsRemaining }

    // Audio preferences (delegated to TimerCore with setters for Watch sync)
    var soundA: AlarmSound {
        get { timerCore.soundA }
        set {
            timerCore.soundA = newValue
            sendPreferencesToWatch()
        }
    }
    var soundB: AlarmSound {
        get { timerCore.soundB }
        set {
            timerCore.soundB = newValue
            sendPreferencesToWatch()
        }
    }
    var musicA: BackgrounMusic {
        get { timerCore.musicA }
        set {
            timerCore.musicA = newValue
            sendPreferencesToWatch()
        }
    }
    var musicB: BackgrounMusic {
        get { timerCore.musicB }
        set {
            timerCore.musicB = newValue
            sendPreferencesToWatch()
        }
    }
    var themeColor: ThemeColor {
        didSet {
            UserDefaults.standard.set(themeColor.rawValue, forKey: "themeColor")
            sendPreferencesToWatch()
        }
    }

    // Platform-specific (iOS)
    private var timerTask: Task<Void, Never>?
    private var musicPlayer: AVPlayer?
    private let audioPlaybackManager = AudioPlaybackManager()
    private var audioSessionActivated = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // Live Activity
    private var currentActivity: Activity<TimerWidgetAttributes>?
    private var liveActivityUpdateCounter = 0

    // Watch Connectivity
    private let watchConnectivity = WatchConnectivityManager.shared

    var currentSoundName: String {
        return timerCore.currentSoundName
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

        // Set up Watch Connectivity callbacks
        setupWatchConnectivityCallbacks()

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
            Task {
                try? await Task.sleep(for: .seconds(0.5))
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
            // Send timer state to watch every 5 seconds as well
            if self.liveActivityUpdateCounter == 0 {
                self.sendTimerStateToWatch()
            }
        }
    }

    private func setupWatchConnectivityCallbacks() {
        // Handle timer state updates from watch
        watchConnectivity.onTimerStateUpdate = { [weak self] message in
            guard let self = self else { return }
            print("📥 iOS received timer state from watch: interval \(message.currentInterval), time \(message.timeRemaining)s")
            // Watch is updating us about its timer state
            // We could sync our UI here if needed, but for now just log it
        }

        // Handle session started from watch
        watchConnectivity.onSessionStarted = { [weak self] message in
            guard let self = self else { return }
            print("📥 iOS received session started from watch: \(message.sessionID)")
            // Watch started a session - we could start our own session here to stay in sync
        }

        // Handle session completed from watch
        watchConnectivity.onSessionCompleted = { [weak self] message in
            guard let self = self else { return }
            print("📥 iOS received session completed from watch: \(message.sessionID), \(message.completedIntervals) intervals")
            // Watch completed a session - we could update our history
        }

        // Handle preferences update from watch (if watch ever changes settings)
        watchConnectivity.onPreferencesUpdate = { [weak self] message in
            guard let self = self else { return }
            print("📥 iOS received preferences update from watch")
            // Update our settings if watch changed them
            self.timerCore.soundA = message.soundA
            self.timerCore.soundB = message.soundB
            self.timerCore.musicA = message.musicA
            self.timerCore.musicB = message.musicB
            self.themeColor = message.themeColor
        }
    }

    private func sendTimerStateToWatch() {
        let message = TimerStateMessage(
            currentInterval: currentInterval,
            timeRemaining: secondsRemaining,
            isRunning: isRunning,
            sessionID: timerCore.currentSession?.id
        )
        watchConnectivity.sendTimerState(message)
    }

    private func sendPreferencesToWatch() {
        let message = PreferencesMessage(
            soundA: soundA,
            soundB: soundB,
            musicA: musicA,
            musicB: musicB,
            themeColor: themeColor
        )
        watchConnectivity.sendPreferencesUpdate(message)
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
            totalIntervals: TimerConstants.totalIntervals,
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
            totalIntervals: TimerConstants.totalIntervals,
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
            totalIntervals: TimerConstants.totalIntervals,
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

        // Notify watch that session started
        let message = SessionStartedMessage(
            sessionID: session.id,
            startTime: session.startTime
        )
        watchConnectivity.sendSessionStarted(message)
    }

    func pause() {
        timerCore.pause()
        // Don't stop the timer - let it keep running but TimerCore won't decrement
        musicPlayer?.pause()
        musicPlayer = nil
        audioPlaybackManager.stopAlertSound()
        updateLiveActivity() // Update to show paused state
    }

    func resume() {
        timerCore.resume()
        playCurrentMusic()
        updateLiveActivity()
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

        // Notify watch that session completed
        if let session = timerCore.currentSession {
            let message = SessionCompletedMessage(
                sessionID: session.id,
                completedIntervals: session.completedIntervals,
                endTime: session.endTime ?? Date()
            )
            watchConnectivity.sendSessionCompleted(message)
        }
    }

    private func cleanupAudio() {
        musicPlayer?.pause()
        musicPlayer = nil
        audioPlaybackManager.stopAlertSound()
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    self?.timerCore.updateTimer()
                }
            }
        }
    }
    
    private func playCurrentMusic() {
        let music = timerCore.getCurrentMusic()
        playMusic(music)
    }

    private func playAlertSound() {
        let sound = timerCore.getCurrentAlertSound()
        audioPlaybackManager.playAlertSound(sound, fallbackToSystemSound: true)
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
        Task {
            try? await Task.sleep(for: .seconds(0.1))
            if let player = self.musicPlayer {
                print("🎵 After 0.1s - timeControlStatus: \(player.timeControlStatus.rawValue), currentTime: \(player.currentTime().seconds)")
            }
        }

        // Check after 1 second
        Task {
            try? await Task.sleep(for: .seconds(1.0))
            if let player = self.musicPlayer {
                print("🎵 After 1.0s - timeControlStatus: \(player.timeControlStatus.rawValue), currentTime: \(player.currentTime().seconds)")
            }
        }

        print("✅ Playing music with AVPlayer: \(music.rawValue), isPlaying: \(musicPlayer?.timeControlStatus == .playing)")
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
}


