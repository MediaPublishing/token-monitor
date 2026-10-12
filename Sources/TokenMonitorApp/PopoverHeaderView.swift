import SwiftUI

struct PopoverHeaderView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var updates = AppUpdateController.shared
    @ObservedObject var analytics: ProjectAnalyticsModel
    @FocusState private var focusedControl: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerControls
            if let version = updates.availableVersion {
                HStack(spacing: 8) {
                    Label("Update \(version) available", systemImage: "arrow.down.circle")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Button("Review Update") { updates.checkForUpdates() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.horizontal, 8)
            }
        }
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
        Button(action: action) {
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
                    focusedControl == systemImage
                        ? Color.primary.opacity(0.65)
                        : Color.black.opacity(isSelected ? 0.14 : 0.10),
                    lineWidth: focusedControl == systemImage ? 2 : 1
                )
        )
    }
}
