//
//  TimerSessionRecord.swift
//  ThreeMinutesTimerKit
//
//  Codable model for CloudKit sync
//

import Foundation

// MARK: - Timer Session Record (Codable for CloudKit)
public struct TimerSessionRecord: Codable, Identifiable {
    public var id: UUID
    public var startTime: Date
    public var endTime: Date?
    public var totalIntervals: Int
    public var completedIntervals: Int
    public var isCompleted: Bool
    public var deviceSource: DeviceSource
    public var lastModified: Date

    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        totalIntervals: Int = 10,
        completedIntervals: Int = 0,
        isCompleted: Bool = false,
        deviceSource: DeviceSource,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.totalIntervals = totalIntervals
        self.completedIntervals = completedIntervals
        self.isCompleted = isCompleted
        self.deviceSource = deviceSource
        self.lastModified = lastModified
    }

    // Convert from AlarmSession (SwiftData model)
    public init(from session: AlarmSession, deviceSource: DeviceSource) {
        self.id = session.id
        self.startTime = session.startTime
        self.endTime = session.endTime
        self.totalIntervals = session.totalIntervals
        self.completedIntervals = session.completedIntervals
        self.isCompleted = session.isCompleted
        self.deviceSource = deviceSource
        self.lastModified = Date()
    }

    // Apply to AlarmSession
    public func apply(to session: AlarmSession) {
        session.id = self.id
        session.startTime = self.startTime
        session.endTime = self.endTime
        session.totalIntervals = self.totalIntervals
        session.completedIntervals = self.completedIntervals
        session.isCompleted = self.isCompleted
    }
}

// MARK: - Device Source
public enum DeviceSource: String, Codable {
    case iOS
    case watchOS
}

// MARK: - Preferences Record
public struct PreferencesRecord: Codable {
    public var soundA: AlarmSound
    public var soundB: AlarmSound
    public var musicA: BackgrounMusic
    public var musicB: BackgrounMusic
    public var themeColor: ThemeColor
    public var lastModified: Date
    public var deviceSource: DeviceSource

    public init(
        soundA: AlarmSound = .bell,
        soundB: AlarmSound = .chime,
        musicA: BackgrounMusic = .musicA,
        musicB: BackgrounMusic = .musicB,
        themeColor: ThemeColor = .purple,
        lastModified: Date = Date(),
        deviceSource: DeviceSource
    ) {
        self.soundA = soundA
        self.soundB = soundB
        self.musicA = musicA
        self.musicB = musicB
        self.themeColor = themeColor
        self.lastModified = lastModified
        self.deviceSource = deviceSource
    }
}
