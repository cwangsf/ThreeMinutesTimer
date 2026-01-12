//
//  TimerState.swift
//  ThreeMinutesTimerKit
//
//  Shared timer state enum
//

import Foundation

// MARK: - Timer State
public enum TimerState {
    case idle       // No session running
    case running    // Session active and running
    case paused     // Session active but paused
}
