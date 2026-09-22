import Foundation
import Testing
@testable import TokenMonitorCore

struct OpenCodeGoNavigationTests {
    @Test func restoresKnownWorkspaceInsteadOfPublicMarketingPage() {
        let workspace = "https://opencode.ai/workspace/example/go"
        #expect(OpenCodeGoNavigation.refreshURL(lastKnownURL: workspace).absoluteString == workspace)
        #expect(OpenCodeGoNavigation.refreshURL(lastKnownURL: nil).absoluteString == "https://opencode.ai/auth")
        #expect(OpenCodeGoNavigation.refreshURL(lastKnownURL: "https://opencode.ai/go") == ServiceKind.openCodeGo.usageURL)
        #expect(ServiceKind.openCodeGo.usageURL.absoluteString == "https://opencode.ai/auth")
    }

    @Test func workspaceRecoveryCannotFollowUntrustedOrNonUsageURLs() {
        for value in ["https://opencode.ai.evil.test/workspace/example/go", "http://opencode.ai/workspace/example/go",
                      "https://opencode.ai:8080/workspace/example/go", "https://name@opencode.ai/workspace/example/go",
                      "https://opencode.ai/workspace/example/go/logout", "https://opencode.ai/workspace/example/keys"] {
            #expect(OpenCodeGoNavigation.workspaceURL(from: value) == nil)
        }
        #expect(OpenCodeGoNavigation.workspaceURL(from: "https://opencode.ai/de/workspace/example/go?ignored=1#usage")?.absoluteString
                == "https://opencode.ai/de/workspace/example/go")
    }

    @Test func discoversWorkspaceAfterAccountEntryAndPrefersCurrentWorkspace() {
        let links = ["https://other.test/workspace/example/go", "https://opencode.ai/workspace/second/go"]
        let entry = ServicePageExtract(service: .openCodeGo, pageTitle: "Account", url: "https://opencode.ai/workspace/second",
                                      bodyText: "", segments: [], links: links)
        #expect(entry.openCodeGoWorkspaceURL?.absoluteString == links[1])
        let dashboard = ServicePageExtract(service: .openCodeGo, pageTitle: "Go", url: "https://opencode.ai/workspace/first/go",
                                          bodyText: "", segments: [], links: links)
        #expect(dashboard.openCodeGoWorkspaceURL?.absoluteString == dashboard.url)
    }

    @Test func supportsMigratedConsoleWorkspaceWithoutTreatingLoginAsUsage() {
        let url = "https://opencode.ai/console/wrk_example/go"
        #expect(OpenCodeGoNavigation.refreshURL(lastKnownURL: url).absoluteString == url)
        #expect(OpenCodeGoNavigation.workspaceURL(from: "https://opencode.ai/console/org_example/go") != nil)
        #expect(OpenCodeGoNavigation.workspaceURL(from: "https://opencode.ai/console/login") == nil)
        #expect(OpenCodeGoNavigation.workspaceURL(from: "https://opencode.ai/console/go") == nil)
        #expect(OpenCodeGoNavigation.isConsoleURL("https://opencode.ai/console/login"))
        #expect(!OpenCodeGoNavigation.isConsoleURL("https://opencode.ai.evil.test/console/login"))
    }
}
