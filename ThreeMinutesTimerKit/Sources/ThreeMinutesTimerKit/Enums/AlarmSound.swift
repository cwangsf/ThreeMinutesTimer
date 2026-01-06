//
//  AlarmSound.swift
//  ThreeMinutesTimerKit
//
//  Shared enum for alarm sound types
//

import Foundation

// MARK: - Alarm Sounds
public enum AlarmSound: String, CaseIterable, Codable {
    case bell = "Bell"
    case chime = "Chime"
    case beep = "Beep"
    case tone = "Tone"
    case alert = "Alert"

    public var filename: String {
        switch self {
        case .bell: return "bell"
        case .chime: return "chime"
        case .beep: return "beep"
        case .tone: return "tone"
        case .alert: return "alert"
        }
    }
}
