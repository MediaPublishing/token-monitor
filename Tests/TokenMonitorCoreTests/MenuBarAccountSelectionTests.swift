import Combine
import Foundation
import Testing
@testable import TokenMonitorCore

struct MenuBarAccountSelectionTests {
    private let primary = MonitoredAccount.primary(for: .claude)
    private let second = MonitoredAccount(id: UUID(), service: .claude, name: "Second Brain", isPrimary: false)
    private let chatGPT = MonitoredAccount.primary(for: .chatGPT)

    @Test func legacyChoiceMigratesWithoutOverwritingNewSelection() {
        let available = [primary, second, chatGPT]
        let legacy = [ServiceKind.claude.rawValue: second.id.uuidString]
        let migrated = MenuBarAccountSelection(legacyAccountIDs: legacy)
        #expect(migrated.accounts(for: .claude, available: available).map(\.id) == [second.id])
        let explicit = MenuBarAccountSelection(accountIDs: [ServiceKind.claude.rawValue: [primary.id.uuidString]], legacyAccountIDs: legacy)
        #expect(explicit.accounts(for: .claude, available: available).map(\.id) == [primary.id])
    }

    @Test func defaultIsOnePrimaryAccountAndAdditionalAccountsAreIndependent() {
        let available = [second, primary, chatGPT]
        var selection = MenuBarAccountSelection()
        #expect(selection.accounts(for: .claude, available: available).map(\.id) == [primary.id])
        let added = selection.showAlongside(second.id, for: .claude, available: available)
        #expect(added)
        #expect(selection.accounts(for: .claude, available: available).map(\.id) == [primary.id, second.id])
        #expect(selection.accounts(for: .chatGPT, available: available).map(\.id) == [chatGPT.id])
        let duplicate = selection.showAlongside(second.id, for: .claude, available: available)
        let wrongProvider = selection.showAlongside(chatGPT.id, for: .claude, available: available)
        #expect(!duplicate)
        #expect(!wrongProvider)
    }

    @Test func switchingWithoutAlongsideReplacesTheFirstAccount() {
        var selection = MenuBarAccountSelection()
        let changed = selection.select(second.id, for: .claude, available: [primary, second])
        #expect(changed)
        #expect(selection.accounts(for: .claude, available: [primary, second]).map(\.id) == [second.id])
        let wrongProvider = selection.select(chatGPT.id, for: .claude, available: [primary, second, chatGPT])
        #expect(!wrongProvider)
    }

    @Test func movingAnExistingColumnKeepsBothAccountsWithoutDuplication() {
        var selection = MenuBarAccountSelection()
        let available = [primary, second]
        selection.showAlongside(second.id, for: .claude, available: available)
        selection.select(second.id, for: .claude, available: available)
        #expect(selection.accounts(for: .claude, available: available).map(\.id) == [second.id, primary.id])
    }

    @Test func hidingPromotesTheRemainingAccountAndCanHideTheProvider() {
        var selection = MenuBarAccountSelection()
        let available = [primary, second]
        selection.showAlongside(second.id, for: .claude, available: available)
        let hidden = selection.hide(primary.id, for: .claude, available: available)
        #expect(hidden)
        #expect(selection.accounts(for: .claude, available: available).map(\.id) == [second.id])
        let lastHidden = selection.hide(second.id, for: .claude, available: available)
        #expect(lastHidden)
        #expect(selection.accounts(for: .claude, available: available).isEmpty)
        selection.reconcile(available: available)
        let restored = MenuBarAccountSelection(accountIDs: selection.accountIDs)
        #expect(restored.accounts(for: .claude, available: available).isEmpty)
        let shown = selection.showAlongside(second.id, for: .claude, available: available)
        #expect(shown)
        #expect(selection.accounts(for: .claude, available: available).map(\.id) == [second.id])
    }

