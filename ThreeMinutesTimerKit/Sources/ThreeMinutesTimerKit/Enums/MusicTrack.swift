//
//  BackgrounMusic.swift
//  ThreeMinutesTimerKit
//
//  Shared enum for background music tracks
//

import Foundation

// MARK: - Music Tracks
public enum BackgrounMusic: String, CaseIterable, Codable {
    case musicA = "Music A"
    case musicB = "Music B"

    public var filename: String {
        switch self {
        case .musicA: return "musicA"
        case .musicB: return "musicB"
        }
    }
}
