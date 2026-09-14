import Foundation
import Testing
@testable import TokenMonitorCore

struct BankedResetTests {
    private let now = ISO8601DateFormatter().date(from: "2026-09-14T12:00:00Z")!

    private func extract(_ text: String?, body: String = "") -> ServicePageExtract {
        ServicePageExtract(service: .chatGPT, pageTitle: "Usage", url: ServiceKind.chatGPT.usageURL.absoluteString,
                           bodyText: body, segments: [], bankedResetText: text, pageTimeZone: "America/New_York")
    }

    @Test func parsesObservedFullResetAndPageTimeZone() throws {
        let result = try #require(BankedResetParser.parse(extract("Full reset\nExpires Sep 20 at 7:59 PM\nUse reset"), now: now))
        #expect(result.availableCount(at: now) == 1)
        #expect(result.groups[0].title == "Full reset")
        #expect(result.groups[0].expiresAt == ISO8601DateFormatter().date(from: "2026-09-20T23:59:00Z"))
    }

    @Test func countsDistinctCardsWithIdenticalExpiryWithoutCountingDomDuplicates() throws {
        let body = "Usage limit resets\nFull reset\nExpires Sep 20 at 7:59 PM\nUse reset\nFull reset\nExpires Sep 20 at 7:59 PM\nUse reset\nAuto reload\nUsage limit resets\nFull reset\nExpires Sep 20 at 7:59 PM\nUse reset"
        let result = try #require(BankedResetParser.parse(extract(nil, body: body), now: now))
        #expect(result.groups.count == 1)
        #expect(result.availableCount(at: now) == 2)
    }

    @Test func loadingAndMissingDataAreUnknownNotZero() {
        let loading = extract("Loading usage limit resets…")
        #expect(BankedResetParser.isLoading(loading))
        #expect(BankedResetParser.parse(loading, now: now) == nil)
        #expect(BankedResetParser.parse(extract(nil), now: now) == nil)
        #expect(BankedResetParser.parse(extract("Use a reset to restore your limits."), now: now) == nil)
    }

    @Test func knownEmptyInventoryIsZero() throws {
        let result = try #require(BankedResetParser.parse(extract("You have no usage limit resets available."), now: now))
        #expect(result.groups.isEmpty)
    }

    @Test func unreadableExpiryIsNotInventedOrScheduled() throws {
        let result = try #require(BankedResetParser.parse(extract("Full reset\nExpires someday\nUse reset"), now: now))
        #expect(result.availableCount(at: now) == 1)
        #expect(result.groups[0].expiresAt == nil)
        #expect(ResetReminderPlanner.reminders(for: result, now: now).isEmpty)
    }

    @Test func incompleteCardDoesNotBorrowAnotherCardsDate() {
        #expect(BankedResetParser.parse(extract("Full reset\nWeekly reset\nExpires Sep 20 at 7:59 PM\nUse reset"), now: now) == nil)
    }

    @Test func expiredResetsDisappearWithoutAnotherRefresh() throws {
        let result = try #require(BankedResetParser.parse(extract("Full reset\nExpires Sep 13 at 7:59 PM\nUse reset"), now: now))
        #expect(result.availableCount(at: now) == 0)
        #expect(ResetReminderPlanner.reminders(for: result, now: now).isEmpty)
    }

    @Test func yearBoundaryIsHandledWithoutRevivingExpiredSeptemberResets() {
        let december = ISO8601DateFormatter().date(from: "2026-12-30T12:00:00Z")!
        let zone = TimeZone(secondsFromGMT: 0)!
        #expect(BankedResetParser.expiryDate("Expires Jan 5 at 12:00 PM", now: december, timeZone: zone) == ISO8601DateFormatter().date(from: "2027-01-05T12:00:00Z"))
        #expect(BankedResetParser.expiryDate("Expires Sep 1 at 12:00 PM", now: now, timeZone: zone) == ISO8601DateFormatter().date(from: "2026-09-01T12:00:00Z"))
    }

    @Test func supportsGermanTwentyFourHourExpiry() throws {
        let value = BankedResetParser.expiryDate("Verfällt am 20. Sep. um 19:59", now: now, timeZone: TimeZone(secondsFromGMT: 0)!)
        #expect(try #require(value) == ISO8601DateFormatter().date(from: "2026-09-20T19:59:00Z"))
    }

