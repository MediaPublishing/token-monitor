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
        let extras = (0..<6).map { index in
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
        var records: [[String: Any]] = []
        var examples: [Int: NSImage] = [:]

        func render(_ name: String, dark: Bool = false) throws -> NSImage {
            let image = renderer.makeCapacityStatusImage(for: NSAppearance(named: dark ? .darkAqua : .aqua))!
            let bitmaps = image.representations.compactMap { $0 as? NSBitmapImageRep }
            precondition(bitmaps.map(\.pixelsWide).sorted() == [Int(image.size.width), Int(image.size.width) * 2])
            let layout = model.statusMenuAccountLayout
            let columnWidth: CGFloat = model.statusMenuShowsPercentages
                ? (model.statusMenuLimitDisplay == .both ? 74 : 56) : (layout.columnCount > 1 ? 14 : 24)
            let gridWidth = columnWidth * CGFloat(layout.columnCount) + CGFloat(layout.columnCount - 1) * 4
            let barStart: CGFloat = model.statusMenuShowsPercentages ? (model.statusMenuLimitDisplay == .both ? 43 : 29) : 1
            for bitmap in bitmaps {
                let scale = CGFloat(bitmap.pixelsWide) / image.size.width
                for column in 0..<layout.columnCount {
                    let start = Int((CGFloat(column) * (columnWidth + 4) + barStart + 1) * scale)
                    let end = Int((CGFloat(column) * (columnWidth + 4) + columnWidth - 2) * scale)
                    var bands = 0
                    var wasFilled = false
                    for y in 0..<bitmap.pixelsHigh {
                        let filled = (start..<end).contains { x in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 }
                        if filled && !wasFilled { bands += 1 }
                        wasFilled = filled
                    }
                    let expected = min(layout.rowCount, layout.visibleCount - column * layout.rowCount)
                    precondition(bands == expected, "\(name): column \(column) has \(bands) bars, expected \(expected)")
                }
                if layout.overflowCount == 0 {
                    precondition(image.size.width == gridWidth)
                } else {
                    precondition(image.size.width > gridWidth && image.size.width <= gridWidth + 32)
                    let start = Int((gridWidth + 3) * scale)
                    precondition((start..<bitmap.pixelsWide).contains { x in
                        (0..<bitmap.pixelsHigh).contains { y in (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 }
                    })
                }
                precondition(image.size.height <= (model.statusMenuShowsPercentages ? 21 : 18))
                let suffix = scale == 1 ? "" : "-2x"
                try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + suffix + ".png"))
            }
            records.append(["name": name, "accounts": model.statusMenuAccounts.count,
                            "visible": layout.visibleCount, "overflow": layout.overflowCount,
                            "columns": layout.columnCount, "rows": layout.rowCount,
                            "width": image.size.width, "height": image.size.height, "scales": [1, 2]])
            return image
        }

        let before = try render("two-before")
        examples[2] = before
        precondition(before.size.width == 24 && before.size.height == 16)
        var updatedImage: NSImage?
        let observation = model.$menuBarAccountSelection.receive(on: RunLoop.main).sink { _ in
            updatedImage = renderer.makeCapacityStatusImage(for: NSAppearance(named: .aqua))
        }
        model.setMenuBarAccount(second.id, for: .claude)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        precondition(model.menuBarAccountID(for: .claude) == second.id)
        precondition(updatedImage != nil && updatedImage?.tiffRepresentation != before.tiffRepresentation)
        precondition(!model.isRefreshing)
        _ = try render("two-switched-without-refresh")
        model.showMenuBarAccountAlongside(primary.id, for: .claude)
        precondition(model.statusMenuAccounts.map(\.accountID) == [chatGPT.id, second.id, primary.id])
        precondition(model.statusMenuAccountLayout.columnCount == 1)
        precondition(model.statusMenuAccountLayout.rowCount == 3)
        _ = try render("three-no-provider-holes")

        for count in 3...9 {
            if count > 3 { model.showMenuBarAccountAlongside(extras[count - 4].id, for: .claude) }
            precondition(model.statusMenuAccounts.count == count)
            precondition(!model.isRefreshing)
            for display in StatusMenuLimitDisplay.allCases {
                model.setStatusMenuLimitDisplay(display)
                for percentages in [false, true] {
                    model.setStatusMenuShowsPercentages(percentages)
                    for colored in [true, false] {
                        model.setStatusMenuUsesColor(colored)
                        for dark in [false, true] {
                            let image = try render("\(count)-\(display.rawValue)-\(percentages ? "percent" : "bars")-\(colored ? "color" : "mono")-\(dark ? "dark" : "light")", dark: dark)
                            if display == .total && !percentages && colored && !dark && [3, 4, 6].contains(count) {
                                examples[count] = image
                            }
                        }
                    }
                }
            }
        }
        model.setMenuBarAccount(primary.id, for: .claude)
        precondition(model.menuBarAccounts(for: .claude).first?.id == primary.id)
        model.hideMenuBarAccount(second.id, for: .claude)
        precondition(model.statusMenuAccounts.count == 8)
        model.showMenuBarAccountAlongside(second.id, for: .claude)
        precondition(model.statusMenuAccounts.count == 9)
        precondition(model.menuBarPositionDescription(for: second.id).contains("Additional"))
        for account in extras { model.hideMenuBarAccount(account.id, for: .claude) }
        model.setStatusMenuShowsPercentages(false)
        _ = try render("three-after-hide")
        precondition(model.statusMenuAccounts.count == 3)

        defaults.set(true, forKey: "openCodeGoEnabled")
        let threeProviders = AppModel(snapshotStore: ProofSnapshots(), accountStore: proofAccounts,
                                     analytics: ProjectAnalyticsModel(defaults: analyticsDefaults, home: output))
        precondition(threeProviders.statusMenuAccounts.count == 4)
        precondition(threeProviders.statusMenuAccountLayout.rowCount == 2)
        precondition(threeProviders.statusMenuAccounts.last?.connectionStatus == .authRequired)
        let threeProviderImage = AppDelegate(model: threeProviders).makeCapacityStatusImage(for: NSAppearance(named: .aqua))!
        precondition(threeProviderImage.size.width == 32 && threeProviderImage.size.height == 16)
        let threeProviderBitmap = NSBitmapImageRep(data: threeProviderImage.tiffRepresentation!)!
        try threeProviderBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("three-providers.png"))
        try writeAccountGridExamples(examples, output: output)
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("records.json"))
        withExtendedLifetime(observation) { }
        print("PASS: \(records.count) native renders, queued account switch without refresh, exact bar-band counts, 1-column and 2-column packing, all limits/percentages/colors/appearances, bounded +N overflow, nine selected accounts preserved, reorder/hide, unavailable provider")
    }

    private static func writeAccountGridExamples(_ examples: [Int: NSImage], output: URL) throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 488, height: 320))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat = 12, bold: Bool = false) {
            let field = NSTextField(labelWithString: text)
            field.font = NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
            field.textColor = .labelColor
            field.frame = NSRect(x: x, y: y, width: 488 - x - 16, height: 20)
            view.addSubview(field)
        }
        label("Compact menu-bar accounts", x: 20, y: 278, size: 16, bold: true)
        label("Example cached data · Version 1.0.44", x: 20, y: 256, size: 11)
        label("Accounts", x: 20, y: 224, bold: true)
        label("Native size", x: 170, y: 224, bold: true)
        label("2× detail", x: 300, y: 224, bold: true)
        for (row, count) in [2, 3, 4, 6].enumerated() {
            let image = examples[count]!
            let y = CGFloat(176 - row * 42)
            label("\(count) accounts", x: 20, y: y, bold: true)
            for (x, scale) in [(CGFloat(180), CGFloat(1)), (CGFloat(310), CGFloat(2))] {
                let imageView = NSImageView(image: image)
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.frame = NSRect(x: x, y: y + 10 - image.size.height * scale / 2,
                                         width: image.size.width * scale, height: image.size.height * scale)
                view.addSubview(imageView)
            }
        }
        label("One bar per account · Hover for names · Reset: Fri 12:00", x: 20, y: 18, size: 11)
        let window = NSWindow(contentRect: view.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 976, pixelsHigh: 640,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent("menu-bar-accounts.png"))
        window.close()
    }
}
