//
//  AlarmSession.swift
//  ThreeMinutesTimerKit
//
//  SwiftData model for alarm sessions
//

import Foundation
import SwiftData

// MARK: - AlarmSession Model
@Model
public class AlarmSession {
    public var id = UUID()
    public var startTime = Date()
    public var endTime: Date?
    public var totalIntervals = 10
    public var completedIntervals = 0
    public var isCompleted = false

    public init() {}
}
