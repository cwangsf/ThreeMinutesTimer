//
//  ThemeColor.swift
//  ThreeMinutesTimerKit
//
//  Shared enum for theme colors
//

import SwiftUI

// MARK: - Theme Color
public enum ThemeColor: String, CaseIterable, Codable {
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case orange = "Orange"
    case green = "Green"
    case red = "Red"

    public var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .red: return .red
        }
    }

    public var gradientColors: [Color] {
        switch self {
        case .blue: return [.blue, .cyan]
        case .purple: return [.purple, .pink]
        case .pink: return [.pink, .orange]
        case .orange: return [.orange, .yellow]
        case .green: return [.green, .mint]
        case .red: return [.red, .orange]
        }
    }
}