    @Test func explicitHiddenProviderDoesNotUseLegacyOrPrimaryFallback() {
        var selection = MenuBarAccountSelection(accountIDs: [ServiceKind.chatGPT.rawValue: []],
            legacyAccountIDs: [ServiceKind.chatGPT.rawValue: chatGPT.id.uuidString])
        let available = [primary, second, chatGPT]
        selection.showAlongside(second.id, for: .claude, available: available)
        selection.reconcile(available: available)
        #expect(selection.accounts(for: .chatGPT, available: available).isEmpty)
        #expect(selection.accounts(for: .claude, available: available).map(\.id) == [primary.id, second.id])
        let hiddenAgain = selection.hide(chatGPT.id, for: .chatGPT, available: available)
        let shownAgain = selection.select(chatGPT.id, for: .chatGPT, available: available)
        #expect(!hiddenAgain)
        #expect(shownAgain)
        #expect(selection.accounts(for: .chatGPT, available: available).map(\.id) == [chatGPT.id])
    }

    @Test func reconcileDoesNotHideProvidersThatHaveNotBeenAddedYet() {
        var selection = MenuBarAccountSelection()
        selection.reconcile(available: [primary])
        #expect(selection.accounts(for: .chatGPT, available: [primary, chatGPT]).map(\.id) == [chatGPT.id])
    }

    @Test func malformedDuplicateDeletedAndWrongProviderIDsAreIgnored() {
        let selection = MenuBarAccountSelection(accountIDs: [ServiceKind.claude.rawValue: [
            "invalid", UUID().uuidString, chatGPT.id.uuidString, second.id.uuidString, second.id.uuidString
        ]])
        #expect(selection.accounts(for: .claude, available: [primary, second, chatGPT]).map(\.id) == [second.id])
        #expect(selection.accounts(for: .claude, available: [primary, chatGPT]).map(\.id) == [primary.id])
    }

    @Test func removingAnAccountPreservesOtherSelectionsAndFallsBackSafely() {
        var selection = MenuBarAccountSelection(accountIDs: [
            ServiceKind.claude.rawValue: [second.id.uuidString, primary.id.uuidString],
            ServiceKind.chatGPT.rawValue: [chatGPT.id.uuidString]
        ])
        selection.reconcile(available: [primary, chatGPT])
        #expect(selection.accountIDs[ServiceKind.claude.rawValue] == [primary.id.uuidString])
        #expect(selection.accountIDs[ServiceKind.chatGPT.rawValue] == [chatGPT.id.uuidString])
    }

    @Test func accountSelectionPreservesOverflowWithoutTruncatingSavedChoices() {
        let extras = (0..<7).map { MonitoredAccount(id: UUID(), service: .claude, name: "Account \($0)", isPrimary: false) }
        let available = [primary] + extras
        var selection = MenuBarAccountSelection()
        for account in extras {
            let added = selection.showAlongside(account.id, for: .claude, available: available)
            #expect(added)
        }
        let overflow = selection.showAlongside(extras[0].id, for: .claude, available: available)
        #expect(!overflow)
        #expect(selection.accounts(for: .claude, available: available).map(\.id) == available.map(\.id))
        let oversized = MenuBarAccountSelection(accountIDs: [ServiceKind.claude.rawValue: available.map { $0.id.uuidString }])
        #expect(oversized.accounts(for: .claude, available: available).map(\.id) == available.map(\.id))
        selection.reconcile(available: available)
        #expect(selection.accountIDs[ServiceKind.claude.rawValue] == available.map { $0.id.uuidString })
    }

    @MainActor @Test func queuedPublishedObserverReadsNewAccountWithoutRefresh() async throws {
        let available = [primary, second]
        let probe = MenuSelectionProbe()
        var immediate: [UUID] = []
        var queued: [UUID] = []
        let immediateSubscription = probe.$selection.sink { _ in
            immediate += probe.selection.accounts(for: .claude, available: available).map(\.id)
        }
        let queuedSubscription = probe.$selection.receive(on: RunLoop.main).sink { _ in
            queued += probe.selection.accounts(for: .claude, available: available).map(\.id)
        }
        var next = probe.selection
        next.select(second.id, for: .claude, available: available)
        probe.selection = next
        for _ in 0..<100 where queued.last != second.id { try await Task.sleep(for: .milliseconds(10)) }
        #expect(immediate.last == primary.id)
        #expect(queued.last == second.id)
        withExtendedLifetime((immediateSubscription, queuedSubscription)) { }
    }
}

@MainActor private final class MenuSelectionProbe: ObservableObject {
    @Published var selection = MenuBarAccountSelection()
}
