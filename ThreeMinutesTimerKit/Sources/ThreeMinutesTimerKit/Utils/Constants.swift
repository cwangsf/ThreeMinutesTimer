//
//  Constants.swift
//  ThreeMinutesTimerKit
//
//  Shared constants for timer configuration
//

import Foundation

// MARK: - Timer Constants
public enum TimerConstants {
    public static let intervalDuration: Int = 180 // 3 minutes in seconds
    public static let totalIntervals: Int = 10
    public static let totalDuration: Int = intervalDuration * totalIntervals // 30 minutes
}
