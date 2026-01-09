//
//  WatchTimerManager.swift
//  TimerWatch Watch App
//
//  Watch-specific timer manager
//

import Foundation
import SwiftUI
import AVFoundation
import WatchKit
import ThreeMinutesTimerKit

// MARK: - Watch Timer Manager
@Observable
class WatchTimerManager: NSObject {
    // Timer core (shared business logic)
    private var timerCore = TimerCore()

    // Public properties delegated to TimerCore
    var isRunning: Bool { timerCore.isRunning }
    var currentInterval: Int { timerCore.currentInterval }
    var progress: Double { timerCore.progress }
    var timeRemaining: String { timerCore.timeRemaining }
    var statusText: String { timerCore.statusText }
    var secondsRemaining: Int { timerCore.secondsRemaining }
    var intervalProgress: Double { timerCore.intervalProgress }

    // Platform-specific (watchOS)
    private var timer: Timer?
    private let audioPlaybackManager = AudioPlaybackManager()
    private var extendedRuntimeSession: WKExtendedRuntimeSession?

    // Watch Connectivity
    private let watchConnectivity = WatchConnectivityManager.shared

    override init() {
        super.init()
        setupTimerCoreCallbacks()
        setupWatchConnectivityCallbacks()
    }

    private func setupTimerCoreCallbacks() {
        timerCore.onIntervalComplete = { [weak self] completedInterval in
            guard let self = self else { return }
            self.playAlertSound()
            self.playHapticFeedback()
        }

        timerCore.onSessionComplete = { [weak self] in
            guard let self = self else { return }
            self.cleanupSession()
            self.playHapticFeedback(type: .success)
        }

        timerCore.onTimerTick = { [weak self] in
            guard let self = self else { return }
            // Send timer state to iPhone periodically (not every second to avoid spam)
            // We'll send every 5 seconds, similar to iOS
            if self.secondsRemaining % 5 == 0 {
                self.sendTimerStateToiPhone()
            }
        }
    }

    private func setupWatchConnectivityCallbacks() {
        // Handle timer state updates from iPhone
        watchConnectivity.onTimerStateUpdate = { [weak self] message in
            guard let self = self else { return }
            print("📥 Watch received timer state from iPhone: interval \(message.currentInterval), time \(message.timeRemaining)s")
            // iPhone is updating us about its timer state
            // Could sync our UI here if needed
        }

        // Handle session started from iPhone
        watchConnectivity.onSessionStarted = { [weak self] message in
            guard let self = self else { return }
            print("📥 Watch received session started from iPhone: \(message.sessionID)")
            // iPhone started a session - could mirror it on watch
        }

        // Handle session completed from iPhone
        watchConnectivity.onSessionCompleted = { [weak self] message in
            guard let self = self else { return }
            print("📥 Watch received session completed from iPhone: \(message.sessionID)")
            // iPhone completed a session
        }

        // Handle preferences update from iPhone
        watchConnectivity.onPreferencesUpdate = { [weak self] message in
            guard let self = self else { return }
            print("📥 Watch received preferences update from iPhone")
            // Update our settings from iPhone
            self.timerCore.soundA = message.soundA
            self.timerCore.soundB = message.soundB
            self.timerCore.musicA = message.musicA
            self.timerCore.musicB = message.musicB
        }
    }

    private func sendTimerStateToiPhone() {
        let message = TimerStateMessage(
            currentInterval: currentInterval,
            timeRemaining: secondsRemaining,
            isRunning: isRunning,
            sessionID: timerCore.currentSession?.id
        )
        watchConnectivity.sendTimerState(message)
    }

    // MARK: - Session Management
    func startSession(session: AlarmSession) {
        timerCore.startSession(session: session)
        startExtendedRuntimeSession()
        startTimer()

        // Notify iPhone that session started
        let message = SessionStartedMessage(
            sessionID: session.id,
            startTime: session.startTime
        )
        watchConnectivity.sendSessionStarted(message)
    }

    func pause() {
        timerCore.pause()
        stopTimer()
        audioPlaybackManager.stopAlertSound()
    }

    func stop() {
        timerCore.stop()
        stopTimer()
        cleanupAudio()
        endExtendedRuntimeSession()
    }

    private func cleanupSession() {
        stopTimer()
        cleanupAudio()
        endExtendedRuntimeSession()

        // Notify iPhone that session completed
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
        audioPlaybackManager.stopAlertSound()
    }

    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerCore.updateTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Audio
    private func playAlertSound() {
        let sound = timerCore.getCurrentAlertSound()
        audioPlaybackManager.playAlertSound(sound)
    }

    // MARK: - Haptic Feedback
    private func playHapticFeedback(type: WKHapticType = .notification) {
        WKInterfaceDevice.current().play(type)
        print("✅ Played haptic feedback: \(type)")
    }

    // MARK: - Extended Runtime Session (for background execution)
    private func startExtendedRuntimeSession() {
        extendedRuntimeSession = WKExtendedRuntimeSession()
        extendedRuntimeSession?.delegate = self
        extendedRuntimeSession?.start()
        print("✅ Extended runtime session started")
    }

    private func endExtendedRuntimeSession() {
        extendedRuntimeSession?.invalidate()
        extendedRuntimeSession = nil
        print("✅ Extended runtime session ended")
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension WatchTimerManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("✅ Extended runtime session did start")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("⚠️ Extended runtime session will expire - stopping session")
        // Session is about to expire, clean up
        stop()
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("⚠️ Extended runtime session invalidated: \(reason)")
        if let error = error {
            print("❌ Error: \(error)")
        }
    }
}
