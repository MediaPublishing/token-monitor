import AppKit
import SwiftUI
import TokenMonitorCore

private struct LayoutFixtureSnapshots: SnapshotPersisting {
    let snapshots: [ServiceKind: ServiceSnapshot]
    func loadSnapshots() throws -> [ServiceKind: ServiceSnapshot] { snapshots }
    func saveSnapshots(_ snapshots: [ServiceKind: ServiceSnapshot]) throws { }
}

private struct LayoutFixtureAccounts: AccountPersisting {
    let count: Int
    let snapshots: [ServiceKind: ServiceSnapshot]

    func loadAccounts() throws -> [MonitoredAccount] {
        var accounts = ServiceKind.allCases.map { service -> MonitoredAccount in
            var account = MonitoredAccount.primary(for: service)
            account.snapshot = snapshots[service]
            return account
        }
        for index in 3..<max(3, count) {
            accounts.append(MonitoredAccount(id: UUID(), service: .claude, name: "Claude \(index - 1)", isPrimary: false,
                                             snapshot: snapshots[.claude]))
        }
        return accounts
    }

    func saveAccounts(_ accounts: [MonitoredAccount]) throws { }
}

@MainActor enum NativeLayoutProof {
    static func run(analytics: ProjectAnalyticsModel, output: URL) async throws {
        precondition(Bundle.main.bundleIdentifier == "com.mediapublishing.tokenmonitor.analytics-qa")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for _ in 0..<100 where analytics.refreshing { try await Task.sleep(for: .milliseconds(30)) }
        precondition(analytics.groups.count == 4 && analytics.totalTokens == 4_250_000)
        precondition(!analytics.hasMeaningfulTopics)
        let logos = ServiceKind.allCases.compactMap { ProviderLogoView.image(for: $0) }
            + [ProviderLogoView.image(for: .openCodeGo, darkAppearance: true)].compactMap { $0 }
        precondition(logos.count == 4)
        precondition(logos.allSatisfy { $0.representations.contains { $0 is NSPDFImageRep } })
        let window = NSWindow(contentRect: NSRect(x: 120, y: 60, width: 488, height: 180),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Token Monitor Native Layout QA"
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        var records: [[String: Any]] = []
        let snapshots = fixtures()
        let scenarios: [(String, Int, PopoverScreen, Bool, Bool, CGFloat, Bool, MenuBarAccountArrangement)] = [
            ("capacity-two-light", 2, .dashboard, false, false, 900, false, .compact),
            ("capacity-three-light", 3, .dashboard, false, false, 900, false, .compact),
            ("capacity-details-light", 3, .dashboard, true, false, 900, false, .compact),
            ("analysis-closed-light", 2, .analytics, false, false, 900, false, .compact),
            ("analysis-open-light", 2, .analytics, false, false, 900, true, .compact),
            ("settings-light", 3, .settings, false, false, 760, false, .compact),
            ("settings-by-provider-light", 3, .settings, false, false, 760, false, .byProvider),
            ("settings-by-account-light", 3, .settings, false, false, 760, false, .byAccount),
            ("settings-dark-bounded", 6, .settings, false, true, 620, false, .compact),
            ("settings-by-provider-dark-bounded", 6, .settings, false, true, 620, false, .byProvider),
            ("settings-by-account-dark-bounded", 6, .settings, false, true, 620, false, .byAccount),
            ("capacity-dark-bounded", 6, .dashboard, false, true, 480, false, .compact)
        ]
        for (name, count, screen, details, dark, maximum, expand, arrangement) in scenarios {
            UserDefaults.standard.set(count >= 3, forKey: "openCodeGoEnabled")
            UserDefaults.standard.set(details, forKey: "showUsageDetails")
            UserDefaults.standard.set(false, forKey: "bankedResetRemindersEnabled")
            for id in analytics.expandedGroupIDs { analytics.setExpanded(id, false) }
            if expand, let first = analytics.groups.first { analytics.setExpanded(first.id, true) }
            let model = AppModel(snapshotStore: LayoutFixtureSnapshots(snapshots: snapshots),
                                 accountStore: LayoutFixtureAccounts(count: count, snapshots: snapshots), analytics: analytics)
            model.setStatusMenuAccountArrangement(arrangement)
            model.popoverMaximumHeight = maximum
            switch screen {
            case .dashboard: model.showDashboardInPopover()
            case .analytics: model.showAnalyticsInPopover()
            case .settings: model.showSettingsInPopover()
            }
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let hosting = NSHostingController(rootView: PopoverRootView(onSizeChange: { _, size in
                window.setContentSize(size)
            }).environmentObject(model))
            window.contentViewController = hosting
            window.setContentSize(NSSize(width: 488, height: 180))
            for _ in 0..<12 { try await Task.sleep(for: .milliseconds(50)) }
            hosting.view.layoutSubtreeIfNeeded()
            let height = hosting.view.bounds.height
            precondition(height <= maximum + 1 && height > 80)
            let scrolls = scrollViews(in: hosting.view)
            precondition(scrolls.count == 1)
            let overflowing = scrolls.contains {
                ($0.documentView?.bounds.height ?? 0) > $0.contentView.bounds.height + 1
            }
            guard let bitmap = hosting.view.bitmapImageRepForCachingDisplay(in: hosting.view.bounds) else {
                throw NSError(domain: "NativeLayoutProof", code: 1)
            }
            hosting.view.cacheDisplay(in: hosting.view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "NativeLayoutProof", code: 2)
            }
            try png.write(to: output.appendingPathComponent(name + ".png"))
            if name == "settings-light" || name == "settings-by-provider-light" {
                precondition(!overflowing, "\(name): Settings unexpectedly scrolls at height \(height)")
            }
            if name == "settings-light" || name == "settings-dark-bounded" {
                try writeLogoScaleProofs(in: hosting.view, name: name, output: output)
            }
            var colors: Set<String> = []
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 7) {
                for y in stride(from: 0, to: bitmap.pixelsHigh, by: 7) {
                    if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) {
                        colors.insert("\(Int(color.redComponent * 255)),\(Int(color.greenComponent * 255)),\(Int(color.blueComponent * 255))")
                    }
                }
            }
            precondition(colors.count > 12)
            records.append(["name": name, "height": Double(height), "maximum": Double(maximum), "scrollAreas": scrolls.count,
                            "overflowing": overflowing, "colors": colors.count])
        }
        let height: (String) -> Double = { name in records.first { $0["name"] as? String == name }!["height"] as! Double }
        precondition(height("capacity-two-light") < height("capacity-three-light"))
        precondition(height("capacity-three-light") < height("capacity-details-light"))
        precondition(height("analysis-closed-light") < height("analysis-open-light"))
        if CommandLine.arguments.contains("--marketing") {
            try await writeMarketingScreenshots(analytics: analytics, snapshots: snapshots, window: window, output: output)
        }
        let data = try JSONSerialization.data(withJSONObject: ["scope": "Native SwiftUI views, synthetic accounts only", "logos": "all decoded as vector PDF", "scenarios": records], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("native-layout-proof.json"))
        print("NATIVE_LAYOUT_PROOF_PASS \(String(decoding: data, as: UTF8.self))")
        fflush(stdout)
        window.close()
    }

    private static func writeMarketingScreenshots(analytics: ProjectAnalyticsModel, snapshots: [ServiceKind: ServiceSnapshot], window: NSWindow, output: URL) async throws {
        UserDefaults.standard.set(true, forKey: "openCodeGoEnabled")
        UserDefaults.standard.set(false, forKey: "showUsageDetails")
        let model = AppModel(snapshotStore: LayoutFixtureSnapshots(snapshots: snapshots),
                             accountStore: LayoutFixtureAccounts(count: 3, snapshots: snapshots), analytics: analytics)
        model.popoverMaximumHeight = 900
        model.showDashboardInPopover()
        window.appearance = NSAppearance(named: .aqua)
        let statuses = model.dashboardServices.map { status in
            var ready = status
            ready.refreshState = .success(lastSuccess: status.snapshot!.capturedAt)
            return ready
        }

        func capture<Content: View>(_ content: Content, name: String) async throws {
            let hosting = NSHostingController(rootView: content.environmentObject(model).frame(width: 488)
                .fixedSize(horizontal: false, vertical: true).background(Color(nsColor: .windowBackgroundColor)))
            window.contentViewController = hosting
            window.setContentSize(NSSize(width: 488, height: 180))
            for _ in 0..<12 { try await Task.sleep(for: .milliseconds(50)) }
            window.setContentSize(hosting.view.fittingSize)
            hosting.view.layoutSubtreeIfNeeded()
            let bounds = hosting.view.bounds
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 2), pixelsHigh: Int(bounds.height * 2),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.size = bounds.size
            hosting.view.cacheDisplay(in: bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
        }

        try await capture(VStack(alignment: .leading, spacing: 10) {
            PopoverHeaderView(analytics: analytics)
            VStack(spacing: 0) {
                ForEach(statuses, id: \.service) { ServiceSectionView(status: $0) }
            }
        }.padding(10), name: "dashboard")
        for status in statuses where status.service != .openCodeGo {
            try await capture(ServiceSectionView(status: status).padding(10), name: status.service == .claude ? "claude" : "chatgpt")
        }
        if let first = analytics.groups.first { analytics.setExpanded(first.id, true) }
        model.showAnalyticsInPopover()
        try await capture(PopoverRootView(), name: "analysis")
        model.showSettingsInPopover()
        try await capture(PopoverRootView(), name: "settings")
        print("MARKETING_SCREENSHOTS_PASS: native production views, synthetic data, 2x display scale")
    }

    private static func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private static func writeLogoScaleProofs(in view: NSView, name: String, output: URL) throws {
        func logoViews(_ view: NSView) -> [NSImageView] {
            if let imageView = view as? NSImageView,
               imageView.image?.representations.contains(where: { $0 is NSPDFImageRep }) == true {
                return [imageView]
            }
            return view.subviews.flatMap(logoViews)
        }
        let logos = logoViews(view)
        precondition(logos.count >= 3)
        for (index, logo) in logos.enumerated() {
            precondition(abs(logo.bounds.width - 18) < 0.01 && abs(logo.bounds.height - 18) < 0.01)
            for scale in [1, 2] {
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 18 * scale, pixelsHigh: 18 * scale,
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                bitmap.size = logo.bounds.size
                logo.cacheDisplay(in: logo.bounds, to: bitmap)
                var occupied = 0
                for x in 0..<bitmap.pixelsWide {
                    for y in 0..<bitmap.pixelsHigh where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                        occupied += 1
                    }
                }
                precondition(occupied > 20)
                let png = bitmap.representation(using: .png, properties: [:])!
                try png.write(to: output.appendingPathComponent("\(name)-logo-\(index)-\(scale)x.png"))
            }
        }
    }

    private static func fixtures() -> [ServiceKind: ServiceSnapshot] {
        let now = Date()
        func metric(_ key: String, _ title: String, _ remaining: Double, _ reset: String) -> UsageMetric {
            UsageMetric(key: key, title: title, valueText: "\(Int(remaining * 100))% remaining", subtitle: reset,
                        progress: remaining, style: .progress)
        }
        let claude = [metric("current-session", "Session", 0.89, "Reset in 2h 10m"),
                      metric("weekly-all-models", "All models", 0.84, "Reset Friday 12:00"),
                      metric("weekly-fable", "Fable", 0.92, "Separate Fable limit"),
                      UsageMetric(key: "extra-usage-spend", title: "Extra usage", valueText: "$0.00 spent", subtitle: nil, progress: 1, style: .progress),
                      UsageMetric(key: "monthly-spend-limit", title: "Monthly limit", valueText: "$200", subtitle: nil, progress: nil, style: .stat)]
        return [
            .chatGPT: ServiceSnapshot(service: .chatGPT, capturedAt: now, pageTitle: "Synthetic", url: "https://chatgpt.com", metrics: [metric("weekly-limit", "Weekly", 0.8, "Reset in 5d 8h")],
                                     bankedResets: BankedResetInventory(capturedAt: now, groups: [.init(title: "Full reset", expiresAt: now.addingTimeInterval(864_000), expiryText: "Expires in 10 days", count: 3)])),
            .claude: ServiceSnapshot(service: .claude, capturedAt: now, pageTitle: "Synthetic", url: "https://claude.ai", metrics: claude),
            .openCodeGo: ServiceSnapshot(service: .openCodeGo, capturedAt: now, pageTitle: "Synthetic", url: "https://opencode.ai", metrics: [metric("rolling-usage", "Rolling", 0.96, "Reset in 4h 10m"), metric("weekly-usage", "Weekly", 0.68, "Reset in 2d 3h"), metric("monthly-usage", "Monthly", 0.42, "Reset in 16d 8h")])
        ]
    }
}
