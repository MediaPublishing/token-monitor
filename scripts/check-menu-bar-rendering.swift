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
        defaults.removeObject(forKey: "statusMenuAccountArrangement")

        func snapshot(_ service: ServiceKind, session: Double, total: Double) -> ServiceSnapshot {
            let keys = service == .claude ? ["current-session", "weekly-all-models"] : ["five-hour-limit", "weekly-limit"]
            return ServiceSnapshot(service: service, capturedAt: .now, pageTitle: "Synthetic proof", url: service.usageURL.absoluteString,
                metrics: zip(keys, [session, total]).map { key, value in
                    UsageMetric(key: key, title: key, valueText: "\(Int(value * 100))% remaining", subtitle: nil,
                                progress: value, style: .progress)
                })
        }
        var primary = MonitoredAccount.primary(for: .claude)
        primary.snapshot = snapshot(.claude, session: 1, total: 0.07)
        var chatGPT = MonitoredAccount.primary(for: .chatGPT)
        chatGPT.snapshot = snapshot(.chatGPT, session: 1, total: 0.99)
        let second = MonitoredAccount(id: UUID(), service: .claude, name: "Claude Pat", isPrimary: false,
                                      snapshot: snapshot(.claude, session: 0.66, total: 0.47))
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
        precondition(model.statusMenuAccountArrangement == .compact)
        var records: [[String: Any]] = []
        var examples: [Int: NSImage] = [:]

        func render(_ name: String, dark: Bool = false) throws -> NSImage {
            let image = renderer.makeCapacityStatusImage(for: NSAppearance(named: dark ? .darkAqua : .aqua))!
            let bitmaps = image.representations.compactMap { $0 as? NSBitmapImageRep }
            precondition(bitmaps.map(\.pixelsWide).sorted() == [Int(image.size.width), Int(image.size.width) * 2])
            let layout = model.statusMenuAccountLayout
            let columnWidth: CGFloat = model.statusMenuShowsPercentages
                ? (model.statusMenuLimitDisplay == .both ? 74 : 56)
                : (model.statusMenuAccountArrangement == .compact && layout.columnCount > 1 ? 14 : 24)
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
                    let expected = model.statusMenuAccounts.indices.compactMap { layout.position(at: $0) }
                        .filter { $0.column == column }.count
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
                            "arrangement": model.statusMenuAccountArrangement.rawValue,
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
        let selectionBeforeLayoutChange = model.menuBarAccountSelection
        let arrangementObservation = model.$statusMenuAccountArrangement.receive(on: RunLoop.main).sink { _ in
            updatedImage = renderer.makeCapacityStatusImage(for: NSAppearance(named: .aqua))
        }
        model.setStatusMenuAccountArrangement(.byProvider)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        precondition(updatedImage?.size.width == 52 && updatedImage?.size.height == 16)
        precondition(model.menuBarAccountSelection == selectionBeforeLayoutChange && !model.isRefreshing)
        _ = try render("two-by-provider-without-refresh")
        let restored = AppModel(snapshotStore: ProofSnapshots(), accountStore: proofAccounts,
                                analytics: ProjectAnalyticsModel(defaults: analyticsDefaults, home: output))
        precondition(restored.statusMenuAccountArrangement == .byProvider)
        precondition(restored.statusMenuAccountLayout.columnCount == 2 && restored.statusMenuAccountLayout.rowCount == 1)
        defaults.set("unknown", forKey: "statusMenuAccountArrangement")
        let invalidPreference = AppModel(snapshotStore: ProofSnapshots(), accountStore: proofAccounts,
                                         analytics: ProjectAnalyticsModel(defaults: analyticsDefaults, home: output))
        precondition(invalidPreference.statusMenuAccountArrangement == .compact)
        model.setStatusMenuAccountArrangement(.compact)
        model.showMenuBarAccountAlongside(primary.id, for: .claude)
        precondition(model.statusMenuAccounts.map(\.accountID) == [chatGPT.id, second.id, primary.id])
        precondition(model.statusMenuAccountLayout.columnCount == 1)
        precondition(model.statusMenuAccountLayout.rowCount == 3)
        _ = try render("three-no-provider-holes")

        let primaryScores = model.statusMenuScores(for: primary.id)
        let secondScores = model.statusMenuScores(for: second.id)
        precondition(primaryScores.session == 1 && primaryScores.total == 0.07)
        precondition(secondScores.session == 0.66 && secondScores.total == 0.47)
        model.setMenuBarAccount(primary.id, for: .claude)
        let selectionBeforeLimitChange = model.menuBarAccountSelection
        var limitUpdatedImage: NSImage?
        let limitObservation = model.$statusMenuLimitDisplay.receive(on: RunLoop.main).sink { _ in
            limitUpdatedImage = renderer.makeCapacityStatusImage(for: NSAppearance(named: .aqua))
        }
        model.setStatusMenuAccountArrangement(.byProvider)
        model.setStatusMenuShowsPercentages(true)
        model.setStatusMenuUsesColor(false)
        model.setStatusMenuLimitDisplay(.total)
        let totalImage = try render("patrick-total", dark: true)
        model.setStatusMenuLimitDisplay(.both)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        precondition(limitUpdatedImage != nil && limitUpdatedImage?.size.width == 152)
        precondition(model.menuBarAccountSelection == selectionBeforeLimitChange && !model.isRefreshing)
        let bothImage = try render("patrick-both", dark: true)
        precondition(totalImage.tiffRepresentation != bothImage.tiffRepresentation)
        precondition(model.statusMenuScores(for: primary.id).total == 0.07)
        precondition(model.statusMenuScores(for: second.id).session == 0.66)
        try writeLimitComparison(total: totalImage, both: bothImage, output: output)
        model.setMenuBarAccount(second.id, for: .claude)

        for count in 3...9 {
            if count > 3 { model.showMenuBarAccountAlongside(extras[count - 4].id, for: .claude) }
            precondition(model.statusMenuAccounts.count == count)
            precondition(!model.isRefreshing)
            for arrangement in MenuBarAccountArrangement.allCases {
              model.setStatusMenuAccountArrangement(arrangement)
              for display in StatusMenuLimitDisplay.allCases {
                model.setStatusMenuLimitDisplay(display)
                for percentages in [false, true] {
                    model.setStatusMenuShowsPercentages(percentages)
                    for colored in [true, false] {
                        model.setStatusMenuUsesColor(colored)
                        for dark in [false, true] {
                            let prefix = arrangement == .compact ? "" : "by-provider-"
                            let image = try render("\(prefix)\(count)-\(display.rawValue)-\(percentages ? "percent" : "bars")-\(colored ? "color" : "mono")-\(dark ? "dark" : "light")", dark: dark)
                            if arrangement == .compact && display == .total && !percentages && colored && !dark && [3, 4, 6].contains(count) {
                                examples[count] = image
                            }
                        }
                    }
                }
              }
            }
        }
        model.setStatusMenuAccountArrangement(.compact)
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
        for account in extras { threeProviders.showMenuBarAccountAlongside(account.id, for: .claude) }
        threeProviders.setStatusMenuAccountArrangement(.byProvider)
        let grouped = threeProviders.statusMenuAccountLayout
        precondition(grouped.columnCount == 3 && grouped.rowCount == 3)
        precondition(grouped.visibleCount == 5 && grouped.overflowCount == 5)
        let lastIndex = threeProviders.statusMenuAccounts.count - 1
        precondition(grouped.position(at: lastIndex)?.column == 2)
        let reservedImage = AppDelegate(model: threeProviders).makeCapacityStatusImage(for: NSAppearance(named: .aqua))!
        precondition(reservedImage.size.width > 80 && reservedImage.size.width <= 112 && reservedImage.size.height == 18)
        for bitmap in reservedImage.representations.compactMap({ $0 as? NSBitmapImageRep }) {
            let scale = Int(CGFloat(bitmap.pixelsWide) / reservedImage.size.width)
            precondition((0..<bitmap.pixelsHigh).contains {
                (bitmap.colorAt(x: 66 * scale, y: $0)?.alphaComponent ?? 0) > 0.05
            }, "OpenCode must remain visible even when earlier providers overflow")
        }
        try writeAccountGridExamples(examples, output: output)
        try writeArrangementExamples(model: model, renderer: renderer, output: output)
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("records.json"))
        withExtendedLifetime(observation) { }
        withExtendedLifetime(arrangementObservation) { }
        withExtendedLifetime(limitObservation) { }
        print("PASS: \(records.count) native renders, independent Claude account limits (100/7 and 66/47), queued account/arrangement/limit changes without refresh, persisted layout, compact fallback for invalid preferences, exact bar-band counts in both layouts, all limits/percentages/colors/appearances, bounded +N overflow, nine selected accounts preserved, reorder/hide, unavailable provider")
    }

    private static func writeLimitComparison(total: NSImage, both: NSImage, output: URL) throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 292))
        view.appearance = NSAppearance(named: .darkAqua)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
        func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat = 12, bold: Bool = false) {
            let field = NSTextField(labelWithString: text)
            field.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
            field.textColor = .white
            field.frame = NSRect(x: x, y: y, width: 520, height: 22)
            view.addSubview(field)
        }
        label("Session und Gesamtlimit je Konto", x: 20, y: 248, size: 18, bold: true)
        label("Original-Renderer · Beispielwerte · 2x vergrößert · ohne Farben", x: 20, y: 224, size: 11)
        for (index, entry) in [("Total", total), ("Both: Session / Total", both)].enumerated() {
            let y = CGFloat(168 - index * 72)
            label(entry.0, x: 20, y: y, bold: true)
            let imageView = NSImageView(image: entry.1)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.frame = NSRect(x: 216, y: y - 8, width: entry.1.size.width * 2, height: entry.1.size.height * 2)
            view.addSubview(imageView)
        }
        label("Links: ChatGPT · rechts oben: Claude · rechts unten: Claude Pat", x: 20, y: 52, size: 11)
        label("Both: Claude 100/7 % · Claude Pat 66/47 %", x: 20, y: 30, size: 11)
        let window = NSWindow(contentRect: view.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1120, pixelsHigh: 584,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent("patrick-session-total.png"))
        window.close()
    }

    private static func writeAccountGridExamples(_ examples: [Int: NSImage], output: URL) throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 488, height: 320))
        view.appearance = NSAppearance(named: .aqua)
        view.wantsLayer = true
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat = 12, bold: Bool = false) {
            let field = NSTextField(labelWithString: text)
            field.font = NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
            field.textColor = .labelColor
            field.frame = NSRect(x: x, y: y, width: 488 - x - 16, height: 20)
            view.addSubview(field)
        }
        label("Compact menu-bar accounts", x: 20, y: 278, size: 16, bold: true)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        label("Example cached data · Version \(version)", x: 20, y: 256, size: 11)
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

    private static func writeArrangementExamples(model: AppModel, renderer: AppDelegate, output: URL) throws {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 488, height: 180))
        view.appearance = NSAppearance(named: .aqua)
        view.wantsLayer = true
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        model.setStatusMenuLimitDisplay(.both)
        model.setStatusMenuShowsPercentages(false)
        model.setStatusMenuUsesColor(true)
        for (index, arrangement) in MenuBarAccountArrangement.allCases.enumerated() {
            let x = CGFloat(20 + index * 244)
            let title = NSTextField(labelWithString: arrangement.title + (arrangement == .compact ? " (Default)" : ""))
            title.font = .systemFont(ofSize: 14, weight: .semibold)
            title.textColor = .labelColor
            title.frame = NSRect(x: x, y: 135, width: 224, height: 24)
            view.addSubview(title)
            model.setStatusMenuAccountArrangement(arrangement)
            let image = renderer.makeCapacityStatusImage(for: NSAppearance(named: .aqua))!
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.frame = NSRect(x: x, y: 75, width: image.size.width * 2, height: image.size.height * 2)
            view.addSubview(imageView)
        }
        let note = NSTextField(labelWithString: "Three accounts · Two providers · Synthetic data")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .labelColor
        note.frame = NSRect(x: 20, y: 22, width: 448, height: 20)
        view.addSubview(note)
        let window = NSWindow(contentRect: view.bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 976, pixelsHigh: 360,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        bitmap.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: output.appendingPathComponent("menu-bar-layout-options.png"))
        window.close()
    }
}
