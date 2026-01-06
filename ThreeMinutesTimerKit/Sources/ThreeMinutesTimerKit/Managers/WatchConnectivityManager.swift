//
//  WatchConnectivityManager.swift
//  ThreeMinutesTimerKit
//
//  Watch Connectivity manager for real-time sync between iOS and watchOS
//

import Foundation
import WatchConnectivity

// MARK: - Watch Connectivity Manager
@Observable
public class WatchConnectivityManager: NSObject {
    public static let shared = WatchConnectivityManager()

    public var isReachable: Bool = false
    public var isActivated: Bool = false

    // Callbacks
    public var onTimerStateUpdate: ((TimerStateMessage) -> Void)?
    public var onSessionCompleted: ((SessionCompletedMessage) -> Void)?
    public var onSessionStarted: ((SessionStartedMessage) -> Void)?
    public var onPreferencesUpdate: ((PreferencesMessage) -> Void)?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send Messages
    public func sendTimerState(_ message: TimerStateMessage) {
        guard WCSession.default.isReachable else {
            print("⚠️ Watch not reachable, queuing message")
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            let messageDict: [String: Any] = ["timerState": data]

            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("❌ Failed to send timer state: \(error.localizedDescription)")
            }
            print("📤 Sent timer state update")
        } catch {
            print("❌ Failed to encode timer state: \(error)")
        }
    }

    public func sendSessionCompleted(_ message: SessionCompletedMessage) {
        guard WCSession.default.isReachable else {
            print("⚠️ Watch not reachable for session completion")
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            let messageDict: [String: Any] = ["sessionCompleted": data]

            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("❌ Failed to send session completed: \(error.localizedDescription)")
            }
            print("📤 Sent session completed")
        } catch {
            print("❌ Failed to encode session completed: \(error)")
        }
    }

    public func sendSessionStarted(_ message: SessionStartedMessage) {
        guard WCSession.default.isReachable else {
            print("⚠️ Watch not reachable for session started")
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            let messageDict: [String: Any] = ["sessionStarted": data]

            WCSession.default.sendMessage(messageDict, replyHandler: nil) { error in
                print("❌ Failed to send session started: \(error.localizedDescription)")
            }
            print("📤 Sent session started")
        } catch {
            print("❌ Failed to encode session started: \(error)")
        }
    }

    public func sendPreferencesUpdate(_ message: PreferencesMessage) {
        do {
            let data = try JSONEncoder().encode(message)
            try WCSession.default.updateApplicationContext(["preferences": data])
            print("📤 Sent preferences update via application context")
        } catch {
            print("❌ Failed to send preferences: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isActivated = activationState == .activated
            if let error = error {
                print("❌ WCSession activation failed: \(error.localizedDescription)")
            } else {
                print("✅ WCSession activated: \(activationState.rawValue)")
            }
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📡 Watch reachability changed: \(session.isReachable)")
        }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let data = message["timerState"] as? Data {
                do {
                    let timerState = try JSONDecoder().decode(TimerStateMessage.self, from: data)
                    self.onTimerStateUpdate?(timerState)
                    print("📥 Received timer state update")
                } catch {
                    print("❌ Failed to decode timer state: \(error)")
                }
            }

            if let data = message["sessionCompleted"] as? Data {
                do {
                    let sessionCompleted = try JSONDecoder().decode(SessionCompletedMessage.self, from: data)
                    self.onSessionCompleted?(sessionCompleted)
                    print("📥 Received session completed")
                } catch {
                    print("❌ Failed to decode session completed: \(error)")
                }
            }

            if let data = message["sessionStarted"] as? Data {
                do {
                    let sessionStarted = try JSONDecoder().decode(SessionStartedMessage.self, from: data)
                    self.onSessionStarted?(sessionStarted)
                    print("📥 Received session started")
                } catch {
                    print("❌ Failed to decode session started: \(error)")
                }
            }
        }
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            if let data = applicationContext["preferences"] as? Data {
                do {
                    let preferences = try JSONDecoder().decode(PreferencesMessage.self, from: data)
                    self.onPreferencesUpdate?(preferences)
                    print("📥 Received preferences update")
                } catch {
                    print("❌ Failed to decode preferences: \(error)")
                }
            }
        }
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        print("ℹ️ WCSession became inactive")
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        print("ℹ️ WCSession deactivated, reactivating...")
        session.activate()
    }
    #endif
}

// MARK: - Message Types
public struct TimerStateMessage: Codable {
    public let currentInterval: Int
    public let timeRemaining: Int
    public let isRunning: Bool
    public let sessionID: UUID?

    public init(currentInterval: Int, timeRemaining: Int, isRunning: Bool, sessionID: UUID?) {
        self.currentInterval = currentInterval
        self.timeRemaining = timeRemaining
        self.isRunning = isRunning
        self.sessionID = sessionID
    }
}

public struct SessionCompletedMessage: Codable {
    public let sessionID: UUID
    public let completedIntervals: Int
    public let endTime: Date

    public init(sessionID: UUID, completedIntervals: Int, endTime: Date) {
        self.sessionID = sessionID
        self.completedIntervals = completedIntervals
        self.endTime = endTime
    }
}

public struct SessionStartedMessage: Codable {
    public let sessionID: UUID
    public let startTime: Date

    public init(sessionID: UUID, startTime: Date) {
        self.sessionID = sessionID
        self.startTime = startTime
    }
}

public struct PreferencesMessage: Codable {
    public let soundA: AlarmSound
    public let soundB: AlarmSound
    public let musicA: BackgrounMusic
    public let musicB: BackgrounMusic
    public let themeColor: ThemeColor

    public init(soundA: AlarmSound, soundB: AlarmSound, musicA: BackgrounMusic, musicB: BackgrounMusic, themeColor: ThemeColor) {
        self.soundA = soundA
        self.soundB = soundB
        self.musicA = musicA
        self.musicB = musicB
        self.themeColor = themeColor
    }
}
