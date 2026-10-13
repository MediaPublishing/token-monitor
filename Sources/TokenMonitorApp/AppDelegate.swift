import AppKit
import Combine
import SwiftUI
import TokenMonitorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static weak var shared: AppDelegate?
    static let popoverWidth: CGFloat = 488

    private let model: AppModel
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private var dashboardSubscription: AnyCancellable?
    private var popoverScreenSubscription: AnyCancellable?
    private var statusMenuSettingsSubscription: AnyCancellable?
    private var menuBarAccountSubscription: AnyCancellable?
    private var updateSubscription: AnyCancellable?
    private var analyticsSubscription: AnyCancellable?
    private var dashboardHostingController: NSHostingController<AnyView>?
    private var outsideClickMonitor: Any?
    private var measuredPopoverSizes: [PopoverScreen: CGSize] = [:]
    private var screenSubscription: AnyCancellable?

    init(model: AppModel = .shared) {
        self.model = model
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        NSApp.setActivationPolicy(.accessory)

        configurePopover()
        configureStatusItem()
        observeDashboardState()

        model.start()
        updateStatusItem()
    }

    func showSettingsWindow() {
        model.showSettingsInPopover()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePopover(nil) }
        return false
    }

    func closePopover() {
        popover.performClose(nil)
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        guard let monitor = outsideClickMonitor else {
            return
        }

        NSEvent.removeMonitor(monitor)
        outsideClickMonitor = nil
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        model.didOpenPopover()
        updatePopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.becomeKey()
        installOutsideClickMonitor()
    }

    private func configurePopover() {
        let rootView = AnyView(
            PopoverRootView(onSizeChange: { [weak self] screen, size in
                self?.applyMeasuredPopoverSize(size, for: screen)
            })
                .environmentObject(model)
        )

        let hostingController = NSHostingController(rootView: rootView)
        dashboardHostingController = hostingController
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: Self.popoverWidth, height: 180)
        popover.contentViewController = hostingController
        updatePopoverSize()
        screenSubscription = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updatePopoverSize() }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = makeCapacityStatusImage(for: button.effectiveAppearance)
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover(_:))
        }
        statusItem = item
    }

    private func observeDashboardState() {
        updateSubscription = AppUpdateController.shared.$availableVersion.sink { [weak self] version in
            self?.updateStatusItem(availableUpdate: version)
        }
        // @Published emits before storage changes; size from committed state on the next run loop.
        dashboardSubscription = model.$dashboardState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
                self?.updatePopoverSize()
            }

        menuBarAccountSubscription = model.$menuBarAccountSelection
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }

        popoverScreenSubscription = Publishers.CombineLatest(
            model.$popoverScreen,
            model.$showUsageDetails
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }

        analyticsSubscription = model.analytics.$enabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updatePopoverSize() }

        statusMenuSettingsSubscription = Publishers.CombineLatest4(
            model.$statusMenuUsesColor,
            model.$statusMenuShowsPercentages,
            model.$statusMenuLimitDisplay,
            model.$openCodeGoEnabled
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.updateStatusItem()
        }
    }

    private func updateStatusItem(availableUpdate: String? = AppUpdateController.shared.availableVersion) {
        guard let button = statusItem?.button else {
            return
        }

        button.image = makeCapacityStatusImage(for: button.effectiveAppearance)
        button.attributedTitle = NSAttributedString(
            string: availableUpdate == nil ? "" : " Update",
            attributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                         .foregroundColor: statusBarForegroundColor(for: button.effectiveAppearance)]
        )
        button.toolTip = tooltipText() + (availableUpdate.map { "\nUpdate \($0) available. Open Token Monitor to review." } ?? "")
    }

    func makeCapacityStatusImage(for appearance: NSAppearance?) -> NSImage? {
        let services = model.statusMenuServices
        let columns = model.statusMenuAccountColumns
        let showsBothLimits = model.statusMenuLimitDisplay == .both
        let columnWidth: CGFloat = model.statusMenuShowsPercentages
            ? (showsBothLimits ? 74 : 56)
            : 20
        let columnGap: CGFloat = 6
        let width = columnWidth * CGFloat(columns.count) + columnGap * CGFloat(max(0, columns.count - 1))
        let height: CGFloat = services.count > 2
            ? (model.statusMenuShowsPercentages ? 21 : 18)
            : 16
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        let foregroundColor = statusBarForegroundColor(for: appearance)
        let trackColor = statusBarTrackColor(for: appearance)
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        for (index, column) in columns.enumerated() {
            let offset = CGFloat(index) * (columnWidth + columnGap)
            if index > 0 {
                trackColor.setFill()
                NSBezierPath(rect: NSRect(x: offset - columnGap / 2, y: 2, width: 0.5, height: height - 4)).fill()
            }
            drawStatusColumn(column, width: columnWidth, height: height, offset: offset,
                             showsBothLimits: showsBothLimits, foregroundColor: foregroundColor, trackColor: trackColor)
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawStatusColumn(_ accounts: [ServiceStatus?], width: CGFloat, height: CGFloat, offset: CGFloat,
                                  showsBothLimits: Bool, foregroundColor: NSColor, trackColor: NSColor) {
        let rowHeight = height / CGFloat(max(accounts.count, 1))
        let barHeight: CGFloat = accounts.count > 2 ? 5 : 6
        let statusValueFontSize: CGFloat = accounts.count > 2 ? 6 : 7
        for (index, account) in accounts.enumerated() {
            guard let account else { continue }
            let rowY = CGFloat(accounts.count - index - 1) * rowHeight
            let barY = rowY + (rowHeight - barHeight) / 2
            let status = account.connectionStatus
            let scores = model.statusMenuScores(for: account.accountID)
            let selectedScore = model.statusMenuLimitDisplay == .session
                ? scores.session
                : scores.total

            if model.statusMenuShowsPercentages {
                if showsBothLimits {
                    drawStatusPair(
                        session: scores.session,
                        total: scores.total,
                        in: NSRect(x: offset, y: rowY, width: 39, height: rowHeight),
                        foregroundColor: foregroundColor,
                        fontSize: statusValueFontSize
                    )
                    drawCombinedBar(
                        in: NSRect(x: offset + 43, y: barY, width: width - 44, height: barHeight),
                        sessionScore: scores.session,
                        totalScore: scores.total,
                        status: status,
                        foregroundColor: foregroundColor,
                        trackColor: trackColor
                    )
                } else {
                    drawStatusValue(
                        for: selectedScore,
                        in: NSRect(x: offset, y: rowY, width: 25, height: rowHeight),
                        foregroundColor: foregroundColor,
                        fontSize: statusValueFontSize
                    )
                    drawBar(
                        in: NSRect(x: offset + 29, y: barY, width: width - 30, height: barHeight),
                        score: selectedScore,
                        status: status,
                        foregroundColor: foregroundColor,
                        trackColor: trackColor
                    )
                }
            } else if showsBothLimits {
                drawCombinedBar(
                    in: NSRect(x: offset + 1, y: barY, width: width - 2, height: barHeight),
                    sessionScore: scores.session,
                    totalScore: scores.total,
                    status: status,
                    foregroundColor: foregroundColor,
                    trackColor: trackColor
                )
            } else {
                drawBar(
                    in: NSRect(x: offset + 1, y: barY, width: width - 2, height: barHeight),
                    score: selectedScore,
                    status: status,
                    foregroundColor: foregroundColor,
                    trackColor: trackColor
                )
            }
        }

    }

    private func drawBar(
        in rect: NSRect,
        score: Double?,
        status: ServiceConnectionStatus,
        foregroundColor: NSColor,
        trackColor: NSColor
    ) {
        let trackPath = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        trackColor.setFill()
        trackPath.fill()

        guard let score else {
            let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
            statusAccentColor(for: status, foregroundColor: foregroundColor).setStroke()
            outline.lineWidth = 1
            outline.stroke()
            return
        }

        let clamped = max(0.08, min(score, 1))
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width * clamped, height: rect.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
        capacityColor(for: score, status: status, foregroundColor: foregroundColor).setFill()
        fillPath.fill()

    }

    private func drawStatusValue(
        for score: Double?,
        in rect: NSRect,
        alignment: NSTextAlignment = .right,
        foregroundColor: NSColor,
        fontSize: CGFloat
    ) {
        let label = score.map { "\(Int((max(0, min($0, 1)) * 100).rounded()))%" } ?? "--"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraph
        ]
        (label as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func drawStatusPair(
        session: Double?,
        total: Double?,
        in rect: NSRect,
        foregroundColor: NSColor,
        fontSize: CGFloat
    ) {
        func percentage(_ score: Double?) -> String {
            score.map { String(Int((max(0, min($0, 1)) * 100).rounded())) } ?? "--"
        }

        let label = "\(percentage(session))/\(percentage(total))%"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraph
        ]
        (label as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func drawCombinedBar(
        in rect: NSRect,
        sessionScore: Double?,
        totalScore: Double?,
        status: ServiceConnectionStatus,
        foregroundColor: NSColor,
        trackColor: NSColor
    ) {
        let trackPath = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        trackColor.setFill()
        trackPath.fill()

        func drawLayer(_ score: Double?, alpha: CGFloat) {
            guard let score else {
                return
            }
            let clamped = max(0.08, min(score, 1))
            let fillRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width * clamped, height: rect.height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
            capacityColor(for: score, status: status, foregroundColor: foregroundColor)
                .withAlphaComponent(alpha)
                .setFill()
            fillPath.fill()
        }

        drawLayer(totalScore, alpha: 0.62)
        drawLayer(sessionScore, alpha: 0.62)

        func drawEndpoint(_ score: Double?, upperHalf: Bool) {
            guard let score else {
                return
            }
            let x = rect.minX + rect.width * max(0, min(score, 1))
            let marker = NSBezierPath()
            marker.move(to: NSPoint(x: x, y: upperHalf ? rect.midY : rect.minY))
            marker.line(to: NSPoint(x: x, y: upperHalf ? rect.maxY : rect.midY))
            foregroundColor.withAlphaComponent(0.9).setStroke()
            marker.lineWidth = 0.75
            marker.stroke()
        }

        drawEndpoint(sessionScore, upperHalf: true)
        drawEndpoint(totalScore, upperHalf: false)
    }

    private func statusBarForegroundColor(for appearance: NSAppearance?) -> NSColor {
        isDarkStatusBarAppearance(appearance) ? .white : .black
    }

    private func statusBarTrackColor(for appearance: NSAppearance?) -> NSColor {
        statusBarForegroundColor(for: appearance).withAlphaComponent(isDarkStatusBarAppearance(appearance) ? 0.32 : 0.16)
    }

    private func isDarkStatusBarAppearance(_ appearance: NSAppearance?) -> Bool {
        let bestMatch = (appearance ?? NSApp.effectiveAppearance)
            .bestMatch(from: [.aqua, .darkAqua, .vibrantLight, .vibrantDark])
        return bestMatch == .darkAqua || bestMatch == .vibrantDark
    }

    private func statusAccentColor(for status: ServiceConnectionStatus, foregroundColor: NSColor) -> NSColor {
        guard model.statusMenuUsesColor else {
            return foregroundColor
        }

        switch status {
        case .healthy:
            return .systemGreen
        case .refreshing:
            return .systemBlue
        case .stale:
            return .systemOrange
        case .authRequired:
            return .systemYellow
        case .error:
            return .systemRed
        }
    }

    private func capacityColor(for score: Double, status: ServiceConnectionStatus, foregroundColor: NSColor) -> NSColor {
        guard model.statusMenuUsesColor else {
            return foregroundColor
        }

        switch status {
        case .error:
            return .systemRed
        case .authRequired:
            return .systemYellow
        case .refreshing:
            if score >= 0.75 { return .systemGreen }
            if score >= 0.5 { return .systemMint }
            if score >= 0.25 { return .systemOrange }
            return .systemRed
        case .stale:
            return score > 0.5 ? .systemOrange : .systemRed
        case .healthy:
            if score >= 0.75 { return .systemGreen }
            if score >= 0.5 { return .systemMint }
            if score >= 0.25 { return .systemOrange }
            return .systemRed
        }
    }

    private func tooltipText() -> String {
        let columns = model.statusMenuAccountColumns
        let statuses = columns.enumerated().flatMap { index, column -> [String] in
            let heading = columns.count > 1 ? ["Column \(index + 1)"] : []
            return heading + column.compactMap { status -> String? in
                guard let status else { return nil }
                let name = status.accountName == status.service.displayName
                    ? status.accountName : "\(status.service.displayName) (\(status.accountName))"
                return "\(name): \(model.stateDescription(for: status))"
            }
        }
        let limitDescription = model.statusMenuLimitDisplay == .both
            ? "Menu bar: Session / Total"
            : "Menu bar: \(model.statusMenuLimitDisplay.title)"
        return (["Token Monitor", model.lastRefreshText, limitDescription] + statuses).joined(separator: "\n")
    }

    private func updatePopoverSize() {
        let window = statusItem?.button?.window
        let screen = window?.screen ?? NSScreen.main
        if let screen {
            let anchorY = window.map { $0.convertToScreen($0.contentView?.bounds ?? .zero).minY }
                ?? screen.visibleFrame.maxY
            let maximum = max(100, anchorY - screen.visibleFrame.minY - 24)
            if abs(model.popoverMaximumHeight - maximum) > 1 { model.popoverMaximumHeight = maximum }
        }
        if let cached = measuredPopoverSizes[model.popoverScreen] {
            applyMeasuredPopoverSize(cached, for: model.popoverScreen)
        }
    }

    private func applyMeasuredPopoverSize(_ size: CGSize, for screen: PopoverScreen) {
        measuredPopoverSizes[screen] = size
        guard screen == model.popoverScreen else { return }
        let bounded = CGSize(width: Self.popoverWidth, height: min(size.height, model.popoverMaximumHeight))
        guard abs(popover.contentSize.height - bounded.height) > 1 else { return }
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentSize = bounded
    }

    func popoverDidClose(_ notification: Notification) {
        removeOutsideClickMonitor()
        model.didClosePopover()
    }
}
