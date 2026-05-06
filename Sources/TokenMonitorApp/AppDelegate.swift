import AppKit
import Combine
import SwiftUI
import TokenMonitorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    static weak var shared: AppDelegate?
    static let popoverWidth: CGFloat = 488

    private let model = AppModel.shared
    private var statusItem: NSStatusItem?
    private var popover = NSPopover()
    private var dashboardSubscription: AnyCancellable?
    private var popoverScreenSubscription: AnyCancellable?
    private var statusMenuSettingsSubscription: AnyCancellable?
    private var dashboardHostingController: NSHostingController<AnyView>?
    private var outsideClickMonitor: Any?

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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.becomeKey()
        installOutsideClickMonitor()
    }

    private func configurePopover() {
        let rootView = AnyView(
            PopoverRootView()
                .environmentObject(model)
        )

        let hostingController = NSHostingController(rootView: rootView)
        dashboardHostingController = hostingController
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: Self.popoverWidth, height: model.desiredPopoverHeight())
        popover.contentViewController = hostingController
        updatePopoverSize()
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
        dashboardSubscription = model.$dashboardState
            .sink { [weak self] _ in
                self?.updateStatusItem()
            }

        popoverScreenSubscription = model.$popoverScreen
            .sink { [weak self] _ in
                self?.updatePopoverSize()
            }

        statusMenuSettingsSubscription = Publishers.CombineLatest(
            model.$statusMenuUsesColor,
            model.$statusMenuShowsPercentages
        )
        .sink { [weak self] _ in
            self?.updateStatusItem()
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            return
        }

        button.image = makeCapacityStatusImage(for: button.effectiveAppearance)
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = tooltipText()
    }

    private func makeCapacityStatusImage(for appearance: NSAppearance?) -> NSImage? {
        let width: CGFloat = model.statusMenuShowsPercentages ? 84 : 20
        let size = NSSize(width: width, height: 16)
        let image = NSImage(size: size)
        let foregroundColor = statusBarForegroundColor(for: appearance)
        let trackColor = statusBarTrackColor(for: appearance)
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        if model.statusMenuShowsPercentages {
            let claudeTotalScore = model.statusMenuTotalScore(for: .claude)
            let claudeSessionScore = model.statusMenuSessionScore(for: .claude)
            let chatGPTTotalScore = model.statusMenuTotalScore(for: .chatGPT)
            let chatGPTSessionScore = model.statusMenuSessionScore(for: .chatGPT)

            drawStatusValue(
                for: claudeTotalScore,
                in: NSRect(x: 0, y: 8, width: 25, height: 8),
                foregroundColor: foregroundColor
            )
            drawStatusValue(
                for: chatGPTTotalScore,
                in: NSRect(x: 0, y: 0, width: 25, height: 8),
                foregroundColor: foregroundColor
            )
            drawBar(
                in: NSRect(x: 29, y: 9, width: 24, height: 6),
                score: claudeTotalScore,
                status: model.dashboardState.service(.claude).connectionStatus,
                foregroundColor: foregroundColor,
                trackColor: trackColor
            )
            drawBar(
                in: NSRect(x: 29, y: 1, width: 24, height: 6),
                score: chatGPTTotalScore,
                status: model.dashboardState.service(.chatGPT).connectionStatus,
                foregroundColor: foregroundColor,
                trackColor: trackColor
            )
            drawStatusValue(
                for: claudeSessionScore,
                in: NSRect(x: 57, y: 8, width: 27, height: 8),
                alignment: .left,
                foregroundColor: foregroundColor
            )
            drawStatusValue(
                for: chatGPTSessionScore,
                in: NSRect(x: 57, y: 0, width: 27, height: 8),
                alignment: .left,
                foregroundColor: foregroundColor
            )
        } else {
            drawBar(
                in: NSRect(x: 1, y: 9, width: width - 2, height: 6),
                score: model.capacityScore(for: .claude),
                status: model.dashboardState.service(.claude).connectionStatus,
                foregroundColor: foregroundColor,
                trackColor: trackColor
            )
            drawBar(
                in: NSRect(x: 1, y: 1, width: width - 2, height: 6),
                score: model.capacityScore(for: .chatGPT),
                status: model.dashboardState.service(.chatGPT).connectionStatus,
                foregroundColor: foregroundColor,
                trackColor: trackColor
            )
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
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
        foregroundColor: NSColor
    ) {
        let label = score.map { "\(Int((max(0, min($0, 1)) * 100).rounded()))%" } ?? "--"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7, weight: .semibold),
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraph
        ]
        (label as NSString).draw(in: rect, withAttributes: attributes)
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
        let statuses = model.dashboardState.services.map { status in
            "\(status.service.displayName): \(model.stateDescription(for: status))"
        }
        return (["Token Monitor", model.lastRefreshText] + statuses).joined(separator: "\n")
    }

    private func updatePopoverSize() {
        let targetWidth = Self.popoverWidth
        let targetHeight = model.desiredPopoverHeight()
        popover.contentSize = NSSize(width: targetWidth, height: targetHeight)
    }

    func popoverDidClose(_ notification: Notification) {
        removeOutsideClickMonitor()
        model.didClosePopover()
    }
}
