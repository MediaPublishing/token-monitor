import SwiftUI

struct PopoverHeaderView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var updates = AppUpdateController.shared

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
                Text(model.lastRefreshText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 8)

            Spacer(minLength: 6)

            headerButton(systemImage: "arrow.clockwise", action: {
                model.refreshAll(trigger: .manual)
            })
            .opacity(model.isRefreshing ? 0.5 : 1.0)
            .disabled(model.isRefreshing)
            .help("Refresh connected services")

            headerButton(
                systemImage: "chart.bar.xaxis",
                isSelected: model.popoverScreen == .dashboard,
                action: {
                    model.showDashboardInPopover()
                }
            )
            .help("Dashboard")

            headerButton(
                systemImage: "gearshape",
                isSelected: model.popoverScreen == .settings,
                action: {
                    model.showSettingsInPopover()
                }
            )
            .help("Settings")

            headerButton(systemImage: "xmark", action: {
                AppDelegate.shared?.closePopover()
            })
            .help("Close popover")
        }
    }

    private func headerButton(
        systemImage: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(nsColor: .selectedControlColor) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(isSelected ? 0.14 : 0.10), lineWidth: 1)
        )
    }
}
