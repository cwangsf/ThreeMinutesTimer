//
//  TimerActivityAttributes.swift
//  ThreeMinutesTimerKit
//
//  Shared Live Activity attributes
//

import Foundation
import ActivityKit

// MARK: - Timer Widget Attributes
public struct TimerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic properties that update during the session
        public var currentInterval: Int
        public var totalIntervals: Int
        public var timeRemaining: String
        public var secondsRemaining: Int
        public var isRunning: Bool

        public init(currentInterval: Int, totalIntervals: Int, timeRemaining: String, secondsRemaining: Int, isRunning: Bool) {
            self.currentInterval = currentInterval
            self.totalIntervals = totalIntervals
            self.timeRemaining = timeRemaining
            self.secondsRemaining = secondsRemaining
            self.isRunning = isRunning
        }
    }

    // Fixed properties for the entire session
    public var sessionStartTime: Date

    public init(sessionStartTime: Date) {
        self.sessionStartTime = sessionStartTime
    }
}
