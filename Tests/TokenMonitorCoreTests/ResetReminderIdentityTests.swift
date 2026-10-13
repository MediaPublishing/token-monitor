import Foundation
import Testing
@testable import TokenMonitorCore

struct ResetReminderIdentityTests {
    @Test func notificationSettingsLinkTargetsTheModernPane() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/TokenMonitorApp/ResetReminderController.swift"), encoding: .utf8)
        #expect(source.contains("x-apple.systempreferences:com.apple.Notifications-Settings.extension"))
        #expect(source.contains("x-apple.systempreferences:com.apple.preference.notifications"))
    }

    @Test func accountIdentityRoundTripsWithoutAcceptingLegacyOrForeignIDs() {
        let id = UUID(uuidString: "1F39E532-8B9D-4D13-B1E0-2144544E9177")!
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(ResetReminderPlanner.accountID(from: ResetReminderPlanner.identifier(for: expiry, accountID: id)) == id)
        #expect(ResetReminderPlanner.accountID(from: ResetReminderPlanner.identifier(for: expiry)) == nil)
        #expect(ResetReminderPlanner.accountID(from: "other-" + id.uuidString + "-1800000000") == nil)
        #expect(ResetReminderPlanner.accountID(from: ResetReminderPlanner.identifierPrefix + id.uuidString + "-broken") == nil)
    }

    @Test func migrationPreservesDeliveredAndDueAntiRepeatSemantics() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let inventory = BankedResetInventory(capturedAt: now, groups: [.init(title: "Full reset", expiresAt: now.addingTimeInterval(60_000), expiryText: "Expires soon")])
        let migrated = ResetReminderPlanner.reminders(for: inventory, now: now, accountID: UUID())[0]
        #expect(!ResetReminderPlanner.shouldSchedule(migrated, previousFireDate: now.addingTimeInterval(-100), delivered: false, now: now))
        #expect(!ResetReminderPlanner.shouldSchedule(migrated, previousFireDate: nil, delivered: true, now: now))
    }
}
