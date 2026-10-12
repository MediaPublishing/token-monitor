import AppKit
import Combine
import TokenMonitorCore

private struct ProofAccounts: AccountPersisting {
    let accounts: [MonitoredAccount]
    func loadAccounts() throws -> [MonitoredAccount] { accounts }
    func saveAccounts(_ accounts: [MonitoredAccount]) throws { }
}

private struct ProofSnapshots: SnapshotPersisting {
    func loadSnapshots() throws -> [ServiceKind: ServiceSnapshot] { [:] }
    func saveSnapshots(_ snapshots: [ServiceKind: ServiceSnapshot]) throws { }
}

@main @MainActor struct MenuBarRenderingProof {
    static func main() throws {
        guard let domain = Bundle.main.bundleIdentifier, domain.hasSuffix(".menu-bar-proof") else {
            fatalError("Only run inside the isolated menu-bar-proof bundle")
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let defaults = UserDefaults.standard
        defaults.set([String: [String]](), forKey: "menuBarSelectionIDs")
        defaults.set([String: String](), forKey: "menuBarAccountIDs")
        defaults.set(false, forKey: "openCodeGoEnabled")
        defaults.set(false, forKey: "projectAnalyticsEnabled")
        defaults.set(false, forKey: "statusMenuShowsPercentages")
        defaults.set(true, forKey: "statusMenuUsesColor")
        defaults.set("total", forKey: "statusMenuLimitDisplay")

        func snapshot(_ service: ServiceKind, session: Double, total: Double) -> ServiceSnapshot {
            let keys = service == .claude ? ["current-session", "weekly-all-models"] : ["five-hour-limit", "weekly-limit"]
            return ServiceSnapshot(service: service, capturedAt: .now, pageTitle: "Synthetic proof", url: service.usageURL.absoluteString,
                metrics: zip(keys, [session, total]).map { key, value in
                    UsageMetric(key: key, title: key, valueText: "\(Int(value * 100))% remaining", subtitle: nil,
                                progress: value, style: .progress)
                })
        }
        var primary = MonitoredAccount.primary(for: .claude)
        primary.snapshot = snapshot(.claude, session: 0.8, total: 0.6)
        var chatGPT = MonitoredAccount.primary(for: .chatGPT)
        chatGPT.snapshot = snapshot(.chatGPT, session: 0.9, total: 0.95)
        let second = MonitoredAccount(id: UUID(), service: .claude, name: "Synthetic Second Brain", isPrimary: false,
                                      snapshot: snapshot(.claude, session: 0.2, total: 0.1))
        let extras = (0..<2).map { index in
            MonitoredAccount(id: UUID(), service: .claude, name: "Synthetic Extra \(index)", isPrimary: false,
                             snapshot: snapshot(.claude, session: 0.4, total: 0.5))
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let analyticsDefaults = UserDefaults(suiteName: domain + ".analytics")!
        analyticsDefaults.set(false, forKey: "projectAnalyticsEnabled")
        let proofAccounts = ProofAccounts(accounts: [chatGPT, primary, second] + extras)
        let model = AppModel(snapshotStore: ProofSnapshots(), accountStore: proofAccounts,
                             analytics: ProjectAnalyticsModel(defaults: analyticsDefaults, home: output))
        let renderer = AppDelegate(model: model)
        precondition(!model.isRefreshing)

        func render(_ name: String, dark: Bool = false) throws -> NSImage {
            let image = renderer.makeCapacityStatusImage(for: NSAppearance(named: dark ? .darkAqua : .aqua))!
            let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
            let columns = model.statusMenuAccountColumns.count
            let width = (image.size.width - CGFloat(columns - 1) * 6) / CGFloat(columns)
            let scale = CGFloat(bitmap.pixelsWide) / image.size.width
            for column in 0..<columns {
                let start = Int((CGFloat(column) * (width + 6) + 1) * scale)
                let end = Int((CGFloat(column) * (width + 6) + width - 1) * scale)
                let hasPixels = (start..<end).contains { x in
                    (0..<bitmap.pixelsHigh).contains { y in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 }
                }
                precondition(hasPixels)
            }
            try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
            return image
        }
        let before = try render("single-before")
        precondition(before.size.width == 20)
        var updatedImage: NSImage?
        let observation = model.$menuBarAccountSelection.receive(on: RunLoop.main).sink { _ in
            updatedImage = renderer.makeCapacityStatusImage(for: NSAppearance(named: .aqua))
        }
        model.setMenuBarAccount(second.id, for: .claude)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        precondition(model.menuBarAccountID(for: .claude) == second.id)
        precondition(updatedImage != nil && updatedImage?.tiffRepresentation != before.tiffRepresentation)
        precondition(!model.isRefreshing)
        _ = try render("single-switched-without-refresh")
        model.showMenuBarAccountAlongside(primary.id, for: .claude)
        precondition(model.statusMenuAccountColumns.count == 2)
        precondition(model.statusMenuAccountColumns[1][0] == nil)
        precondition(model.statusMenuAccountColumns[1][1]?.accountID == primary.id)
        for display in StatusMenuLimitDisplay.allCases {
            model.setStatusMenuLimitDisplay(display)
            for percentages in [false, true] {
                model.setStatusMenuShowsPercentages(percentages)
                for dark in [false, true] {
                    let image = try render("dual-\(display.rawValue)-\(percentages ? "percent" : "bars")-\(dark ? "dark" : "light")", dark: dark)
                    let width: CGFloat = percentages ? (display == .both ? 74 : 56) : 20
                    precondition(image.size.width == width * 2 + 6 && image.size.height == 16)
                }
            }
        }
        model.setMenuBarAccount(primary.id, for: .claude)
        precondition(model.menuBarAccounts(for: .claude).map(\.id) == [primary.id, second.id])
        model.hideMenuBarAccount(second.id, for: .claude)
        precondition(model.statusMenuAccountColumns.count == 1)
        model.showMenuBarAccountAlongside(second.id, for: .claude)
        for account in extras { model.showMenuBarAccountAlongside(account.id, for: .claude) }
        model.setStatusMenuShowsPercentages(false)
        let fourColumnImage = try render("four-columns")
        precondition(fourColumnImage.size.width == 98)
        defaults.set(true, forKey: "openCodeGoEnabled")
        let threeProviders = AppModel(snapshotStore: ProofSnapshots(), accountStore: proofAccounts,
                                      analytics: ProjectAnalyticsModel(defaults: analyticsDefaults, home: output))
        let threeProviderImage = AppDelegate(model: threeProviders).makeCapacityStatusImage(for: NSAppearance(named: .aqua))!
        precondition(threeProviderImage.size.width == 98 && threeProviderImage.size.height == 18)
        let threeProviderBitmap = NSBitmapImageRep(data: threeProviderImage.tiffRepresentation!)!
        try threeProviderBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("three-providers.png"))
        withExtendedLifetime(observation) { }
        print("PASS: real AppModel queued switch without refresh, independent columns, reorder/hide, all limit modes, percentages, light/dark, nonblank columns, four-column bound, three providers")
    }
}
