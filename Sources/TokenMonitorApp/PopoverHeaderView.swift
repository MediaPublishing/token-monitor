import SwiftUI

struct PopoverHeaderView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var updates = AppUpdateController.shared
    @ObservedObject var analytics: ProjectAnalyticsModel
    @FocusState private var focusedControl: String?
    @State private var showsKeyboardFocus = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerControls
            if let version = updates.availableVersion {
                HStack(spacing: 8) {
                    Label(updates.isPreparingUpdate ? "Preparing update..." : "Update \(version) available", systemImage: "arrow.down.circle")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Button("Review Update") { updates.checkForUpdates() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(updates.isPreparingUpdate)
                        .help("Open the installer. If a background download is running, it opens when ready.")
                }
                .padding(.horizontal, 8)
            }
        }
        .background(ToolbarFocusInputObserver(showsKeyboardFocus: $showsKeyboardFocus).allowsHitTesting(false))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            showsKeyboardFocus = false
        }
        .onDisappear { showsKeyboardFocus = false }
    }

    private var headerControls: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Token Monitor")
                    .font(.headline.weight(.semibold))
                Text(model.popoverScreen == .analytics ? "Local token usage" : model.lastRefreshText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.leading, 8)

            Spacer(minLength: 6)

            headerButton(systemImage: "arrow.clockwise", action: {
                if model.popoverScreen == .analytics { analytics.refresh() }
                else { model.refreshAll(trigger: .manual) }
            })
            .opacity(headerIsRefreshing ? 0.5 : 1.0)
            .disabled(headerIsRefreshing)
            .help(model.popoverScreen == .analytics ? "Refresh local analysis" : "Refresh connected services")

            headerButton(
                systemImage: "chart.bar.xaxis",
                isSelected: model.popoverScreen == .dashboard,
                action: {
                    model.showDashboardInPopover()
                }
            )
            .help("Dashboard")
            .accessibilityLabel("Capacity")

            if analytics.enabled {
                headerButton(
                    systemImage: "chart.pie",
                    isSelected: model.popoverScreen == .analytics,
                    action: { model.showAnalyticsInPopover() }
                )
                .help("Analysis")
                .accessibilityLabel("Analysis")
            }

            headerButton(
                systemImage: "gearshape",
                isSelected: model.popoverScreen == .settings,
                action: {
                    model.showSettingsInPopover()
                }
            )
            .help("Settings")
            .accessibilityLabel("Settings")

            headerButton(systemImage: "xmark", action: {
                AppDelegate.shared?.closePopover()
            })
            .help("Close popover")
            .accessibilityLabel("Close popover")
        }
    }

    private var headerIsRefreshing: Bool {
        model.popoverScreen == .analytics ? analytics.refreshing : model.isRefreshing
    }

    private func headerButton(
        systemImage: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let hasKeyboardFocus = showsKeyboardFocus && focusedControl == systemImage
        return Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .focused($focusedControl, equals: systemImage)
        .focusEffectDisabled()
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(nsColor: .selectedControlColor) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    hasKeyboardFocus
                        ? Color.primary.opacity(0.65)
                        : Color.black.opacity(isSelected ? 0.14 : 0.10),
                    lineWidth: hasKeyboardFocus ? 2 : 1
                )
        )
    }
}

private struct ToolbarFocusInputObserver: NSViewRepresentable {
    @Binding var showsKeyboardFocus: Bool

    func makeNSView(context: Context) -> InputView {
        let view = InputView()
        view.onInput = { showsKeyboardFocus = $0 }
        return view
    }

    func updateNSView(_ view: InputView, context: Context) {
        view.onInput = { showsKeyboardFocus = $0 }
    }

    static func dismantleNSView(_ view: InputView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class InputView: NSView {
        var onInput: (Bool) -> Void = { _ in }
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            // Observe this window's input without consuming or changing its events.
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                self.onInput(event.type == .keyDown)
                return event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }
}
