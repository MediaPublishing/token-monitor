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
    private var dashboardHostingController: NSHostingController<AnyView>?

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
            button.image = makeCapacityStatusImage()
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
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            return
        }

        button.image = makeCapacityStatusImage()
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = tooltipText()
    }

    private func makeCapacityStatusImage() -> NSImage? {
        let size = NSSize(width: 20, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        drawBar(
            in: NSRect(x: 1, y: 9, width: 18, height: 5),
            score: model.capacityScore(for: .claude),
            status: model.dashboardState.service(.claude).connectionStatus
        )
        drawBar(
            in: NSRect(x: 1, y: 2, width: 18, height: 5),
            score: model.capacityScore(for: .chatGPT),
            status: model.dashboardState.service(.chatGPT).connectionStatus
        )

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawBar(in rect: NSRect, score: Double?, status: ServiceConnectionStatus) {
        let trackPath = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
        NSColor.quaternaryLabelColor.setFill()
        trackPath.fill()

        guard let score else {
            let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
            statusAccentColor(for: status).setStroke()
            outline.lineWidth = 1
            outline.stroke()
            return
        }

        let clamped = max(0.08, min(score, 1))
        let fillRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width * clamped, height: rect.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
        capacityColor(for: score, status: status).setFill()
        fillPath.fill()
    }

    private func statusAccentColor(for status: ServiceConnectionStatus) -> NSColor {
        switch status {
        case .healthy:
            return .systemGreen
        case .stale:
            return .systemOrange
        case .authRequired:
            return .systemYellow
        case .error:
            return .systemRed
        }
    }

    private func capacityColor(for score: Double, status: ServiceConnectionStatus) -> NSColor {
        switch status {
        case .error:
            return .systemRed
        case .authRequired:
            return .systemYellow
        case .stale:
            return score > 0.5 ? .systemOrange : .systemRed
        case .healthy:
            if score >= 0.65 { return .systemGreen }
            if score >= 0.35 { return .systemOrange }
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
        model.didClosePopover()
    }
}