    @Test func schedulesExactlySeventyTwoHoursBeforeExpiryAndCombinesMatchingDates() throws {
        let expiry = now.addingTimeInterval(10 * 86400)
        let inventory = BankedResetInventory(capturedAt: now, groups: [
            .init(title: "Full reset", expiresAt: expiry, expiryText: "", count: 2),
            .init(title: "Weekly reset", expiresAt: expiry, expiryText: "")
        ])
        let reminders = ResetReminderPlanner.reminders(for: inventory, now: now)
        #expect(reminders.count == 1)
        #expect(reminders[0].count == 3)
        #expect(reminders[0].fireAt == expiry.addingTimeInterval(-72 * 3600))
    }

    @Test func lateDiscoveryNotifiesImmediatelyAndNeverRepeatsAfterRestart() throws {
        let inventory = BankedResetInventory(capturedAt: now, groups: [.init(title: "Full reset", expiresAt: now.addingTimeInterval(3600), expiryText: "")])
        let reminder = try #require(ResetReminderPlanner.reminders(for: inventory, now: now).first)
        #expect(reminder.fireAt == now.addingTimeInterval(1))
        #expect(ResetReminderPlanner.shouldSchedule(reminder, previousFireDate: nil, delivered: false, now: now))
        #expect(!ResetReminderPlanner.shouldSchedule(reminder, previousFireDate: reminder.fireAt, delivered: false, now: now.addingTimeInterval(5)))
        #expect(!ResetReminderPlanner.shouldSchedule(reminder, previousFireDate: nil, delivered: true, now: now))
    }

    @Test func futureReminderCanBeUpdatedWhenCountChanges() throws {
        let inventory = BankedResetInventory(capturedAt: now, groups: [.init(title: "Full reset", expiresAt: now.addingTimeInterval(10 * 86400), expiryText: "")])
        let reminder = try #require(ResetReminderPlanner.reminders(for: inventory, now: now).first)
        #expect(ResetReminderPlanner.shouldSchedule(reminder, previousFireDate: reminder.fireAt, delivered: false, now: now))
    }

    @Test func reducerPreservesUnknownDataButClearsConsumedResetsAndDisconnectedAccounts() {
        let inventory = BankedResetInventory(capturedAt: now, groups: [.init(title: "Full reset", expiresAt: now.addingTimeInterval(86400), expiryText: "")])
        let old = ServiceSnapshot(service: .chatGPT, capturedAt: now, pageTitle: "Usage", url: "", metrics: [], bankedResets: inventory)
        var state = DashboardState.initial(lastSnapshots: [.chatGPT: old])
        var updated = ServiceSnapshot(service: .chatGPT, capturedAt: now.addingTimeInterval(60), pageTitle: "Usage", url: "", metrics: [])
        DashboardReducer.reduce(&state, event: .service(.chatGPT, .refreshSucceeded(updated)))
        #expect(state.service(.chatGPT).snapshot?.bankedResets == inventory)
        updated.bankedResets = .init(capturedAt: updated.capturedAt, groups: [])
        DashboardReducer.reduce(&state, event: .service(.chatGPT, .refreshSucceeded(updated)))
        #expect(state.service(.chatGPT).snapshot?.bankedResets?.groups.isEmpty == true)
        DashboardReducer.reduce(&state, event: .service(.chatGPT, .disconnected(message: "Connect")))
        #expect(state.service(.chatGPT).snapshot == nil)
    }

    @Test func oldSnapshotsAndExtractsStillDecodeWithoutResetFields() throws {
        let snapshot = ServiceSnapshot(service: .chatGPT, capturedAt: now, pageTitle: "Usage", url: "", metrics: [])
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(ServiceSnapshot.self, from: data).bankedResets == nil)
        let oldExtract = #"{"service":"chatgpt","pageTitle":"Usage","url":"","bodyText":"","segments":[]}"#
        #expect(try JSONDecoder().decode(ServicePageExtract.self, from: Data(oldExtract.utf8)).bankedResetText == nil)
    }

    @Test func chatGPTParserKeepsCapacitySeparateFromBankedResets() throws {
        let page = extract("Full reset\nExpires Sep 20 at 7:59 PM\nUse reset", body: "Weekly usage limit\n96% remaining\nResets Sep 20, 2026 21:14")
        let snapshot = try ChatGPTUsageParser().parse(extract: page, now: now)
        #expect(snapshot.metric(for: "weekly-limit")?.progress == 0.96)
        #expect(snapshot.bankedResets?.availableCount(at: now) == 1)
        #expect(snapshot.metrics.allSatisfy { !$0.key.contains("banked") })
    }
}
