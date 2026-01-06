//
//  CloudKitManager.swift
//  ThreeMinutesTimerKit
//
//  CloudKit sync manager for sessions and preferences
//

import Foundation
import CloudKit

// MARK: - CloudKit Manager
@Observable
public class CloudKitManager {
    public static let shared = CloudKitManager()

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    // Record type names
    private let sessionRecordType = "SessionRecord"
    private let preferencesRecordType = "PreferencesRecord"
    private let preferencesRecordID = "userPreferences"

    // Callbacks
    public var onSessionsUpdated: (([TimerSessionRecord]) -> Void)?
    public var onPreferencesUpdated: ((PreferencesRecord) -> Void)?

    private init() {
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Session Sync
    public func saveSession(_ record: TimerSessionRecord) async throws {
        let ckRecord = CKRecord(recordType: sessionRecordType, recordID: CKRecord.ID(recordName: record.id.uuidString))

        ckRecord["startTime"] = record.startTime
        ckRecord["endTime"] = record.endTime
        ckRecord["totalIntervals"] = record.totalIntervals
        ckRecord["completedIntervals"] = record.completedIntervals
        ckRecord["isCompleted"] = record.isCompleted ? 1 : 0
        ckRecord["deviceSource"] = record.deviceSource.rawValue
        ckRecord["lastModified"] = record.lastModified

        try await privateDatabase.save(ckRecord)
        print("✅ Session saved to CloudKit: \(record.id)")
    }

    public func fetchSessions() async throws -> [TimerSessionRecord] {
        let query = CKQuery(recordType: sessionRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]

        let results = try await privateDatabase.records(matching: query)
        var sessions: [TimerSessionRecord] = []

        for (_, result) in results.matchResults {
            if let record = try? result.get() {
                if let session = timerSessionRecord(from: record) {
                    sessions.append(session)
                }
            }
        }

        print("📥 Fetched \(sessions.count) sessions from CloudKit")
        return sessions
    }

    public func deleteSession(_ sessionID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: sessionID.uuidString)
        try await privateDatabase.deleteRecord(withID: recordID)
        print("🗑️ Session deleted from CloudKit: \(sessionID)")
    }

    // MARK: - Preferences Sync
    public func savePreferences(_ preferences: PreferencesRecord) async throws {
        let recordID = CKRecord.ID(recordName: preferencesRecordID)
        let ckRecord = CKRecord(recordType: preferencesRecordType, recordID: recordID)

        ckRecord["soundA"] = preferences.soundA.rawValue
        ckRecord["soundB"] = preferences.soundB.rawValue
        ckRecord["musicA"] = preferences.musicA.rawValue
        ckRecord["musicB"] = preferences.musicB.rawValue
        ckRecord["themeColor"] = preferences.themeColor.rawValue
        ckRecord["lastModified"] = preferences.lastModified
        ckRecord["deviceSource"] = preferences.deviceSource.rawValue

        try await privateDatabase.save(ckRecord)
        print("✅ Preferences saved to CloudKit")
    }

    public func fetchPreferences() async throws -> PreferencesRecord? {
        let recordID = CKRecord.ID(recordName: preferencesRecordID)

        do {
            let record = try await privateDatabase.record(for: recordID)
            return preferencesRecord(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            // No preferences saved yet
            print("ℹ️ No preferences found in CloudKit")
            return nil
        } catch {
            throw error
        }
    }

    // MARK: - Subscription for Push Notifications
    public func subscribeToSessionChanges() async throws {
        let subscription = CKQuerySubscription(
            recordType: sessionRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "session-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await privateDatabase.save(subscription)
            print("✅ Subscribed to session changes")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists
            print("ℹ️ Session subscription already exists")
        }
    }

    public func subscribeToPreferencesChanges() async throws {
        let subscription = CKQuerySubscription(
            recordType: preferencesRecordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "preferences-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await privateDatabase.save(subscription)
            print("✅ Subscribed to preferences changes")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription already exists
            print("ℹ️ Preferences subscription already exists")
        }
    }

    // MARK: - Helper Methods
    private func timerSessionRecord(from ckRecord: CKRecord) -> TimerSessionRecord? {
        guard let recordName = UUID(uuidString: ckRecord.recordID.recordName),
              let startTime = ckRecord["startTime"] as? Date,
              let totalIntervals = ckRecord["totalIntervals"] as? Int,
              let completedIntervals = ckRecord["completedIntervals"] as? Int,
              let isCompletedInt = ckRecord["isCompleted"] as? Int,
              let deviceSourceString = ckRecord["deviceSource"] as? String,
              let deviceSource = DeviceSource(rawValue: deviceSourceString),
              let lastModified = ckRecord["lastModified"] as? Date else {
            return nil
        }

        let endTime = ckRecord["endTime"] as? Date
        let isCompleted = isCompletedInt == 1

        return TimerSessionRecord(
            id: recordName,
            startTime: startTime,
            endTime: endTime,
            totalIntervals: totalIntervals,
            completedIntervals: completedIntervals,
            isCompleted: isCompleted,
            deviceSource: deviceSource,
            lastModified: lastModified
        )
    }

    private func preferencesRecord(from ckRecord: CKRecord) -> PreferencesRecord? {
        guard let soundAString = ckRecord["soundA"] as? String,
              let soundBString = ckRecord["soundB"] as? String,
              let musicAString = ckRecord["musicA"] as? String,
              let musicBString = ckRecord["musicB"] as? String,
              let themeColorString = ckRecord["themeColor"] as? String,
              let lastModified = ckRecord["lastModified"] as? Date,
              let deviceSourceString = ckRecord["deviceSource"] as? String,
              let soundA = AlarmSound(rawValue: soundAString),
              let soundB = AlarmSound(rawValue: soundBString),
              let musicA = BackgrounMusic(rawValue: musicAString),
              let musicB = BackgrounMusic(rawValue: musicBString),
              let themeColor = ThemeColor(rawValue: themeColorString),
              let deviceSource = DeviceSource(rawValue: deviceSourceString) else {
            return nil
        }

        return PreferencesRecord(
            soundA: soundA,
            soundB: soundB,
            musicA: musicA,
            musicB: musicB,
            themeColor: themeColor,
            lastModified: lastModified,
            deviceSource: deviceSource
        )
    }
}
