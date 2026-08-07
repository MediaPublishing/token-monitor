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

        statusMenuSettingsSubscription = Publishers.CombineLatest3(
            model.$statusMenuUsesColor,
            model.$statusMenuShowsPercentages,
            model.$openCodeGoEnabled
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
        let services = model.statusMenuServices
        let width: CGFloat = model.statusMenuShowsPercentages ? 84 : 20
        let height: CGFloat = services.count > 2
            ? (model.statusMenuShowsPercentages ? 21 : 18)
            : 16
        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)
        let foregroundColor = statusBarForegroundColor(for: appearance)
        let trackColor = statusBarTrackColor(for: appearance)
        let statusValueFontSize: CGFloat = services.count > 2 ? 6 : 7
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let rowHeight = size.height / CGFloat(max(services.count, 1))
        let barHeight: CGFloat = services.count > 2 ? 5 : 6

        for (index, service) in services.enumerated() {
            let rowY = CGFloat(services.count - index - 1) * rowHeight
            let barY = rowY + (rowHeight - barHeight) / 2
            let status = model.dashboardState.service(service).connectionStatus

            if model.statusMenuShowsPercentages {
                drawStatusValue(
                    for: model.statusMenuTotalScore(for: service),
                    in: NSRect(x: 0, y: rowY, width: 25, height: rowHeight),
                    foregroundColor: foregroundColor,
                    fontSize: statusValueFontSize
                )
                drawBar(
                    in: NSRect(x: 29, y: barY, width: 24, height: barHeight),
                    score: model.statusMenuTotalScore(for: service),
                    status: status,
                    foregroundColor: foregroundColor,
                    trackColor: trackColor
                )
                drawStatusValue(
                    for: model.statusMenuSessionScore(for: service),
                    in: NSRect(x: 57, y: rowY, width: 27, height: rowHeight),
                    alignment: .left,
                    foregroundColor: foregroundColor,
                    fontSize: statusValueFontSize
                )
            } else {
                drawBar(
                    in: NSRect(x: 1, y: barY, width: width - 2, height: barHeight),
                    score: model.capacityScore(for: service),
                    status: status,
                    foregroundColor: foregroundColor,
                    trackColor: trackColor
                )
            }
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
        let statuses = model.statusMenuServices.map { service in
            let status = model.dashboardState.service(service)
            return "\(service.displayName): \(model.stateDescription(for: status))"
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
