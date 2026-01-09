//
//  AudioPlaybackManager.swift
//  ThreeMinutesTimerKit
//
//  Shared audio playback utilities
//

import Foundation
import AVFoundation

// MARK: - Audio Playback Manager
/// Handles AVAudioPlayer setup and playback for alert sounds
public class AudioPlaybackManager: NSObject, AVAudioPlayerDelegate {
    private var alertPlayer: AVAudioPlayer?

    /// Optional delegate to receive audio player callbacks
    public weak var delegate: AVAudioPlayerDelegate?

    /// Optional completion handler for when audio finishes
    public var onPlaybackFinished: ((Bool) -> Void)?

    public override init() {
        super.init()
    }

    // MARK: - Playback Control

    /// Plays an alert sound from the main bundle
    /// - Parameters:
    ///   - sound: The alarm sound to play
    ///   - fallbackToSystemSound: If true, plays system sound on failure (iOS only)
    /// - Returns: True if playback started successfully
    @discardableResult
    public func playAlertSound(_ sound: AlarmSound, fallbackToSystemSound: Bool = false) -> Bool {
        guard let url = Bundle.main.url(forResource: sound.filename, withExtension: "mp3") else {
            print("⚠️ Alert sound file not found: \(sound.filename)")
            #if os(iOS)
            if fallbackToSystemSound {
                playSystemSound()
            }
            #endif
            return false
        }

        do {
            alertPlayer = try AVAudioPlayer(contentsOf: url)
            alertPlayer?.delegate = self
            alertPlayer?.play()
            print("✅ Playing alert sound: \(sound.rawValue)")
            return true
        } catch {
            print("❌ Error playing alert sound: \(error)")
            #if os(iOS)
            if fallbackToSystemSound {
                playSystemSound()
            }
            #endif
            return false
        }
    }

    /// Stops the currently playing alert sound
    public func stopAlertSound() {
        alertPlayer?.stop()
        alertPlayer = nil
    }

    /// Checks if alert sound is currently playing
    public var isPlaying: Bool {
        return alertPlayer?.isPlaying ?? false
    }

    #if os(iOS)
    /// Plays iOS system sound as fallback
    private func playSystemSound() {
        AudioServicesPlaySystemSound(1005) // System sound ID for alarm
        print("🔔 Playing system sound fallback")
    }
    #endif

    // MARK: - AVAudioPlayerDelegate

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("✅ Audio finished playing successfully")
        } else {
            print("⚠️ Audio playback interrupted")
        }

        // Call delegate if set
        delegate?.audioPlayerDidFinishPlaying?(player, successfully: flag)

        // Call completion handler if set
        onPlaybackFinished?(flag)
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("❌ Audio decode error: \(error)")
        }

        // Call delegate if set
        delegate?.audioPlayerDecodeErrorDidOccur?(player, error: error)
    }
}
