# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ThreeMinutesTimer** (actual app name: "Interval Alarm") is a SwiftUI iOS app that runs 30-minute sessions with 10 three-minute intervals. It plays alternating alarm sounds at each interval and tracks sessions using SwiftData.

## Build & Test Commands

```bash
# Build the app
xcodebuild -scheme ThreeMinutesTimer -configuration Debug build

# Run tests
xcodebuild -scheme ThreeMinutesTimer -destination 'platform=iOS Simulator,name=iPhone 15' test

# Clean build folder
xcodebuild -scheme ThreeMinutesTimer clean
```

## Architecture

### Core Components

- **AlarmManager.swift** (`ThreeMinutesTimer/Controller/AlarmManager.swift`): Central `@Observable` class managing timer state, audio playback, and session lifecycle. Handles 10 three-minute intervals with alternating sounds (soundA/soundB). Uses `Timer` for countdown and `AVAudioPlayer` for custom alarm sounds with system sound fallback.

- **AlarmSession** (defined in `AlarmManager.swift`): SwiftData `@Model` that persists session data (start/end times, completed intervals). The app uses SwiftData's model container for storage.

- **HomeView.swift**: Main UI with session controls, sound selection buttons (disabled while running), and status display. Creates new `AlarmSession` instances and passes them to `AlarmManager`.

- **ProgressCircleView.swift**: Circular progress indicator showing current interval (1-10) and countdown timer. Uses animated gradient stroke.

### State Management

- Uses Swift's `@Observable` macro (not `ObservableObject`) for `AlarmManager`
- SwiftData with `@Model` and `@Query` for persistence
- `@State` for view-local state

### Audio System

- Attempts to load custom MP3 files from bundle (bell.mp3, chime.mp3, beep.mp3, tone.mp3, alert.mp3)
- Falls back to system sound (ID 1005) if files are missing
- Requires `AVAudioSession` setup with `.playback` category

### Localization

Uses String Catalog (`Localizable.xcstrings`) for internationalization. Currently supports English and Chinese (zh-Hans). Reference localized strings using `String(localized: .intervalTitle)` pattern.

## Key Implementation Details

- Interval duration: Currently hardcoded to 10 seconds for testing (comments indicate production should be 180 seconds/3 minutes)
- Total intervals: 10 (hardcoded in `AlarmManager`)
- Notification permissions are requested on HomeView appearance
- Session completion triggers a notification
- Sound selection is disabled during active sessions
