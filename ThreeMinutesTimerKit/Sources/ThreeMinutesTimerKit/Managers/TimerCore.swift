//
//  TimerCore.swift
//  ThreeMinutesTimerKit
//
//  Platform-agnostic timer business logic
//

import Foundation

// MARK: - Timer Core
@Observable
public class TimerCore {
    // MARK: - Public State
    public var isRunning = false
    public var currentInterval = 0
    public var progress: Double = 0
    public var timeRemaining = "3:00"
    public var secondsRemaining = TimerConstants.intervalDuration

    // MARK: - Audio Preferences
    public var soundA: AlarmSound = .bell
    public var soundB: AlarmSound = .chime
    public var musicA: BackgrounMusic = .musicA
    public var musicB: BackgrounMusic = .musicB

    // MARK: - Session Tracking
    public private(set) var currentSession: AlarmSession?
    public private(set) var intervalStartTime: Date?
    public private(set) var sessionStartTime: Date?

    // MARK: - Callbacks for platform-specific actions
    public var onIntervalComplete: ((Int) -> Void)?
    public var onSessionComplete: (() -> Void)?
    public var onTimerTick: (() -> Void)?

    // MARK: - Computed Properties
    public var statusText: String {
        if !isRunning && currentInterval == 0 {
            return "Ready to start"
        } else if !isRunning && currentInterval > 0 {
            return "Paused"
        } else if currentInterval >= TimerConstants.totalIntervals {
            return "Session completed!"
        } else {
            return "Interval \(currentInterval + 1) active"
        }
    }

    public init() {}

    // MARK: - Session Management
    public func startSession(session: AlarmSession) {
        currentSession = session
        currentInterval = 0
        secondsRemaining = TimerConstants.intervalDuration
        isRunning = true
        sessionStartTime = Date()
        intervalStartTime = Date()
        updateProgress()
        updateTimeRemaining()
    }

    public func pause() {
        isRunning = false
    }

    public func resume() {
        isRunning = true
        intervalStartTime = Date()
    }

    public func stop() {
        isRunning = false
        currentInterval = 0
        progress = 0
        secondsRemaining = TimerConstants.intervalDuration
        updateTimeRemaining()

        if let session = currentSession {
            session.endTime = Date()
            session.completedIntervals = currentInterval
        }
        currentSession = nil
        intervalStartTime = nil
        sessionStartTime = nil
    }

    // MARK: - Timer Updates
    public func updateTimer() {
        guard isRunning else { return }

        secondsRemaining -= 1
        updateProgress()
        updateTimeRemaining()

        onTimerTick?()

        if secondsRemaining <= 0 {
            completeInterval()
        }
    }

    private func completeInterval() {
        let completedInterval = currentInterval
        currentInterval += 1

        // Notify platform-specific code
        onIntervalComplete?(completedInterval)

        if currentInterval >= TimerConstants.totalIntervals {
            completeSession()
        } else {
            // Start next interval
            secondsRemaining = TimerConstants.intervalDuration
            intervalStartTime = Date()
            updateProgress()
            updateTimeRemaining()
        }
    }

    private func completeSession() {
        isRunning = false

        if let session = currentSession {
            session.endTime = Date()
            session.completedIntervals = TimerConstants.totalIntervals
            session.isCompleted = true
        }

        intervalStartTime = nil
        sessionStartTime = nil

        // Notify platform-specific code
        onSessionComplete?()
    }

    // MARK: - Progress Calculation
    private func updateProgress() {
        let totalSeconds = Double(TimerConstants.totalIntervals * TimerConstants.intervalDuration)
        let elapsedSeconds = Double(currentInterval * TimerConstants.intervalDuration) +
                           Double(TimerConstants.intervalDuration - secondsRemaining)
        progress = elapsedSeconds / totalSeconds
    }

    private func updateTimeRemaining() {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        timeRemaining = String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Background Recovery
    public func handleAppReturningToForeground() {
        guard isRunning, let startTime = intervalStartTime else { return }

        // Recalculate time based on actual elapsed time
        let elapsed = Date().timeIntervalSince(startTime)
        let totalElapsedSeconds = Int(elapsed)

        // Check if we missed any intervals
        let missedIntervals = totalElapsedSeconds / TimerConstants.intervalDuration

        if missedIntervals > 0 {
            // We missed one or more intervals while in background
            currentInterval += missedIntervals

            if currentInterval >= TimerConstants.totalIntervals {
                completeSession()
                return
            }

            // Notify that we entered a new interval
            onIntervalComplete?(currentInterval - 1)
        }

        // Calculate seconds into current interval
        let secondsIntoInterval = totalElapsedSeconds % TimerConstants.intervalDuration
        secondsRemaining = TimerConstants.intervalDuration - secondsIntoInterval

        if secondsRemaining <= 0 {
            completeInterval()
        } else {
            updateProgress()
            updateTimeRemaining()
        }
    }

    // MARK: - Interval Progress (for circular progress display)
    public var intervalProgress: Double {
        let secondsElapsedInInterval = TimerConstants.intervalDuration - secondsRemaining
        return Double(secondsElapsedInInterval) / Double(TimerConstants.intervalDuration)
    }

    // MARK: - Audio Selection
    /// Returns the appropriate alert sound for the current interval
    public func getCurrentAlertSound() -> AlarmSound {
        return (currentInterval % 2 == 0) ? soundA : soundB
    }

    /// Returns the appropriate music track for the current interval
    public func getCurrentMusic() -> BackgrounMusic {
        return (currentInterval % 2 == 0) ? musicA : musicB
    }

    /// Returns the name of the current sound (for display purposes)
    public var currentSoundName: String {
        return getCurrentAlertSound().rawValue
    }
}
