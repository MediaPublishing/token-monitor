import Foundation
import Testing
@testable import TokenMonitorCore

struct LoginNavigationTests {
    private func page(_ url: String = "https://chatgpt.com/", body: String = "Log in\nSign up for free") -> ServicePageExtract {
        ServicePageExtract(service: .chatGPT, pageTitle: "ChatGPT", url: url, bodyText: body, segments: [])
    }

    @Test func loggedOutHomeNeverRedirectsWhileTheUserIsTryingToSignIn() {
        var navigation = ChatGPTLoginNavigation()
        for _ in 0..<20 {
            let action = navigation.action(for: page(), hasAuthenticatedSession: false)
            #expect(action == .wait)
        }
        let german = navigation.action(for: page(body: "Melde dich an\nAnmelden\nKostenlos registrieren"), hasAuthenticatedSession: false)
        #expect(german == .wait)
    }

    @Test func returningFromAuthDoesNotProveTheUserIsSignedIn() {
        var navigation = ChatGPTLoginNavigation()
        navigation.navigationStarted(at: URL(string: "https://auth.openai.com/log-in"))
        let auth = navigation.action(for: page("https://auth.openai.com/log-in", body: "Enter your email"), hasAuthenticatedSession: false)
        let returned = navigation.action(for: page(), hasAuthenticatedSession: false)
        #expect(auth == .wait)
        #expect(returned == .wait)
    }

    @Test func authenticatedHomeLoadsUsageOnlyOnceIncludingAnExistingSession() {
        var navigation = ChatGPTLoginNavigation()
        let home = page(body: "How can I help?")
        let first = navigation.action(for: home, hasAuthenticatedSession: true)
        let second = navigation.action(for: home, hasAuthenticatedSession: true)
        #expect(first == .loadUsage)
        #expect(second == .wait)
    }

    @Test func emptyOrPartiallyLoadedUsagePagesNeverTriggerReloads() {
        var navigation = ChatGPTLoginNavigation()
        let blank = navigation.action(for: page(body: ""), hasAuthenticatedSession: true)
        #expect(blank == .wait)
        for url in [ServiceKind.chatGPT.usageURL.absoluteString, "https://chatgpt.com/settings/usage",
                    "https://chatgpt.com/#settings/Usage"] {
            let action = navigation.action(for: page(url, body: "Loading usage..."), hasAuthenticatedSession: true)
            #expect(action == .wait)
        }
    }

    @Test func usageURLWithoutMetricsCannotCompleteConnection() {
        var navigation = ChatGPTLoginNavigation()
        let action = navigation.action(for: page(ServiceKind.chatGPT.usageURL.absoluteString), hasAuthenticatedSession: false)
        #expect(action == .wait)
    }

    @Test func parsedUsageCompletesEvenIfTheOptionalSessionProbeIsUnavailable() {
        var navigation = ChatGPTLoginNavigation()
        for url in [ServiceKind.chatGPT.usageURL.absoluteString, "https://chatgpt.com/#settings/Usage"] {
            let usage = page(url, body: "Weekly usage limit\n57% remaining\nResets Oct 29, 2026 8:50 AM")
            let action = navigation.action(for: usage, hasAuthenticatedSession: false)
            #expect(action == .complete)
        }
    }

    @Test func aNewExplicitAuthenticationAttemptAllowsOneNewUsageNavigation() {
        var navigation = ChatGPTLoginNavigation()
        let first = navigation.action(for: page(body: "Home"), hasAuthenticatedSession: true)
        #expect(first == .loadUsage)
        navigation.navigationStarted(at: URL(string: "https://auth.openai.com/log-in"))
        let signedOut = navigation.action(for: page(), hasAuthenticatedSession: false)
        let signedIn = navigation.action(for: page(body: "Home"), hasAuthenticatedSession: true)
        #expect(signedOut == .wait)
        #expect(signedIn == .loadUsage)
    }

    @Test func unrelatedHostsAndNonWebPagesNeverTriggerUsageNavigation() {
        var navigation = ChatGPTLoginNavigation()
        for url in ["about:blank", "https://accounts.google.com/", "https://chatgpt.com.example.org/",
                    "https://chatgpt.com@example.org/", "http://chatgpt.com/", "https://chatgpt.com:444/"] {
            let action = navigation.action(for: page(url, body: "Home"), hasAuthenticatedSession: true)
            #expect(action == .wait)
        }
    }
}
